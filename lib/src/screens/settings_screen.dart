import 'package:flutter/material.dart';

import '../theme/liquid_theme.dart';
import '../widgets/liquid_glass.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.onExportPdf,
    this.isExporting = false,
  });

  final VoidCallback? onExportPdf;
  final bool isExporting;

  @override
  Widget build(BuildContext context) {
    return AmbientBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
          physics: const BouncingScrollPhysics(),
          children: [
            Text('SETTINGS', style: LiquidTheme.eyebrow),
            const SizedBox(height: 28),
            GlassSurface(
              radius: 28,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              opacity: 0.5,
              blur: 28,
              onTap: isExporting ? null : onExportPdf,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Export PDF',
                      style: LiquidTheme.titleL.copyWith(fontSize: 28),
                    ),
                  ),
                  SizedBox.square(
                    dimension: 24,
                    child: isExporting
                        ? const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              LiquidTheme.ink,
                            ),
                          )
                        : const Icon(
                            Icons.chevron_right_rounded,
                            color: LiquidTheme.inkFaint,
                            size: 24,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
