import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import 'ocr_image_preprocessor.dart';

class SevenSegmentDisplayReadResult {
  const SevenSegmentDisplayReadResult({
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.confidence,
  });

  final int? systolic;
  final int? diastolic;
  final int? pulse;
  final double confidence;

  bool get hasCompleteReading =>
      systolic != null && diastolic != null && pulse != null;

  bool get hasAnyReading =>
      systolic != null || diastolic != null || pulse != null;

  String get rawText {
    final lines = <String>[];
    if (pulse != null) {
      lines.add('PULSE $pulse');
    }
    if (systolic != null) {
      lines.add('SYS $systolic');
    }
    if (diastolic != null) {
      lines.add('DIA $diastolic');
    }
    return lines.join('\n');
  }
}

class SevenSegmentDisplayReader {
  const SevenSegmentDisplayReader();

  SevenSegmentDisplayReadResult readFile(String imagePath) {
    final bytes = File(imagePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return const SevenSegmentDisplayReadResult(
        systolic: null,
        diastolic: null,
        pulse: null,
        confidence: 0,
      );
    }

    return readImage(decoded);
  }

  SevenSegmentDisplayReadResult readImage(img.Image image) {
    final resized = OcrImagePreprocessor.resizeForOcr(image);
    final crops = OcrImagePreprocessor.planCrops(resized);
    return readDisplayCrop(crops.display);
  }

  SevenSegmentDisplayReadResult readDisplayCrop(img.Image display) {
    final pulse = _readNumberRow(
      OcrImagePreprocessor.copyRelativeCrop(
        display,
        x: 0.10,
        y: 0.24,
        width: 0.80,
        height: 0.22,
      ),
      expectedDigits: 2,
      numberLeft: 0.50,
      numberRight: 0.98,
      min: 30,
      max: 220,
    );
    final systolic = _readNumberRow(
      OcrImagePreprocessor.copyRelativeCrop(
        display,
        x: 0.08,
        y: 0.38,
        width: 0.82,
        height: 0.22,
      ),
      expectedDigits: 3,
      numberLeft: 0.27,
      numberRight: 0.98,
      min: 50,
      max: 260,
    );
    final diastolic = _readNumberRow(
      OcrImagePreprocessor.copyRelativeCrop(
        display,
        x: 0.08,
        y: 0.53,
        width: 0.82,
        height: 0.23,
      ),
      expectedDigits: 2,
      numberLeft: 0.49,
      numberRight: 0.98,
      min: 30,
      max: 180,
    );

    final confidence = _overallConfidence(
      systolic: systolic,
      diastolic: diastolic,
      pulse: pulse,
    );

    return SevenSegmentDisplayReadResult(
      systolic: systolic.value,
      diastolic: diastolic.value,
      pulse: pulse.value,
      confidence: confidence,
    );
  }

  static double _overallConfidence({
    required _NumberReadResult systolic,
    required _NumberReadResult diastolic,
    required _NumberReadResult pulse,
  }) {
    final available = [
      systolic,
      diastolic,
      pulse,
    ].where((result) => result.value != null).toList();
    if (available.isEmpty) {
      return 0;
    }

    var confidence =
        available.fold<double>(0, (sum, result) => sum + result.confidence) /
        available.length;
    if (available.length < 3) {
      confidence *= 0.72;
    }
    if (systolic.value != null &&
        diastolic.value != null &&
        systolic.value! <= diastolic.value!) {
      confidence *= 0.45;
    }
    return confidence.clamp(0, 1);
  }

  static _NumberReadResult _readNumberRow(
    img.Image row, {
    required int expectedDigits,
    required double numberLeft,
    required double numberRight,
    required int min,
    required int max,
  }) {
    final left = (row.width * numberLeft).round().clamp(0, row.width - 1);
    final right = (row.width * numberRight).round().clamp(left + 1, row.width);
    final threshold = _lightingThreshold(row, left: left, right: right);
    final verticalBounds = _activeVerticalBounds(
      row,
      left: left,
      right: right,
      threshold: threshold,
    );
    final top = verticalBounds.$1;
    final bottom = verticalBounds.$2;
    final digitWidth = (right - left) / expectedDigits;
    final decodedDigits = <_DigitReadResult>[];

    for (var index = 0; index < expectedDigits; index++) {
      final digitLeft = (left + digitWidth * index).round();
      final digitRight = index == expectedDigits - 1
          ? right
          : (left + digitWidth * (index + 1)).round();
      final digit = img.copyCrop(
        row,
        x: digitLeft.clamp(0, row.width - 1),
        y: top.clamp(0, row.height - 1),
        width: (digitRight - digitLeft).clamp(1, row.width - digitLeft),
        height: (bottom - top).clamp(1, row.height - top),
      );
      decodedDigits.add(_decodeDigit(digit, threshold));
    }

    if (decodedDigits.any((digit) => digit.value == null)) {
      return const _NumberReadResult(value: null, confidence: 0);
    }

    final text = decodedDigits.map((digit) => digit.value!).join();
    final value = int.tryParse(text);
    if (value == null || value < min || value > max) {
      return const _NumberReadResult(value: null, confidence: 0);
    }

    final confidence =
        decodedDigits.fold<double>(0, (sum, digit) => sum + digit.confidence) /
        decodedDigits.length;
    return _NumberReadResult(value: value, confidence: confidence.clamp(0, 1));
  }

  static double _lightingThreshold(
    img.Image image, {
    required int left,
    required int right,
  }) {
    final scores = <double>[];
    final stepX = math.max(1, ((right - left) / 180).round());
    final stepY = math.max(1, (image.height / 160).round());

    for (var y = 0; y < image.height; y += stepY) {
      for (var x = left; x < right; x += stepX) {
        scores.add(_ledScore(image.getPixel(x, y)));
      }
    }

    if (scores.isEmpty) {
      return 70;
    }
    scores.sort();
    final p84 =
        scores[(scores.length * 0.84).floor().clamp(0, scores.length - 1)];
    final p95 =
        scores[(scores.length * 0.95).floor().clamp(0, scores.length - 1)];
    final threshold = p84 + ((p95 - p84) * 0.18);
    return threshold.clamp(48, 154);
  }

  static (int, int) _activeVerticalBounds(
    img.Image image, {
    required int left,
    required int right,
    required double threshold,
  }) {
    final rowCounts = List<int>.filled(image.height, 0);
    for (var y = 0; y < image.height; y++) {
      var count = 0;
      for (var x = left; x < right; x += 2) {
        if (_ledScore(image.getPixel(x, y)) >= threshold) {
          count++;
        }
      }
      rowCounts[y] = count;
    }

    final maxCount = rowCounts.fold<int>(0, math.max);
    final minLit = math.max(2, (maxCount * 0.18).round());
    var top = rowCounts.indexWhere((count) => count >= minLit);
    var bottom = rowCounts.lastIndexWhere((count) => count >= minLit) + 1;

    if (top < 0 || bottom <= top) {
      top = 0;
      bottom = image.height;
    }

    final padding = ((bottom - top) * 0.09).round();
    top = (top - padding).clamp(0, image.height - 1);
    bottom = (bottom + padding).clamp(top + 1, image.height);
    return (top, bottom);
  }

  static _DigitReadResult _decodeDigit(img.Image digit, double threshold) {
    final segmentScores = _segmentRegions
        .map((segment) => _segmentScore(digit, segment, threshold))
        .toList();
    final maxScore = segmentScores.fold<double>(0, math.max);
    if (maxScore < 0.08) {
      return const _DigitReadResult(value: null, confidence: 0);
    }
    final activeCutoff = math.max(0.24, maxScore * 0.38).clamp(0.20, 0.42);
    final activeSegments = <int>{
      for (var index = 0; index < segmentScores.length; index++)
        if (segmentScores[index] >= activeCutoff) index,
    };

    int? bestDigit;
    var bestError = double.infinity;
    for (final entry in _digitSegments.entries) {
      var error = 0.0;
      for (var segment = 0; segment < _segmentRegions.length; segment++) {
        final score = segmentScores[segment];
        final shouldBeOn = entry.value.contains(segment);
        final isOn = activeSegments.contains(segment);
        if (shouldBeOn != isOn) {
          error += shouldBeOn ? 1.4 : 1.0;
        }
        error += shouldBeOn
            ? (1 - score).clamp(0, 1) * 0.10
            : score.clamp(0, 1) * 0.08;
      }

      if (error < bestError) {
        bestError = error;
        bestDigit = entry.key;
      }
    }

    final confidence = (1 - (bestError / 5.2)).clamp(0, 1).toDouble();
    if (bestDigit == null || confidence < 0.46) {
      return const _DigitReadResult(value: null, confidence: 0);
    }
    return _DigitReadResult(value: bestDigit, confidence: confidence);
  }

  static double _segmentScore(
    img.Image digit,
    _SegmentRegion region,
    double threshold,
  ) {
    final left = (digit.width * region.left).round().clamp(0, digit.width - 1);
    final top = (digit.height * region.top).round().clamp(0, digit.height - 1);
    final right = (digit.width * region.right).round().clamp(
      left + 1,
      digit.width,
    );
    final bottom = (digit.height * region.bottom).round().clamp(
      top + 1,
      digit.height,
    );

    var lit = 0;
    var total = 0;
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        total++;
        if (_ledScore(digit.getPixel(x, y)) >= threshold) {
          lit++;
        }
      }
    }

    if (total == 0) {
      return 0;
    }
    return lit / total;
  }

  static double _ledScore(img.Pixel pixel) {
    final red = pixel.r.toDouble();
    final green = pixel.g.toDouble();
    final blue = pixel.b.toDouble();
    final luma = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue);
    final coolChannel = math.max(green, blue);
    final whiteAllowance = math.min(red, coolChannel) * 0.22;
    return (coolChannel * 0.72) + (luma * 0.25) + whiteAllowance - (red * 0.12);
  }
}

class _NumberReadResult {
  const _NumberReadResult({required this.value, required this.confidence});

  final int? value;
  final double confidence;
}

class _DigitReadResult {
  const _DigitReadResult({required this.value, required this.confidence});

  final int? value;
  final double confidence;
}

class _SegmentRegion {
  const _SegmentRegion({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

const _segmentRegions = <_SegmentRegion>[
  _SegmentRegion(left: 0.27, top: 0.03, right: 0.73, bottom: 0.16),
  _SegmentRegion(left: 0.02, top: 0.17, right: 0.27, bottom: 0.40),
  _SegmentRegion(left: 0.72, top: 0.17, right: 0.98, bottom: 0.40),
  _SegmentRegion(left: 0.24, top: 0.44, right: 0.76, bottom: 0.56),
  _SegmentRegion(left: 0.02, top: 0.61, right: 0.27, bottom: 0.84),
  _SegmentRegion(left: 0.72, top: 0.61, right: 0.98, bottom: 0.84),
  _SegmentRegion(left: 0.27, top: 0.84, right: 0.73, bottom: 0.97),
];

const _digitSegments = <int, Set<int>>{
  0: {0, 1, 2, 4, 5, 6},
  1: {2, 5},
  2: {0, 2, 3, 4, 6},
  3: {0, 2, 3, 5, 6},
  4: {1, 2, 3, 5},
  5: {0, 1, 3, 5, 6},
  6: {0, 1, 3, 4, 5, 6},
  7: {0, 2, 5},
  8: {0, 1, 2, 3, 4, 5, 6},
  9: {0, 1, 2, 3, 5, 6},
};
