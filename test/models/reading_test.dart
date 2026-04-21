import 'package:flutter_test/flutter_test.dart';
import 'package:heart_bp/src/models/reading.dart';

void main() {
  group('Reading pressureLevel', () {
    test('classifies low blood pressure', () {
      expect(_reading(88, 58).pressureLevel.label, 'Low');
    });

    test('classifies normal blood pressure', () {
      expect(_reading(118, 76).pressureLevel.label, 'Normal');
    });

    test('classifies elevated blood pressure', () {
      expect(_reading(126, 78).pressureLevel.label, 'Elevated');
    });

    test('classifies stage 1 high blood pressure', () {
      expect(_reading(136, 73).pressureLevel.label, 'High Stage 1');
    });

    test('classifies stage 2 high blood pressure', () {
      expect(_reading(148, 92).pressureLevel.label, 'High Stage 2');
    });

    test('classifies crisis blood pressure', () {
      expect(_reading(182, 121).pressureLevel.label, 'Crisis');
    });
  });
}

Reading _reading(int systolic, int diastolic) {
  return Reading(
    id: 1,
    capturedAt: DateTime(2026, 4, 21, 9, 5),
    systolic: systolic,
    diastolic: diastolic,
    pulse: 62,
    imagePath: '/tmp/reading.jpg',
    rawOcrText: '',
    createdAt: DateTime(2026, 4, 21, 9, 5),
  );
}
