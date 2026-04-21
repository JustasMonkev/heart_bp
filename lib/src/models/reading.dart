enum BloodPressureLevel {
  crisis,
  highStage2,
  highStage1,
  elevated,
  normal,
  low;

  String get label => switch (this) {
        BloodPressureLevel.crisis => 'Crisis',
        BloodPressureLevel.highStage2 => 'High Stage 2',
        BloodPressureLevel.highStage1 => 'High Stage 1',
        BloodPressureLevel.elevated => 'Elevated',
        BloodPressureLevel.normal => 'Normal',
        BloodPressureLevel.low => 'Low',
      };
}

BloodPressureLevel pressureLevelFor(int systolic, int diastolic) {
  if (systolic > 180 || diastolic > 120) return BloodPressureLevel.crisis;
  if (systolic >= 140 || diastolic >= 90) return BloodPressureLevel.highStage2;
  if (systolic >= 130 || diastolic >= 80) return BloodPressureLevel.highStage1;
  if (systolic < 90 || diastolic < 60) return BloodPressureLevel.low;
  if (systolic >= 120 && diastolic < 80) return BloodPressureLevel.elevated;
  return BloodPressureLevel.normal;
}

class Reading {
  const Reading({
    required this.id,
    required this.capturedAt,
    required this.systolic,
    required this.diastolic,
    required this.pulse,
    required this.imagePath,
    required this.rawOcrText,
    required this.createdAt,
  });

  final int id;
  final DateTime capturedAt;
  final int systolic;
  final int diastolic;
  final int pulse;
  final String imagePath;
  final String rawOcrText;
  final DateTime createdAt;

  String get bloodPressureLabel => '$systolic/$diastolic';
  String get systolicDisplayLabel => '$systolic SYS';
  String get diastolicDisplayLabel => '$diastolic DIA';
  String get pulseDisplayLabel => 'Pulse $pulse';
  BloodPressureLevel get pressureLevel => pressureLevelFor(systolic, diastolic);

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'captured_at': capturedAt.millisecondsSinceEpoch,
      'systolic': systolic,
      'diastolic': diastolic,
      'pulse': pulse,
      'image_path': imagePath,
      'raw_ocr_text': rawOcrText,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Reading.fromMap(Map<String, Object?> map) {
    return Reading(
      id: map['id']! as int,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(
        map['captured_at']! as int,
      ),
      systolic: map['systolic']! as int,
      diastolic: map['diastolic']! as int,
      pulse: map['pulse']! as int,
      imagePath: map['image_path']! as String,
      rawOcrText: map['raw_ocr_text']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at']! as int,
      ),
    );
  }
}
