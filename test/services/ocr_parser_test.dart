import 'package:flutter_test/flutter_test.dart';
import 'package:heart_bp/src/services/ocr_parser.dart';

void main() {
  group('OcrParser', () {
    final parser = OcrParser();

    test('extracts systolic diastolic and pulse from labeled monitor text', () {
      const rawText = '''
PULSE
62
SYS mmHg
139
DIA mmHg
72
''';

      final result = parser.parse(rawText);

      expect(result.systolic, 139);
      expect(result.diastolic, 72);
      expect(result.pulse, 62);
    });

    test('falls back to likely numeric candidates when labels are noisy', () {
      const rawText = 'AM 01:08 62 139 72 M';

      final result = parser.parse(rawText);

      expect(result.systolic, 139);
      expect(result.diastolic, 72);
      expect(result.pulse, 62);
    });

    test('returns partial results when some metrics are missing', () {
      const rawText = '''
SYS 128
PULSE 64
''';

      final result = parser.parse(rawText);

      expect(result.systolic, 128);
      expect(result.diastolic, isNull);
      expect(result.pulse, 64);
    });

    test('normalizes common seven segment OCR mistakes', () {
      const rawText = '''
PULSE
7Z
SYS mmHg
I5O
DIA mmHg
7B
''';

      final result = parser.parse(rawText);

      expect(result.systolic, 150);
      expect(result.diastolic, 78);
      expect(result.pulse, 72);
    });
  });
}
