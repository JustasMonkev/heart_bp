import 'package:flutter/material.dart';

class LiquidTheme {
  LiquidTheme._();

  static const Color canvasTop = Color(0xFFFBF7F2);
  static const Color canvasBottom = Color(0xFFEFE7DF);

  static const Color ink = Color(0xFF0B0B0F);
  static const Color inkSoft = Color(0xFF3A3A3F);
  static const Color inkMuted = Color(0xFF7A7A81);
  static const Color inkFaint = Color(0xFFB0B0B6);

  static const Color accent = Color(0xFFE23E4E);
  static const Color accentGlow = Color(0xFFFF7C6B);
  static const Color mint = Color(0xFF2FB67A);
  static const Color amber = Color(0xFFE89B2E);

  static const Color glassStroke = Color(0xB3FFFFFF);
  static const Color glassStrokeSoft = Color(0x66FFFFFF);
  static const Color glassShadow = Color(0x14000000);

  static TextStyle _base(double size, FontWeight weight, {double tracking = 0, Color color = ink, double height = 1.1}) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: tracking,
      color: color,
      height: height,
    );
  }

  static final TextStyle numeralXL = _base(88, FontWeight.w700, tracking: -3.5, height: 0.95);
  static final TextStyle numeralL = _base(44, FontWeight.w600, tracking: -1.4, height: 1.0);
  static final TextStyle displayM = _base(32, FontWeight.w600, tracking: -0.9);
  static final TextStyle titleL = _base(22, FontWeight.w600, tracking: -0.4);
  static final TextStyle titleM = _base(17, FontWeight.w600, tracking: -0.2);
  static final TextStyle body = _base(15, FontWeight.w400, tracking: -0.1, color: inkSoft, height: 1.35);
  static final TextStyle bodyMuted = _base(14, FontWeight.w400, tracking: -0.05, color: inkMuted, height: 1.35);
  static final TextStyle eyebrow = _base(11, FontWeight.w600, tracking: 1.6, color: inkMuted).copyWith(
    fontFeatures: const [FontFeature.enable('tnum')],
  );
  static final TextStyle mono = _base(13, FontWeight.w500, tracking: 0.4, color: inkSoft).copyWith(
    fontFeatures: const [FontFeature.enable('tnum')],
  );
}
