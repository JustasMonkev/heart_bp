import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../app.dart' show levelColor;
import '../data/reading_repository.dart';
import '../models/reading.dart';
import '../theme/liquid_theme.dart';
import '../widgets/liquid_glass.dart';
import 'reading_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.repository,
  });

  final ReadingRepository repository;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isExporting = false;

  Future<void> _exportReport() async {
    setState(() => _isExporting = true);

    try {
      final report = await widget.repository.createPdfReport();
      await Printing.sharePdf(bytes: report.bytes, filename: report.filename);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d · HH:mm');

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    const LiquidBackButton(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ARCHIVE', style: LiquidTheme.eyebrow),
                          const SizedBox(height: 2),
                          Text('History', style: LiquidTheme.titleL),
                        ],
                      ),
                    ),
                    LiquidIconAction(
                      icon: Icons.ios_share_rounded,
                      busy: _isExporting,
                      onPressed: _isExporting ? null : _exportReport,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Reading>>(
                  stream: widget.repository.watchAllReadings(),
                  builder: (context, snapshot) {
                    final readings = snapshot.data ?? const <Reading>[];
                    if (readings.isEmpty) return const _EmptyHistory();

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final reading = readings[index];
                        return _HistoryTile(
                          reading: reading,
                          formatter: formatter,
                          onTap: () {
                            Navigator.of(context).push(
                              PageRouteBuilder<void>(
                                transitionDuration: const Duration(milliseconds: 320),
                                pageBuilder: (_, _, _) => ReadingDetailScreen(
                                  repository: widget.repository,
                                  reading: reading,
                                ),
                                transitionsBuilder: (_, animation, _, child) {
                                  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
                                  return FadeTransition(
                                    opacity: curved,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.04),
                                        end: Offset.zero,
                                      ).animate(curved),
                                      child: child,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemCount: readings.length,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.reading,
    required this.formatter,
    required this.onTap,
  });

  final Reading reading;
  final DateFormat formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = levelColor(reading.pressureLevel);

    return GlassSurface(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      opacity: 0.5,
      blur: 24,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 46,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      reading.bloodPressureLabel,
                      style: LiquidTheme.numeralL,
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('mmHg', style: LiquidTheme.bodyMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      formatter.format(reading.capturedAt),
                      style: LiquidTheme.mono,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('·', style: TextStyle(color: LiquidTheme.inkFaint)),
                    ),
                    const Icon(Icons.favorite_rounded, size: 12, color: LiquidTheme.accent),
                    const SizedBox(width: 4),
                    Text('${reading.pulse} bpm', style: LiquidTheme.mono),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
            ),
            child: Text(
              reading.pressureLevel.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: LiquidTheme.inkFaint, size: 22),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassSurface(
          radius: 28,
          padding: const EdgeInsets.all(28),
          opacity: 0.5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassSurface(
                radius: 99,
                padding: const EdgeInsets.all(18),
                opacity: 0.35,
                blur: 20,
                shadow: false,
                child: const Icon(Icons.monitor_heart_rounded, size: 28, color: LiquidTheme.accent),
              ),
              const SizedBox(height: 20),
              Text('Nothing logged yet', style: LiquidTheme.titleL),
              const SizedBox(height: 8),
              Text(
                'Scan your first reading to start building\na local, private history.',
                textAlign: TextAlign.center,
                style: LiquidTheme.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
