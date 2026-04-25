import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../navigation/heart_page_route.dart';
import '../services/blood_pressure_tips.dart';
import '../widgets/scan_guidance_overlay.dart';
import '../widgets/scan_processing_view.dart';
import 'ocr_image_preprocessor.dart';
import 'ocr_parser.dart';
import 'reading_extraction_resolver.dart';
import 'seven_segment_display_reader.dart';

class ScanCaptureResult {
  const ScanCaptureResult({
    required this.imagePath,
    required this.rawText,
    required this.parsed,
    required this.capturedAt,
    this.confidence = ScanConfidenceLevel.low,
    this.confidenceScore = 0,
    this.confidenceMessage =
        'The scan was uncertain. Check the photo before saving.',
    this.extractionSource = 'OCR',
  });

  final String imagePath;
  final String rawText;
  final OcrParseResult parsed;
  final DateTime capturedAt;
  final ScanConfidenceLevel confidence;
  final double confidenceScore;
  final String confidenceMessage;
  final String extractionSource;

  ScanCaptureResult copyWith({
    String? imagePath,
    String? rawText,
    OcrParseResult? parsed,
    DateTime? capturedAt,
    ScanConfidenceLevel? confidence,
    double? confidenceScore,
    String? confidenceMessage,
    String? extractionSource,
  }) {
    return ScanCaptureResult(
      imagePath: imagePath ?? this.imagePath,
      rawText: rawText ?? this.rawText,
      parsed: parsed ?? this.parsed,
      capturedAt: capturedAt ?? this.capturedAt,
      confidence: confidence ?? this.confidence,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      confidenceMessage: confidenceMessage ?? this.confidenceMessage,
      extractionSource: extractionSource ?? this.extractionSource,
    );
  }
}

abstract class CaptureAndScanService {
  Future<ScanCaptureResult?> captureReading(BuildContext context);
}

class CameraCaptureAndScanService implements CaptureAndScanService {
  CameraCaptureAndScanService({
    OcrParser? parser,
    ReadingExtractionResolver? extractionResolver,
    Future<List<CameraDescription>> Function()? camerasProvider,
  }) : _parser = parser ?? OcrParser(),
       _extractionResolver =
           extractionResolver ?? const ReadingExtractionResolver(),
       _camerasProvider = camerasProvider ?? availableCameras;

  final OcrParser _parser;
  final ReadingExtractionResolver _extractionResolver;
  final Future<List<CameraDescription>> Function() _camerasProvider;

  @override
  Future<ScanCaptureResult?> captureReading(BuildContext context) {
    return Navigator.of(context).push<ScanCaptureResult>(
      buildHeartRoute<ScanCaptureResult>(
        fullscreenDialog: true,
        builder: (_) =>
            _ScanScreen(parser: _parser, camerasProvider: _camerasProvider),
      ),
    );
  }

  Future<File> _persistPhoto(String sourcePath, DateTime capturedAt) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final photosDirectory = Directory(
      p.join(documentsDirectory.path, 'reading_photos'),
    );
    await photosDirectory.create(recursive: true);

    final extension = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    final targetPath = p.join(
      photosDirectory.path,
      'reading-${capturedAt.millisecondsSinceEpoch}$extension',
    );
    return File(sourcePath).copy(targetPath);
  }

  Future<ScanCaptureResult> _extractReadingFromImage({
    required String imagePath,
    required DateTime capturedAt,
  }) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final preparedImages = await _prepareOcrImages(imagePath);
      final displayTexts = await _recognizeTextSet(
        preparedImages['display'] ?? [imagePath],
        recognizer,
      );
      var parsed = _parser.parseBest(displayTexts);

      final needsTargeted =
          parsed.systolic == null ||
          parsed.diastolic == null ||
          parsed.pulse == null;
      if (needsTargeted) {
        final targetedMetrics = await _recognizeTargetedMetrics(
          preparedImages,
          recognizer,
        );
        parsed = _parser.mergeTargetedMetrics(
          parsed,
          systolic: targetedMetrics['systolic'],
          diastolic: targetedMetrics['diastolic'],
          pulse: targetedMetrics['pulse'],
          rawText: displayTexts
              .where((text) => text.trim().isNotEmpty)
              .join('\n'),
        );
      }

      final primaryText = displayTexts.firstWhere(
        (text) => text.trim().isNotEmpty,
        orElse: () => '',
      );
      final segmentResult = await _readSevenSegmentDisplay(imagePath);
      final decision = _extractionResolver.resolve(
        ocrResult: parsed,
        segmentResult: segmentResult,
        rawOcrText: primaryText,
      );

      return ScanCaptureResult(
        imagePath: imagePath,
        rawText: decision.parsed.rawText,
        parsed: decision.parsed,
        capturedAt: capturedAt,
        confidence: decision.confidence,
        confidenceScore: decision.confidenceScore,
        confidenceMessage: decision.confidenceMessage,
        extractionSource: decision.extractionSource,
      );
    } finally {
      await recognizer.close();
    }
  }

  Future<SevenSegmentDisplayReadResult> _readSevenSegmentDisplay(
    String imagePath,
  ) async {
    try {
      return await compute<String, SevenSegmentDisplayReadResult>(
        _readSevenSegmentImage,
        imagePath,
      );
    } catch (_) {
      return const SevenSegmentDisplayReadResult(
        systolic: null,
        diastolic: null,
        pulse: null,
        confidence: 0,
      );
    }
  }

  Future<Map<String, List<String>>> _prepareOcrImages(String imagePath) async {
    final tempDirectory = await getTemporaryDirectory();
    final preparedImages =
        await compute<Map<String, String>, Map<String, List<String>>>(
          _buildPreparedOcrImages,
          {'imagePath': imagePath, 'tempDir': tempDirectory.path},
        );
    return preparedImages;
  }

  Future<List<String>> _recognizeTextSet(
    Iterable<String> imagePaths,
    TextRecognizer recognizer,
  ) async {
    final recognized = <String>[];
    for (final imagePath in imagePaths) {
      final rawText = await _recognizeText(imagePath, recognizer);
      if (rawText.trim().isNotEmpty && !recognized.contains(rawText)) {
        recognized.add(rawText);
      }
    }

    if (recognized.isEmpty) {
      recognized.add('');
    }

    return recognized;
  }

  Future<Map<String, int?>> _recognizeTargetedMetrics(
    Map<String, List<String>> preparedImages,
    TextRecognizer recognizer,
  ) async {
    final pulseTexts = await _recognizeTextSet(
      preparedImages['pulse'] ?? const <String>[],
      recognizer,
    );
    final systolicTexts = await _recognizeTextSet(
      preparedImages['systolic'] ?? const <String>[],
      recognizer,
    );
    final diastolicTexts = await _recognizeTextSet(
      preparedImages['diastolic'] ?? const <String>[],
      recognizer,
    );
    final pulseParsed = _parser.parseBest(pulseTexts);
    final systolicParsed = _parser.parseBest(systolicTexts);
    final diastolicParsed = _parser.parseBest(diastolicTexts);

    return {
      'pulse':
          pulseParsed.pulse ??
          _parser.bestMetricValue(
            pulseTexts,
            min: 30,
            max: 220,
            preferredMin: 40,
            preferredMax: 120,
          ),
      'systolic':
          systolicParsed.systolic ??
          _parser.bestMetricValue(
            systolicTexts,
            min: 50,
            max: 260,
            preferredMin: 90,
            preferredMax: 190,
          ),
      'diastolic':
          diastolicParsed.diastolic ??
          _parser.bestMetricValue(
            diastolicTexts,
            min: 30,
            max: 180,
            preferredMin: 50,
            preferredMax: 120,
          ),
    };
  }

  Future<String> _recognizeText(
    String imagePath,
    TextRecognizer recognizer,
  ) async {
    try {
      final recognizedText = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return recognizedText.text;
    } catch (_) {
      return '';
    }
  }
}

Map<String, List<String>> _buildPreparedOcrImages(Map<String, String> request) {
  return OcrImagePreprocessor.buildPreparedImageFiles(
    imagePath: request['imagePath']!,
    tempDir: request['tempDir']!,
  );
}

SevenSegmentDisplayReadResult _readSevenSegmentImage(String imagePath) {
  return const SevenSegmentDisplayReader().readFile(imagePath);
}

class _ScanScreen extends StatefulWidget {
  const _ScanScreen({required this.parser, required this.camerasProvider});

  final OcrParser parser;
  final Future<List<CameraDescription>> Function() camerasProvider;

  @override
  State<_ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<_ScanScreen> {
  static const _minimumCaptureFrames = 2;
  static const _maximumCaptureFrames = 3;
  static const _framePause = Duration(milliseconds: 220);

  CameraController? _controller;
  bool _isReady = false;
  bool _isCapturing = false;
  String? _errorMessage;
  BloodPressureTip? _processingTip;
  late final CameraCaptureAndScanService _extractionService;

  @override
  void initState() {
    super.initState();
    _extractionService = CameraCaptureAndScanService(
      parser: widget.parser,
      camerasProvider: widget.camerasProvider,
    );
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await widget.camerasProvider();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera was found on this device.';
        });
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isReady = true;
      });
    } on CameraException catch (error) {
      setState(() {
        _errorMessage = error.code == 'CameraAccessDenied'
            ? 'Camera permission was denied. Please allow camera access and try again.'
            : 'Could not start the camera: ${error.description ?? error.code}';
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Could not start the camera: $error';
      });
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _errorMessage = null;
      _processingTip = BloodPressureTips.tipForSeed(
        DateTime.now().microsecondsSinceEpoch,
      );
    });
    await WidgetsBinding.instance.endOfFrame;

    try {
      final frameResults = await _captureFrameResults(controller);
      final selectedResult = _selectConsensusResult(frameResults);
      final persistedImage = await _extractionService._persistPhoto(
        selectedResult.imagePath,
        selectedResult.capturedAt,
      );
      final result = selectedResult.copyWith(imagePath: persistedImage.path);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(result);
    } catch (error) {
      setState(() {
        _errorMessage = 'Capture failed. You can try again. $error';
        _isCapturing = false;
        _processingTip = null;
      });
    }
  }

  Future<List<ScanCaptureResult>> _captureFrameResults(
    CameraController controller,
  ) async {
    final results = <ScanCaptureResult>[];

    for (var index = 0; index < _maximumCaptureFrames; index++) {
      try {
        final photo = await controller.takePicture();
        final capturedAt = DateTime.now();
        final result = await _extractionService._extractReadingFromImage(
          imagePath: photo.path,
          capturedAt: capturedAt,
        );
        results.add(result);

        if (results.length >= _minimumCaptureFrames &&
            _hasStableCaptureConsensus(results)) {
          break;
        }
      } catch (_) {
        if (results.isEmpty) {
          rethrow;
        }
        break;
      }

      if (index < _maximumCaptureFrames - 1) {
        await Future<void>.delayed(_framePause);
      }
    }

    if (results.isEmpty) {
      throw StateError('No camera frames were captured.');
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.98, end: 1).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: ClipRRect(
                    key: ValueKey<String>(
                      _isCapturing ? 'processing' : 'camera-body',
                    ),
                    borderRadius: BorderRadius.circular(28),
                    child: _buildCameraBody(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  _isCapturing
                      ? 'Comparing camera frames and extracting the display values.'
                      : 'Align the monitor display inside the frame and keep reflections off the numbers.',
                  key: ValueKey<String>(
                    _isCapturing ? 'processing-copy' : 'capture-copy',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isReady && !_isCapturing ? _capture : null,
                  icon: Icon(
                    _isCapturing
                        ? Icons.hourglass_top_rounded
                        : Icons.camera_alt_outlined,
                  ),
                  label: Text(_isCapturing ? 'Analyzing…' : 'Capture'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraBody() {
    if (_isCapturing) {
      return ScanProcessingView(
        tip: _processingTip ?? BloodPressureTips.tipForSeed(0),
      );
    }

    if (_errorMessage != null) {
      return Container(
        color: Colors.black12,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 48),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isCapturing ? null : _initializeCamera,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isReady || _controller == null) {
      return const ColoredBox(
        color: Colors.black12,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [CameraPreview(_controller!), const ScanGuidanceOverlay()],
    );
  }
}

bool _hasStableCaptureConsensus(List<ScanCaptureResult> results) {
  if (results.length < 2) {
    return false;
  }

  final latest = results.last;
  final previous = results[results.length - 2];
  if (_sameParsedReading(latest, previous)) {
    return true;
  }

  return latest.confidence == ScanConfidenceLevel.high &&
      latest.parsed.systolic != null &&
      latest.parsed.diastolic != null &&
      latest.parsed.pulse != null;
}

ScanCaptureResult _selectConsensusResult(List<ScanCaptureResult> results) {
  if (results.length == 1) {
    return results.single;
  }

  final completeGroups = <String, List<ScanCaptureResult>>{};
  for (final result in results) {
    if (result.parsed.systolic == null ||
        result.parsed.diastolic == null ||
        result.parsed.pulse == null) {
      continue;
    }
    completeGroups
        .putIfAbsent(_readingKey(result), () => <ScanCaptureResult>[])
        .add(result);
  }

  final consensusGroups =
      completeGroups.values.where((group) => group.length > 1).toList()
        ..sort((left, right) => right.length.compareTo(left.length));
  if (consensusGroups.isNotEmpty) {
    final best = _highestConfidenceResult(consensusGroups.first);
    return best.copyWith(
      confidence: ScanConfidenceLevel.high,
      confidenceScore: best.confidenceScore.clamp(0.90, 1).toDouble(),
      confidenceMessage:
          'Multiple camera frames agreed on these values. Review before saving.',
      extractionSource: 'Frame consensus',
    );
  }

  return _highestConfidenceResult(results);
}

ScanCaptureResult _highestConfidenceResult(List<ScanCaptureResult> results) {
  final sorted = results.toList()
    ..sort((left, right) {
      final confidenceComparison = right.confidenceScore.compareTo(
        left.confidenceScore,
      );
      if (confidenceComparison != 0) {
        return confidenceComparison;
      }
      return right.parsed.score.compareTo(left.parsed.score);
    });
  return sorted.first;
}

bool _sameParsedReading(ScanCaptureResult left, ScanCaptureResult right) {
  return _readingKey(left) == _readingKey(right) &&
      left.parsed.systolic != null &&
      left.parsed.diastolic != null &&
      left.parsed.pulse != null;
}

String _readingKey(ScanCaptureResult result) {
  return '${result.parsed.systolic}/${result.parsed.diastolic}/${result.parsed.pulse}';
}
