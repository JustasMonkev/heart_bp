import 'package:flutter/material.dart';

import '../data/reading_repository.dart';
import '../models/reading.dart';
import '../theme/liquid_theme.dart';
import '../theme/pressure_palette.dart';
import '../widgets/liquid_glass.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key, required this.repository});

  final ReadingRepository repository;

  @override
  Widget build(BuildContext context) {
    return AmbientBackground(
      child: SafeArea(
        child: StreamBuilder<List<Reading>>(
          stream: repository.watchAllReadings(),
          builder: (context, snapshot) {
            final summary = _TimeOfDaySummary.fromReadings(
              snapshot.data ?? const <Reading>[],
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              physics: const BouncingScrollPhysics(),
              children: [
                Text('INSIGHTS', style: LiquidTheme.eyebrow),
                const SizedBox(height: 4),
                Text('Time of Day', style: LiquidTheme.titleL),
                const SizedBox(height: 24),
                GlassSurface(
                  radius: 28,
                  padding: const EdgeInsets.all(22),
                  opacity: 0.55,
                  blur: 28,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionLabel('AVG SYSTOLIC BY HOUR'),
                      const SizedBox(height: 18),
                      _HourlySystolicChart(data: summary.hourly),
                      const SizedBox(height: 18),
                      const _HeatmapLegend(),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _InsightSummaryCard(
                  color: const Color(0xFFE65100),
                  icon: Icons.schedule_rounded,
                  title: summary.peakTitle,
                  body: summary.peakBody,
                ),
                const SizedBox(height: 10),
                _InsightSummaryCard(
                  color: const Color(0xFF2E8B57),
                  icon: Icons.info_outline_rounded,
                  title: summary.lowestTitle,
                  body: summary.lowestBody,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: LiquidTheme.eyebrow);
  }
}

class _HourlySystolicChart extends StatelessWidget {
  const _HourlySystolicChart({required this.data});

  final List<_HourlySystolic> data;

  @override
  Widget build(BuildContext context) {
    final activeData = data.where((item) => item.readingCount > 0);
    final maxSys = activeData.isEmpty
        ? 180
        : activeData
              .map((item) => item.averageSystolic)
              .reduce((a, b) => a > b ? a : b);
    final scaleTop = maxSys < 140 ? 140 : maxSys;

    return Column(
      children: [
        SizedBox(
          height: 104,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((item) {
              final value = item.readingCount == 0
                  ? 0.06
                  : ((item.averageSystolic - 105) / (scaleTop - 105)).clamp(
                      0.12,
                      1.0,
                    );
              final color = _hourColor(item);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: value,
                      widthFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color.withValues(
                            alpha: item.readingCount == 0 ? 0.24 : 0.82,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: data.map((item) {
            final label = switch (item.hour) {
              0 => '12a',
              3 => '3a',
              6 => '6a',
              9 => '9a',
              12 => '12p',
              15 => '3p',
              18 => '6p',
              21 => '9p',
              _ => '',
            };

            return Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: LiquidTheme.mono.copyWith(
                  color: LiquidTheme.inkMuted,
                  fontSize: 9,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  static Color _hourColor(_HourlySystolic item) {
    if (item.readingCount == 0) return Colors.black;
    if (item.averageSystolic >= 140) {
      return levelColor(BloodPressureLevel.highStage2);
    }
    if (item.averageSystolic >= 130) {
      return levelColor(BloodPressureLevel.highStage1);
    }
    if (item.averageSystolic >= 120) {
      return levelColor(BloodPressureLevel.elevated);
    }
    return levelColor(BloodPressureLevel.normal);
  }
}

class _HourlySystolic {
  const _HourlySystolic(this.hour, this.averageSystolic, this.readingCount);

  final int hour;
  final int averageSystolic;
  final int readingCount;
}

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend();

  @override
  Widget build(BuildContext context) {
    const items = [
      (label: 'Normal', level: BloodPressureLevel.normal),
      (label: 'Elevated', level: BloodPressureLevel.elevated),
      (label: 'High 1', level: BloodPressureLevel.highStage1),
      (label: 'High 2', level: BloodPressureLevel.highStage2),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: items.map((item) {
        final color = levelColor(item.level);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              item.label,
              style: LiquidTheme.bodyMuted.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _InsightSummaryCard extends StatelessWidget {
  const _InsightSummaryCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      opacity: 0.48,
      blur: 24,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: LiquidTheme.titleM),
                const SizedBox(height: 2),
                Text(body, style: LiquidTheme.bodyMuted.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeOfDaySummary {
  const _TimeOfDaySummary({
    required this.hourly,
    required this.peakTitle,
    required this.peakBody,
    required this.lowestTitle,
    required this.lowestBody,
  });

  final List<_HourlySystolic> hourly;
  final String peakTitle;
  final String peakBody;
  final String lowestTitle;
  final String lowestBody;

  factory _TimeOfDaySummary.fromReadings(List<Reading> readings) {
    final byHour = <int, List<int>>{
      for (var hour = 0; hour < 24; hour++) hour: <int>[],
    };

    for (final reading in readings) {
      byHour[reading.capturedAt.hour]!.add(reading.systolic);
    }

    final hourly = [
      for (var hour = 0; hour < 24; hour++)
        _HourlySystolic(
          hour,
          _average(byHour[hour]!, fallback: 0),
          byHour[hour]!.length,
        ),
    ];

    if (readings.isEmpty) {
      return _TimeOfDaySummary(
        hourly: hourly,
        peakTitle: 'Add more readings',
        peakBody:
            'Measure at different times of day to reveal when your systolic pressure runs highest.',
        lowestTitle: 'No low point yet',
        lowestBody:
            'Once readings are logged, this card will show your lowest time-of-day average.',
      );
    }

    final completeWindows = <_HourlyWindow>[];
    final partialWindows = <_HourlyWindow>[];
    for (var startHour = 0; startHour <= 21; startHour++) {
      final values = <int>[];
      var hoursWithReadings = 0;
      for (var hour = startHour; hour <= startHour + 2; hour++) {
        final hourValues = byHour[hour]!;
        if (hourValues.isNotEmpty) hoursWithReadings++;
        values.addAll(hourValues);
      }
      if (values.isEmpty) continue;
      final window = _HourlyWindow(
        startHour: startHour,
        averageSystolic: _average(values, fallback: 0),
      );
      if (hoursWithReadings == 3) {
        completeWindows.add(window);
      } else {
        partialWindows.add(window);
      }
    }

    final windows = completeWindows.isNotEmpty
        ? completeWindows
        : partialWindows;
    final peak = windows.reduce((a, b) {
      return a.averageSystolic >= b.averageSystolic ? a : b;
    });
    final lowest = windows.reduce((a, b) {
      return a.averageSystolic <= b.averageSystolic ? a : b;
    });

    return _TimeOfDaySummary(
      hourly: hourly,
      peakTitle: 'Peak at ${_hourRangeLabel(peak.startHour)}',
      peakBody:
          'Avg ${peak.averageSystolic} mmHg - highest time-of-day average.',
      lowestTitle: 'Lowest at ${_hourRangeLabel(lowest.startHour)}',
      lowestBody:
          'Avg ${lowest.averageSystolic} mmHg - lowest time-of-day average.',
    );
  }
}

class _HourlyWindow {
  const _HourlyWindow({required this.startHour, required this.averageSystolic});

  final int startHour;
  final int averageSystolic;
}

int _average(List<int> values, {required int fallback}) {
  if (values.isEmpty) return fallback;
  var sum = 0;
  for (final value in values) {
    sum += value;
  }
  return (sum / values.length).round();
}

String _hourRangeLabel(int startHour) {
  final endHour = startHour + 2;
  if (_period(startHour) == _period(endHour)) {
    return '${_hourNumber(startHour)} - ${_hourNumber(endHour)} ${_period(startHour)}';
  }
  return '${_hourLabel(startHour)} - ${_hourLabel(endHour)}';
}

String _hourLabel(int hour) => '${_hourNumber(hour)} ${_period(hour)}';

int _hourNumber(int hour) {
  final normalized = hour % 12;
  return normalized == 0 ? 12 : normalized;
}

String _period(int hour) => hour < 12 ? 'AM' : 'PM';
