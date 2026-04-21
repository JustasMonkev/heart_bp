class ReadingValidationResult {
  const ReadingValidationResult({
    this.systolicError,
    this.diastolicError,
    this.pulseError,
  });

  final String? systolicError;
  final String? diastolicError;
  final String? pulseError;

  bool get isValid =>
      systolicError == null && diastolicError == null && pulseError == null;
}

class ReadingValidator {
  static ReadingValidationResult validate({
    required String systolic,
    required String diastolic,
    required String pulse,
  }) {
    return ReadingValidationResult(
      systolicError: _validateMetric(
        name: 'Systolic',
        rawValue: systolic,
        min: 50,
        max: 260,
      ),
      diastolicError: _validateMetric(
        name: 'Diastolic',
        rawValue: diastolic,
        min: 30,
        max: 180,
      ),
      pulseError: _validateMetric(
        name: 'Pulse',
        rawValue: pulse,
        min: 30,
        max: 220,
      ),
    );
  }

  static String? _validateMetric({
    required String name,
    required String rawValue,
    required int min,
    required int max,
  }) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return '$name is required.';
    }

    final value = int.tryParse(trimmed);
    if (value == null) {
      return '$name must be a whole number.';
    }

    if (value < min || value > max) {
      return '$name must be between $min and $max.';
    }

    return null;
  }
}
