import 'package:flutter/material.dart';

import '../models/reading.dart';

const Color diastolicAccent = Color(0xFFC29400);
const Color pulseAccent = Color(0xFF4D77BB);
const Color reminderTint = Color(0xFFF4E5D3);

Color levelColor(BloodPressureLevel level) {
  return switch (level) {
    BloodPressureLevel.crisis => const Color(0xFFD32F2F),
    BloodPressureLevel.highStage2 => const Color(0xFFE65100),
    BloodPressureLevel.highStage1 => const Color(0xFFEF8B25),
    BloodPressureLevel.elevated => const Color(0xFFBF8F00),
    BloodPressureLevel.normal => const Color(0xFF2E8B57),
    BloodPressureLevel.low => const Color(0xFF4A78B8),
  };
}
