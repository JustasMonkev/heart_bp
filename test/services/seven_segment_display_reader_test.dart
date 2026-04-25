import 'package:flutter_test/flutter_test.dart';
import 'package:heart_bp/src/services/seven_segment_display_reader.dart';
import 'package:image/image.dart' as img;

void main() {
  group('SevenSegmentDisplayReader', () {
    const reader = SevenSegmentDisplayReader();

    test('reads a clean generated monitor display', () {
      final display = _fixtureDisplay(
        systolic: '153',
        diastolic: '77',
        pulse: '68',
      );

      final result = reader.readDisplayCrop(display);

      expect(result.systolic, 153);
      expect(result.diastolic, 77);
      expect(result.pulse, 68);
      expect(result.confidence, greaterThan(0.70));
    });

    test('ignores dim inactive ghost segments', () {
      final display = _fixtureDisplay(
        systolic: '139',
        diastolic: '72',
        pulse: '62',
        drawGhostSegments: true,
      );

      final result = reader.readDisplayCrop(display);

      expect(result.systolic, 139);
      expect(result.diastolic, 72);
      expect(result.pulse, 62);
      expect(result.confidence, greaterThan(0.60));
    });

    test('keeps confidence low when the display is blank', () {
      final display = img.Image(width: 500, height: 900);
      img.fill(display, color: img.ColorRgb8(8, 16, 22));

      final result = reader.readDisplayCrop(display);

      expect(result.hasAnyReading, isFalse);
      expect(result.confidence, 0);
    });
  });
}

img.Image _fixtureDisplay({
  required String systolic,
  required String diastolic,
  required String pulse,
  bool drawGhostSegments = false,
}) {
  final display = img.Image(width: 500, height: 900);
  img.fill(display, color: img.ColorRgb8(8, 16, 22));

  _drawMetric(
    display,
    rowX: 0.10,
    rowY: 0.24,
    rowWidth: 0.80,
    rowHeight: 0.22,
    numberLeft: 0.50,
    numberRight: 0.98,
    digits: pulse,
    drawGhostSegments: drawGhostSegments,
  );
  _drawMetric(
    display,
    rowX: 0.08,
    rowY: 0.38,
    rowWidth: 0.82,
    rowHeight: 0.22,
    numberLeft: 0.27,
    numberRight: 0.98,
    digits: systolic,
    drawGhostSegments: drawGhostSegments,
  );
  _drawMetric(
    display,
    rowX: 0.08,
    rowY: 0.53,
    rowWidth: 0.82,
    rowHeight: 0.23,
    numberLeft: 0.49,
    numberRight: 0.98,
    digits: diastolic,
    drawGhostSegments: drawGhostSegments,
  );

  return display;
}

void _drawMetric(
  img.Image display, {
  required double rowX,
  required double rowY,
  required double rowWidth,
  required double rowHeight,
  required double numberLeft,
  required double numberRight,
  required String digits,
  required bool drawGhostSegments,
}) {
  final rowLeft = (display.width * rowX).round();
  final rowTop = (display.height * rowY).round();
  final rowPixelWidth = (display.width * rowWidth).round();
  final rowPixelHeight = (display.height * rowHeight).round();
  final numberPixelLeft = rowLeft + (rowPixelWidth * numberLeft).round();
  final numberPixelRight = rowLeft + (rowPixelWidth * numberRight).round();
  final digitWidth = (numberPixelRight - numberPixelLeft) / digits.length;

  for (var index = 0; index < digits.length; index++) {
    final digitLeft = numberPixelLeft + (digitWidth * index).round();
    final digitRight = index == digits.length - 1
        ? numberPixelRight
        : numberPixelLeft + (digitWidth * (index + 1)).round();
    _drawDigit(
      display,
      left: digitLeft,
      top: rowTop + (rowPixelHeight * 0.06).round(),
      width: digitRight - digitLeft,
      height: (rowPixelHeight * 0.88).round(),
      digit: int.parse(digits[index]),
      drawGhostSegments: drawGhostSegments,
    );
  }
}

void _drawDigit(
  img.Image display, {
  required int left,
  required int top,
  required int width,
  required int height,
  required int digit,
  required bool drawGhostSegments,
}) {
  final activeSegments = _digitSegments[digit]!;
  for (var segment = 0; segment < _segmentRegions.length; segment++) {
    if (!activeSegments.contains(segment) && !drawGhostSegments) {
      continue;
    }
    final region = _segmentRegions[segment];
    final color = activeSegments.contains(segment)
        ? img.ColorRgb8(178, 232, 246)
        : img.ColorRgb8(68, 22, 36);
    img.fillRect(
      display,
      x1: left + (width * region.left).round(),
      y1: top + (height * region.top).round(),
      x2: left + (width * region.right).round(),
      y2: top + (height * region.bottom).round(),
      color: color,
      radius: 3,
    );
  }
}

class _SegmentRegion {
  const _SegmentRegion(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;
}

const _segmentRegions = <_SegmentRegion>[
  _SegmentRegion(0.27, 0.03, 0.73, 0.16),
  _SegmentRegion(0.02, 0.17, 0.27, 0.40),
  _SegmentRegion(0.72, 0.17, 0.98, 0.40),
  _SegmentRegion(0.24, 0.44, 0.76, 0.56),
  _SegmentRegion(0.02, 0.61, 0.27, 0.84),
  _SegmentRegion(0.72, 0.61, 0.98, 0.84),
  _SegmentRegion(0.27, 0.84, 0.73, 0.97),
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
