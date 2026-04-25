import 'package:flutter/material.dart';

class ScanGuidanceOverlay extends StatelessWidget {
  const ScanGuidanceOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: double.infinity,
              height: 360,
              margin: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2.5),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 22,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: CustomPaint(painter: _GuideCornerPainter()),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: const [
                _GuideChip(icon: Icons.fit_screen_rounded, label: 'Fill frame'),
                _GuideChip(icon: Icons.flare_rounded, label: 'No glare'),
                _GuideChip(
                  icon: Icons.filter_center_focus_rounded,
                  label: 'Multi-frame',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideChip extends StatelessWidget {
  const _GuideChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE23E4E)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const length = 42.0;
    const inset = 10.0;

    canvas
      ..drawLine(const Offset(inset, inset), const Offset(length, inset), paint)
      ..drawLine(const Offset(inset, inset), const Offset(inset, length), paint)
      ..drawLine(
        Offset(size.width - inset, inset),
        Offset(size.width - length, inset),
        paint,
      )
      ..drawLine(
        Offset(size.width - inset, inset),
        Offset(size.width - inset, length),
        paint,
      )
      ..drawLine(
        Offset(inset, size.height - inset),
        Offset(length, size.height - inset),
        paint,
      )
      ..drawLine(
        Offset(inset, size.height - inset),
        Offset(inset, size.height - length),
        paint,
      )
      ..drawLine(
        Offset(size.width - inset, size.height - inset),
        Offset(size.width - length, size.height - inset),
        paint,
      )
      ..drawLine(
        Offset(size.width - inset, size.height - inset),
        Offset(size.width - inset, size.height - length),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
