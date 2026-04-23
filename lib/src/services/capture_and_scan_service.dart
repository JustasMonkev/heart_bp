import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../navigation/heart_page_route.dart';
import '../services/blood_pressure_tips.dart';
import '../widgets/scan_processing_view.dart';
import 'ocr_parser.dart';

class ScanCaptureResult {
  const ScanCaptureResult({
    required this.imagePath,
    required this.rawText,
    required this.parsed,
    required this.capturedAt,
  });

  final String imagePath;
  final String rawText;
  final OcrParseResult parsed;
  final DateTime capturedAt;
}

abstract class CaptureAndScanService {
  Future<ScanCaptureResult?> captureReading(BuildContext context);
}

class CameraCaptureAndScanService implements CaptureAndScanService {
  CameraCaptureAndScanService({
    OcrParser? parser,
    Future<List<CameraDescription>> Function()? camerasProvider,
  }) : _parser = parser ?? OcrParser(),
       _camerasProvider = camerasProvider ?? availableCameras;

  final OcrParser _parser;
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

      return ScanCaptureResult(
        imagePath: imagePath,
        rawText: primaryText,
        parsed: parsed,
        capturedAt: capturedAt,
      );
    } finally {
      await recognizer.close();
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
  final imagePath = request['imagePath']!;
  final tempDir = request['tempDir']!;
  final bytes = File(imagePath).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return {
      'display': [imagePath],
      'pulse': [imagePath],
      'systolic': [imagePath],
      'diastolic': [imagePath],
    };
  }

  final source = _resizeForOcr(decoded);
  final crops = _planOcrCrops(source);
  final variantsDirectory = Directory(p.join(tempDir, 'heart_bp_ocr_variants'))
    ..createSync(recursive: true);
  final basename = p.basenameWithoutExtension(imagePath);

  final variantMap = <String, List<img.Image>>{
    'display': [crops.display, _enhanceForOcr(crops.display)],
    'pulse': [_enhanceForOcr(crops.pulse)],
    'systolic': [_enhanceForOcr(crops.systolic)],
    'diastolic': [_enhanceForOcr(crops.diastolic)],
  };

  final output = <String, List<String>>{};
  for (final entry in variantMap.entries) {
    final paths = <String>[];
    for (var index = 0; index < entry.value.length; index++) {
      final path = p.join(
        variantsDirectory.path,
        '$basename-${entry.key}-$index.jpg',
      );
      File(
        path,
      ).writeAsBytesSync(img.encodeJpg(entry.value[index], quality: 90));
      paths.add(path);
    }
    output[entry.key] = paths;
  }

  return output;
}

img.Image _resizeForOcr(img.Image source) {
  const maxWidth = 1440;
  if (source.width <= maxWidth) {
    return source.clone();
  }

  final targetHeight = (source.height * (maxWidth / source.width)).round();
  return img.copyResize(
    source,
    width: maxWidth,
    height: targetHeight,
    interpolation: img.Interpolation.average,
  );
}

_OcrCropSet _planOcrCrops(img.Image source) {
  final dividerX = _estimateDividerX(source);
  final displayLeft = (dividerX - source.width * 0.42).round().clamp(
    0,
    dividerX - 12,
  );
  final displayRight = (dividerX - source.width * 0.01).round().clamp(
    displayLeft + 20,
    source.width,
  );
  final displayTop = (source.height * 0.05).round();
  final displayBottom = (source.height * 0.95).round().clamp(
    displayTop + 20,
    source.height,
  );

  final display = img.copyCrop(
    source,
    x: displayLeft,
    y: displayTop,
    width: displayRight - displayLeft,
    height: displayBottom - displayTop,
  );

  return _OcrCropSet(
    display: display,
    pulse: _copyRelativeCrop(
      display,
      x: 0.10,
      y: 0.17,
      width: 0.80,
      height: 0.21,
    ),
    systolic: _copyRelativeCrop(
      display,
      x: 0.08,
      y: 0.37,
      width: 0.82,
      height: 0.24,
    ),
    diastolic: _copyRelativeCrop(
      display,
      x: 0.08,
      y: 0.54,
      width: 0.82,
      height: 0.24,
    ),
  );
}

int _estimateDividerX(img.Image source) {
  final startX = (source.width * 0.34).round();
  final endX = (source.width * 0.80).round();
  final startY = (source.height * 0.12).round();
  final endY = (source.height * 0.92).round();
  final brightness = List<double>.filled(source.width, 0);

  for (var x = startX; x < endX; x++) {
    var total = 0.0;
    var count = 0;
    for (var y = startY; y < endY; y += 6) {
      final pixel = source.getPixel(x, y);
      total += _pixelLuminance(pixel);
      count++;
    }
    brightness[x] = count == 0 ? 0 : total / count;
  }

  final smoothed = brightness.toList();
  for (var x = startX + 2; x < endX - 2; x++) {
    smoothed[x] =
        (brightness[x - 2] +
            brightness[x - 1] +
            brightness[x] +
            brightness[x + 1] +
            brightness[x + 2]) /
        5;
  }

  var bestX = (source.width * 0.56).round();
  var bestDelta = double.negativeInfinity;
  for (var x = startX + 4; x < endX - 4; x++) {
    final delta = smoothed[x + 3] - smoothed[x - 3];
    if (delta > bestDelta) {
      bestDelta = delta;
      bestX = x;
    }
  }

  return bestX.clamp(
    (source.width * 0.45).round(),
    (source.width * 0.66).round(),
  );
}

double _pixelLuminance(img.Pixel pixel) {
  final red = pixel.r.toDouble();
  final green = pixel.g.toDouble();
  final blue = pixel.b.toDouble();
  return (0.2126 * red) + (0.7152 * green) + (0.0722 * blue);
}

img.Image _copyRelativeCrop(
  img.Image source, {
  required double x,
  required double y,
  required double width,
  required double height,
}) {
  final left = (source.width * x).round().clamp(0, source.width - 1);
  final top = (source.height * y).round().clamp(0, source.height - 1);
  final cropWidth = (source.width * width).round().clamp(
    1,
    source.width - left,
  );
  final cropHeight = (source.height * height).round().clamp(
    1,
    source.height - top,
  );

  return img.copyCrop(
    source,
    x: left,
    y: top,
    width: cropWidth,
    height: cropHeight,
  );
}

img.Image _enhanceForOcr(img.Image source) {
  final doubledWidth = source.width < 900 ? source.width * 2 : source.width;
  final resized = img.copyResize(
    source,
    width: doubledWidth,
    interpolation: img.Interpolation.average,
  );
  img.grayscale(resized);
  img.adjustColor(resized, contrast: 1.65, brightness: 1.06, gamma: 0.92);
  return resized;
}

class _OcrCropSet {
  const _OcrCropSet({
    required this.display,
    required this.pulse,
    required this.systolic,
    required this.diastolic,
  });

  final img.Image display;
  final img.Image pulse;
  final img.Image systolic;
  final img.Image diastolic;
}

class _ScanScreen extends StatefulWidget {
  const _ScanScreen({required this.parser, required this.camerasProvider});

  final OcrParser parser;
  final Future<List<CameraDescription>> Function() camerasProvider;

  @override
  State<_ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<_ScanScreen> {
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
      final photo = await controller.takePicture();
      final capturedAt = DateTime.now();
      final persistedImage = await _extractionService._persistPhoto(
        photo.path,
        capturedAt,
      );
      final result = await _extractionService._extractReadingFromImage(
        imagePath: persistedImage.path,
        capturedAt: capturedAt,
      );

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
                      ? 'Reading the saved photo now. This usually takes a few seconds.'
                      : 'Keep the monitor display large in frame and avoid glare on the screen. The app now prioritizes the left display area for OCR.',
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
      children: [
        CameraPreview(_controller!),
        Align(
          alignment: Alignment.center,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 3),
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        ),
      ],
    );
  }
}
