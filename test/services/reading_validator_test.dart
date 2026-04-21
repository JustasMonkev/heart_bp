import 'package:flutter_test/flutter_test.dart';
import 'package:heart_bp/src/services/reading_validator.dart';

void main() {
  group('ReadingValidator', () {
    test('accepts in-range numeric values', () {
      final result = ReadingValidator.validate(
        systolic: '139',
        diastolic: '72',
        pulse: '62',
      );

      expect(result.isValid, isTrue);
      expect(result.systolicError, isNull);
      expect(result.diastolicError, isNull);
      expect(result.pulseError, isNull);
    });

    test('rejects missing values', () {
      final result = ReadingValidator.validate(
        systolic: '',
        diastolic: '72',
        pulse: '',
      );

      expect(result.isValid, isFalse);
      expect(result.systolicError, isNotNull);
      expect(result.pulseError, isNotNull);
    });

    test('rejects non numeric and out of range values', () {
      final result = ReadingValidator.validate(
        systolic: 'abc',
        diastolic: '12',
        pulse: '300',
      );

      expect(result.isValid, isFalse);
      expect(result.systolicError, contains('number'));
      expect(result.diastolicError, contains('30'));
      expect(result.pulseError, contains('220'));
    });
  });
}
