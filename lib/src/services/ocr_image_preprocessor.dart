import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class OcrCropSet {
  const OcrCropSet({
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

class OcrImagePreprocessor {
  const OcrImagePreprocessor._();

  static Map<String, List<String>> buildPreparedImageFiles({
    required String imagePath,
    required String tempDir,
  }) {
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

    final source = resizeForOcr(decoded);
    final crops = planCrops(source);
    final variantsDirectory = Directory(
      p.join(tempDir, 'heart_bp_ocr_variants'),
    )..createSync(recursive: true);
    final basename = p.basenameWithoutExtension(imagePath);

    final variantMap = <String, List<img.Image>>{
      'display': [
        crops.display,
        enhanceForOcr(crops.display),
        isolateLitSegmentsForOcr(crops.display),
      ],
      'pulse': [
        enhanceForOcr(crops.pulse),
        isolateLitSegmentsForOcr(crops.pulse),
      ],
      'systolic': [
        enhanceForOcr(crops.systolic),
        isolateLitSegmentsForOcr(crops.systolic),
      ],
      'diastolic': [
        enhanceForOcr(crops.diastolic),
        isolateLitSegmentsForOcr(crops.diastolic),
      ],
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

  static img.Image resizeForOcr(img.Image source) {
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

  static OcrCropSet planCrops(img.Image source) {
    final dividerX = _estimateDividerX(source);
    final displayLeft = (dividerX - source.width * 0.42).round().clamp(
      0,
      dividerX - 12,
    );
    final displayRight = (dividerX + source.width * 0.04).round().clamp(
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

    return OcrCropSet(
      display: display,
      pulse: copyRelativeCrop(
        display,
        x: 0.10,
        y: 0.28,
        width: 0.80,
        height: 0.17,
      ),
      systolic: copyRelativeCrop(
        display,
        x: 0.08,
        y: 0.43,
        width: 0.82,
        height: 0.16,
      ),
      diastolic: copyRelativeCrop(
        display,
        x: 0.08,
        y: 0.54,
        width: 0.82,
        height: 0.18,
      ),
    );
  }

  static img.Image copyRelativeCrop(
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

  static img.Image enhanceForOcr(img.Image source) {
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

  static img.Image isolateLitSegmentsForOcr(img.Image source) {
    final targetWidth = source.width < 900 ? source.width * 2 : source.width;
    final resized = img.copyResize(
      source,
      width: targetWidth,
      interpolation: img.Interpolation.average,
    );
    final threshold = _litSegmentThreshold(resized);
    final output = img.Image(width: resized.width, height: resized.height);
    img.fill(output, color: img.ColorRgb8(255, 255, 255));

    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        if (_ledScore(resized.getPixel(x, y)) >= threshold) {
          _paintBlackPixel(output, x, y);
        }
      }
    }

    return output;
  }

  static int _estimateDividerX(img.Image source) {
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

  static double _pixelLuminance(img.Pixel pixel) {
    final red = pixel.r.toDouble();
    final green = pixel.g.toDouble();
    final blue = pixel.b.toDouble();
    return (0.2126 * red) + (0.7152 * green) + (0.0722 * blue);
  }

  static double _litSegmentThreshold(img.Image image) {
    final scores = <double>[];
    final stepX = math.max(1, (image.width / 240).round());
    final stepY = math.max(1, (image.height / 240).round());
    for (var y = 0; y < image.height; y += stepY) {
      for (var x = 0; x < image.width; x += stepX) {
        scores.add(_ledScore(image.getPixel(x, y)));
      }
    }
    if (scores.isEmpty) {
      return 70;
    }
    scores.sort();
    final p82 =
        scores[(scores.length * 0.82).floor().clamp(0, scores.length - 1)];
    final p96 =
        scores[(scores.length * 0.96).floor().clamp(0, scores.length - 1)];
    return (p82 + ((p96 - p82) * 0.24)).clamp(42, 150);
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

  static void _paintBlackPixel(img.Image image, int x, int y) {
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final px = x + dx;
        final py = y + dy;
        if (px >= 0 && py >= 0 && px < image.width && py < image.height) {
          image.setPixelRgb(px, py, 0, 0, 0);
        }
      }
    }
  }
}
