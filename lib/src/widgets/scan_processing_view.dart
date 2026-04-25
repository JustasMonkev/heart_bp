import 'package:flutter/material.dart';

import '../services/blood_pressure_tips.dart';
import '../theme/liquid_theme.dart';
import 'liquid_glass.dart';

class ScanProcessingView extends StatelessWidget {
  const ScanProcessingView({super.key, required this.tip});

  final BloodPressureTip tip;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF3ECE5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: GlassSurface(
            radius: 30,
            tint: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: LiquidTheme.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.monitor_heart_outlined,
                    color: LiquidTheme.accent,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Analyzing your reading',
                  style: LiquidTheme.titleL.copyWith(color: LiquidTheme.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  'The photos stay local. We are comparing frames and extracting SYS, DIA, and pulse now.',
                  style: LiquidTheme.body,
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: const LinearProgressIndicator(
                    minHeight: 8,
                    color: LiquidTheme.accent,
                    backgroundColor: Color(0x1AE23E4E),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Health tip',
                  style: LiquidTheme.eyebrow.copyWith(
                    color: LiquidTheme.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tip.title,
                  style: LiquidTheme.titleM.copyWith(color: LiquidTheme.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  tip.message,
                  style: LiquidTheme.bodyMuted.copyWith(
                    color: LiquidTheme.inkSoft,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'General information only. If readings concern you, check with a clinician.',
                  style: LiquidTheme.bodyMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
