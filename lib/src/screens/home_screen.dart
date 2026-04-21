import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/reading_repository.dart';
import '../models/reading.dart';
import '../navigation/heart_page_route.dart';
import '../services/capture_and_scan_service.dart';
import '../theme/liquid_theme.dart';
import '../theme/pressure_palette.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/reading_editor_sheet.dart';
import 'history_screen.dart';
import 'manual_entry_screen.dart';

final _headerDate = DateFormat('EEE, MMM d');
final _readingDateTime = DateFormat('MMM d · HH:mm');
final _dayKey = DateFormat('yyyy-MM-dd');
final _weekdayInitial = DateFormat('E');

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.captureAndScanService,
  });

  final ReadingRepository repository;
  final CaptureAndScanService captureAndScanService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSaving = false;

  Future<void> _startScan() async {
    final scanResult = await widget.captureAndScanService.captureReading(context);
    await _handleScanResult(scanResult);
  }

  Future<void> _handleScanResult(ScanCaptureResult? scanResult) async {
    if (!mounted || scanResult == null) return;

    final draft = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) => ReadingEditorSheet(scanResult: scanResult),
    );

    if (!mounted || draft == null) return;

    setState(() => _isSaving = true);
    try {
      await widget.repository.saveReading(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reading saved to history.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save reading: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openQuickEntry() async {
    final saved = await Navigator.of(context).push<bool>(
      buildHeartRoute<bool>(
        builder: (_) => ManualEntryScreen(repository: widget.repository),
      ),
    );

    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Manual reading saved.')),
    );
  }

  void _openHistory() {
    Navigator.of(context).push<void>(
      buildHeartRoute<void>(
        builder: (_) => HistoryScreen(repository: widget.repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: StreamBuilder<List<Reading>>(
            stream: widget.repository.watchAllReadings(),
            builder: (context, snapshot) {
              final readings = snapshot.data ?? const <Reading>[];
              final latest = readings.isNotEmpty ? readings.first : null;
              final summary = _HomeSummary.fromReadings(readings);

              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                physics: const BouncingScrollPhysics(),
                children: [
                  const _HomeHeader(),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: latest == null
                        ? const _EmptyLatestCard()
                        : _LatestReadingCard(
                            key: ValueKey<int>(latest.id),
                            reading: latest,
                          ),
                  ),
                  const SizedBox(height: 18),
                  _TrendCard(summary: summary),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _AverageTile(
                          label: 'AVG SYS',
                          value: summary.avgSystolic,
                          unit: 'mmHg',
                          accent: LiquidTheme.amber,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _AverageTile(
                          label: 'AVG DIA',
                          value: summary.avgDiastolic,
                          unit: 'mmHg',
                          accent: diastolicAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _AverageTile(
                          label: 'AVG PULSE',
                          value: summary.avgPulse,
                          unit: 'bpm',
                          accent: pulseAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _InsightCard(summary: summary),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        flex: 7,
                        child: GlassButton(
                          label: 'Quick entry',
                          icon: Icons.add_rounded,
                          primary: true,
                          onPressed: _isSaving ? null : _openQuickEntry,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: GlassButton(
                          label: _isSaving ? 'Saving…' : 'Scan',
                          icon: Icons.center_focus_strong_rounded,
                          onPressed: _isSaving ? null : _startScan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GlassButton(
                    label: 'Open history',
                    icon: Icons.auto_stories_rounded,
                    onPressed: _isSaving ? null : _openHistory,
                  ),
                  const SizedBox(height: 22),
                  Text('RECENT', style: LiquidTheme.eyebrow),
                  const SizedBox(height: 10),
                  if (readings.isEmpty)
                    const _EmptyRecentCard()
                  else
                    ...readings.take(4).map(
                          (reading) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RecentTile(
                              reading: reading,
                              onTap: _openHistory,
                            ),
                          ),
                        ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final date = _headerDate.format(DateTime.now()).toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: LiquidTheme.eyebrow),
                const SizedBox(height: 4),
                Text('Heart', style: LiquidTheme.displayM.copyWith(fontSize: 40)),
              ],
            ),
          ),
          GlassSurface(
            radius: 99,
            padding: const EdgeInsets.all(14),
            opacity: 0.46,
            blur: 22,
            shadow: false,
            child: const Icon(
              Icons.favorite_rounded,
              size: 22,
              color: LiquidTheme.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestReadingCard extends StatelessWidget {
  const _LatestReadingCard({
    super.key,
    required this.reading,
  });

  final Reading reading;

  @override
  Widget build(BuildContext context) {
    final color = levelColor(reading.pressureLevel);

    return GlassSurface(
      radius: 38,
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      opacity: 0.58,
      blur: 36,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('LATEST READING', style: LiquidTheme.eyebrow),
              const Spacer(),
              _StatusChip(label: reading.pressureLevel.label, color: color),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(reading.systolic.toString(), style: LiquidTheme.numeralXL),
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 6, right: 6),
                child: Text(
                  '/',
                  style: LiquidTheme.numeralXL.copyWith(
                    color: LiquidTheme.inkFaint,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              Text(reading.diastolic.toString(), style: LiquidTheme.numeralXL),
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 16),
                child: Text('mmHg', style: LiquidTheme.bodyMuted.copyWith(fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GlassPill(
                label: '${reading.pulse} BPM',
                accent: LiquidTheme.ink,
                leading: const Icon(
                  Icons.favorite_rounded,
                  size: 14,
                  color: LiquidTheme.accent,
                ),
              ),
              const Spacer(),
              Text(
                _readingDateTime.format(reading.capturedAt),
                style: LiquidTheme.bodyMuted.copyWith(fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyLatestCard extends StatelessWidget {
  const _EmptyLatestCard();

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 38,
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
      opacity: 0.56,
      blur: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LATEST READING', style: LiquidTheme.eyebrow),
          const SizedBox(height: 12),
          Text('No readings yet', style: LiquidTheme.displayM),
          const SizedBox(height: 10),
          Text(
            'Use Quick entry or Scan to start building your private blood-pressure history.',
            style: LiquidTheme.body,
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.summary,
  });

  final _HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final trendColor = summary.delta <= 0 ? LiquidTheme.mint : LiquidTheme.accent;
    return GlassSurface(
      radius: 34,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      opacity: 0.54,
      blur: 32,
      child: Column(
        children: [
          Row(
            children: [
              Text('7-DAY SYSTOLIC', style: LiquidTheme.eyebrow),
              const Spacer(),
              Text(
                '${summary.delta <= 0 ? '↘' : '↗'} ${summary.delta.abs()} mmHg',
                style: LiquidTheme.titleM.copyWith(
                  color: trendColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 88,
            child: CustomPaint(
              painter: _TrendPainter(values: summary.weeklySystolic),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: summary.weekdayLabels
                .map(
                  (label) => Text(
                    label,
                    style: LiquidTheme.eyebrow.copyWith(
                      color: label == summary.weekdayLabels.last
                          ? LiquidTheme.ink
                          : LiquidTheme.inkFaint,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AverageTile extends StatelessWidget {
  const _AverageTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
  });

  final String label;
  final int value;
  final String unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      opacity: 0.46,
      blur: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: LiquidTheme.eyebrow),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: LiquidTheme.numeralL.copyWith(
              fontSize: 28,
              color: accent,
            ),
          ),
          Text(unit, style: LiquidTheme.bodyMuted),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.summary,
  });

  final _HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 34,
      padding: const EdgeInsets.all(20),
      opacity: 0.52,
      blur: 32,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [LiquidTheme.accent, LiquidTheme.accentGlow],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.insightTitle, style: LiquidTheme.titleL),
                const SizedBox(height: 4),
                Text(summary.insightBody, style: LiquidTheme.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.reading,
    required this.onTap,
  });

  final Reading reading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = levelColor(reading.pressureLevel);

    return GlassSurface(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      opacity: 0.5,
      blur: 24,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reading.bloodPressureLabel,
                  style: LiquidTheme.numeralL.copyWith(fontSize: 30),
                ),
                const SizedBox(height: 2),
                Text(
                  _readingDateTime.format(reading.capturedAt),
                  style: LiquidTheme.bodyMuted.copyWith(fontSize: 16),
                ),
              ],
            ),
          ),
          _StatusChip(label: reading.pressureLevel.label, color: color, compact: true),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: LiquidTheme.inkFaint,
          ),
        ],
      ),
    );
  }
}

class _EmptyRecentCard extends StatelessWidget {
  const _EmptyRecentCard();

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 26,
      padding: const EdgeInsets.all(18),
      opacity: 0.42,
      blur: 24,
      child: Text(
        'Recent readings will show here after your first save.',
        style: LiquidTheme.body,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.values,
  });

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxValue = values.reduce(math.max).toDouble();
    final minValue = values.reduce(math.min).toDouble();
    final span = math.max(1.0, maxValue - minValue);
    final step = values.length == 1 ? 0.0 : size.width / (values.length - 1);
    final points = <Offset>[];

    for (var i = 0; i < values.length; i++) {
      final normalized = (values[i] - minValue) / span;
      final y = size.height - (normalized * (size.height - 8)) - 4;
      points.add(Offset(step * i, y));
    }

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    fillPath.lineTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      fillPath.quadraticBezierTo(controlX, previous.dy, current.dx, current.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            LiquidTheme.accent.withValues(alpha: 0.16),
            LiquidTheme.accent.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      linePath.quadraticBezierTo(controlX, previous.dy, current.dx, current.dy);
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = LiquidTheme.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(
      points.last,
      5.5,
      Paint()..color = LiquidTheme.accent,
    );
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

int _avg(Iterable<int> values, int fallback) {
  if (values.isEmpty) return fallback;
  var sum = 0;
  var count = 0;
  for (final value in values) {
    sum += value;
    count++;
  }
  return (sum / count).round();
}

class _HomeSummary {
  const _HomeSummary({
    required this.weeklySystolic,
    required this.weekdayLabels,
    required this.avgSystolic,
    required this.avgDiastolic,
    required this.avgPulse,
    required this.delta,
    required this.insightTitle,
    required this.insightBody,
  });

  final List<int> weeklySystolic;
  final List<String> weekdayLabels;
  final int avgSystolic;
  final int avgDiastolic;
  final int avgPulse;
  final int delta;
  final String insightTitle;
  final String insightBody;

  factory _HomeSummary.fromReadings(List<Reading> readings) {
    final ordered = List<Reading>.from(readings)
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
    final recentStart = ordered.length > 7 ? ordered.length - 7 : 0;
    final recent = ordered.isEmpty
        ? <Reading>[]
        : ordered.skip(recentStart).toList();

    final now = DateTime.now();
    final recentByDate = <String, Reading>{};
    for (final reading in ordered) {
      recentByDate[_dayKey.format(reading.capturedAt)] = reading;
    }

    final lastKnown = ordered.isNotEmpty ? ordered.last.systolic : 120;
    final weekly = <int>[];
    final labels = <String>[];
    var fallback = lastKnown;
    for (var index = 6; index >= 0; index--) {
      final day = DateTime(now.year, now.month, now.day).subtract(
        Duration(days: index),
      );
      final reading = recentByDate[_dayKey.format(day)];
      if (reading != null) {
        fallback = reading.systolic;
      }
      weekly.add(fallback);
      labels.add(_weekdayInitial.format(day).substring(0, 1));
    }

    final avgSystolic = _avg(recent.map((r) => r.systolic), 120);
    final avgDiastolic = _avg(recent.map((r) => r.diastolic), 80);
    final avgPulse = _avg(recent.map((r) => r.pulse), 72);

    final morning = recent.where((item) => item.capturedAt.hour < 12);
    final evening = recent.where((item) => item.capturedAt.hour >= 12);
    final morningAvg = _avg(morning.map((r) => r.systolic), avgSystolic);
    final eveningAvg = _avg(evening.map((r) => r.systolic), avgSystolic);

    final insightTitle = morningAvg > eveningAvg + 4
        ? 'BP peaks in the morning'
        : recent.length >= 3
            ? 'Trend looks steady'
            : 'Build your baseline';
    final insightBody = morningAvg > eveningAvg + 4
        ? 'Morning avg $morningAvg/$avgDiastolic — consider checking before coffee.'
        : recent.length >= 3
            ? 'Your last ${recent.length} readings are staying within a fairly narrow range.'
            : 'Add a few readings across the week to unlock stronger trend insights.';

    return _HomeSummary(
      weeklySystolic: weekly,
      weekdayLabels: labels,
      avgSystolic: avgSystolic,
      avgDiastolic: avgDiastolic,
      avgPulse: avgPulse,
      delta: weekly.last - weekly.first,
      insightTitle: insightTitle,
      insightBody: insightBody,
    );
  }
}
