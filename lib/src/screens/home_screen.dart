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
import 'manual_entry_screen.dart';
import 'reading_detail_screen.dart';

final _headerDate = DateFormat('EEE, MMM d');
final _readingDateTime = DateFormat('MMM d · HH:mm');
final _sheetDayDate = DateFormat('EEEE, MMMM d');
final _readingTime = DateFormat('h:mm a');
final _latestTime = DateFormat('HH:mm');
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
  bool _isStreakExpanded = false;
  DateTime? _visibleCalendarMonth;

  Future<void> _startScan() async {
    final scanResult = await widget.captureAndScanService.captureReading(
      context,
    );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save reading: $error')));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Manual reading saved.')));
  }

  void _openReading(Reading reading) {
    Navigator.of(context).push<void>(
      buildHeartRoute<void>(
        builder: (_) => ReadingDetailScreen(
          repository: widget.repository,
          reading: reading,
        ),
      ),
    );
  }

  void _jumpCalendarMonth(int offset, DateTime today) {
    final current = _visibleCalendarMonth ?? DateTime(today.year, today.month);
    final next = DateTime(current.year, current.month + offset);
    final currentMonth = DateTime(today.year, today.month);

    setState(() {
      _visibleCalendarMonth = next.isAfter(currentMonth) ? currentMonth : next;
    });
  }

  Future<void> _showDayReadings(DateTime date, List<Reading> readings) async {
    final sortedReadings = List<Reading>.from(readings)
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (_) => _DayReadingsSheet(date: date, readings: sortedReadings),
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
              final visibleCalendarMonth =
                  _visibleCalendarMonth ??
                  DateTime(summary.today.year, summary.today.month);

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
                  _StreakCard(
                    summary: summary,
                    expanded: _isStreakExpanded,
                    visibleMonth: visibleCalendarMonth,
                    onToggle: () {
                      setState(() => _isStreakExpanded = !_isStreakExpanded);
                    },
                    onPreviousMonth: () {
                      _jumpCalendarMonth(-1, summary.today);
                    },
                    onNextMonth: () {
                      _jumpCalendarMonth(1, summary.today);
                    },
                    onDayTap: _showDayReadings,
                  ),
                  const SizedBox(height: 18),
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
                  const SizedBox(height: 22),
                  Text('RECENT', style: LiquidTheme.eyebrow),
                  const SizedBox(height: 10),
                  if (readings.isEmpty)
                    const _EmptyRecentCard()
                  else
                    ...readings
                        .take(4)
                        .map(
                          (reading) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RecentTile(
                              reading: reading,
                              onTap: () => _openReading(reading),
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
                Text(
                  'Heart',
                  style: LiquidTheme.displayM.copyWith(fontSize: 40),
                ),
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
  const _LatestReadingCard({super.key, required this.reading});

  final Reading reading;

  @override
  Widget build(BuildContext context) {
    final color = levelColor(reading.pressureLevel);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF46516D).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF17203A).withValues(alpha: 0.28),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 17,
                  color: LiquidTheme.accentGlow,
                ),
                const SizedBox(width: 9),
                Text(
                  'HEART BP',
                  style: LiquidTheme.eyebrow.copyWith(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 13,
                    letterSpacing: 2.2,
                  ),
                ),
                const Spacer(),
                Text(
                  _latestTime.format(reading.capturedAt),
                  style: LiquidTheme.mono.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 18,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          reading.systolic.toString(),
                          style: LiquidTheme.numeralXL.copyWith(
                            color: Colors.white,
                            fontSize: 68,
                            letterSpacing: -2.6,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 5,
                            right: 5,
                            bottom: 9,
                          ),
                          child: Text(
                            '/',
                            style: LiquidTheme.numeralXL.copyWith(
                              color: Colors.white.withValues(alpha: 0.34),
                              fontSize: 52,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        Text(
                          reading.diastolic.toString(),
                          style: LiquidTheme.numeralXL.copyWith(
                            color: Colors.white,
                            fontSize: 68,
                            letterSpacing: -2.6,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 9, bottom: 15),
                          child: Text(
                            'mmHg',
                            style: LiquidTheme.bodyMuted.copyWith(
                              color: Colors.white.withValues(alpha: 0.56),
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                _PulsePill(pulse: reading.pulse),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    reading.pressureLevel.label,
                    overflow: TextOverflow.ellipsis,
                    style: LiquidTheme.titleM.copyWith(
                      color: color,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsePill extends StatelessWidget {
  const _PulsePill({required this.pulse});

  final int pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
      decoration: BoxDecoration(
        color: LiquidTheme.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: LiquidTheme.accent.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.favorite_rounded,
            size: 17,
            color: LiquidTheme.accentGlow,
          ),
          const SizedBox(width: 8),
          Text(
            '$pulse bpm',
            style: LiquidTheme.titleM.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
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

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.summary,
    required this.expanded,
    required this.visibleMonth,
    required this.onToggle,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDayTap,
  });

  final _HomeSummary summary;
  final bool expanded;
  final DateTime visibleMonth;
  final VoidCallback onToggle;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final void Function(DateTime date, List<Reading> readings) onDayTap;

  @override
  Widget build(BuildContext context) {
    final canGoNext = _isBeforeMonth(visibleMonth, summary.today);

    return GlassSurface(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      opacity: 0.5,
      blur: 28,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: LiquidTheme.accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: LiquidTheme.accent.withValues(alpha: 0.22),
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 18,
                          color: LiquidTheme.accent,
                        ),
                        Text(
                          '${summary.streak}',
                          style: const TextStyle(
                            color: LiquidTheme.accent,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${summary.streak}-day streak',
                          style: LiquidTheme.titleM.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Log today to keep it going.',
                          style: LiquidTheme.bodyMuted.copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        _LoggedWeekBar(summary: summary),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: LiquidTheme.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 16),
            Divider(
              height: 1,
              thickness: 0.5,
              color: Colors.black.withValues(alpha: 0.07),
            ),
            const SizedBox(height: 14),
            _StreakCalendar(
              summary: summary,
              visibleMonth: visibleMonth,
              canGoNext: canGoNext,
              onPreviousMonth: onPreviousMonth,
              onNextMonth: onNextMonth,
              onDayTap: onDayTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _LoggedWeekBar extends StatelessWidget {
  const _LoggedWeekBar({required this.summary});

  final _HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < summary.loggedWeek.length; index++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: summary.loggedWeek[index]
                        ? LiquidTheme.accent.withValues(
                            alpha: index == summary.loggedWeek.length - 1
                                ? 1
                                : 0.55,
                          )
                        : LiquidTheme.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  summary.weekdayLabels[index],
                  style: LiquidTheme.eyebrow.copyWith(
                    color: LiquidTheme.inkFaint,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
          if (index != summary.loggedWeek.length - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _StreakCalendar extends StatelessWidget {
  const _StreakCalendar({
    required this.summary,
    required this.visibleMonth,
    required this.canGoNext,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDayTap,
  });

  final _HomeSummary summary;
  final DateTime visibleMonth;
  final bool canGoNext;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final void Function(DateTime date, List<Reading> readings) onDayTap;

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(visibleMonth.year, visibleMonth.month);
    final daysInMonth = DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      0,
    ).day;
    final leadingEmptyDays = monthStart.weekday - 1;
    final monthLabel = DateFormat(
      'MMMM yyyy',
    ).format(visibleMonth).toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                monthLabel,
                style: LiquidTheme.eyebrow.copyWith(fontSize: 10),
              ),
            ),
            _CalendarIconButton(
              key: const ValueKey('calendar-previous-month'),
              icon: Icons.chevron_left_rounded,
              onTap: onPreviousMonth,
            ),
            const SizedBox(width: 6),
            _CalendarIconButton(
              key: const ValueKey('calendar-next-month'),
              icon: Icons.chevron_right_rounded,
              onTap: canGoNext ? onNextMonth : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (final day in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Center(
                child: Text(
                  day,
                  style: LiquidTheme.eyebrow.copyWith(
                    color: LiquidTheme.inkFaint,
                    fontSize: 9,
                  ),
                ),
              ),
            for (var index = 0; index < leadingEmptyDays; index++)
              const SizedBox.shrink(),
            for (var day = 1; day <= daysInMonth; day++)
              Builder(
                builder: (context) {
                  final date = DateTime(
                    visibleMonth.year,
                    visibleMonth.month,
                    day,
                  );
                  final readings = summary.readingsByDay[_dayKey.format(date)];
                  return _CalendarDay(
                    day: day,
                    date: date,
                    readings: readings ?? const <Reading>[],
                    today: summary.today,
                    onTap: onDayTap,
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _CalendarIconButton extends StatelessWidget {
  const _CalendarIconButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: enabled ? 0.34 : 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: enabled ? 0.52 : 0.28),
              width: 0.7,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? LiquidTheme.inkSoft : LiquidTheme.inkFaint,
          ),
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.date,
    required this.readings,
    required this.today,
    required this.onTap,
  });

  final int day;
  final DateTime date;
  final List<Reading> readings;
  final DateTime today;
  final void Function(DateTime date, List<Reading> readings) onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = _sameDate(date, today);
    final isLogged = readings.isNotEmpty;
    final key = _dayKey.format(date);

    return Semantics(
      button: true,
      label:
          '${DateFormat('MMMM d').format(date)}, ${readings.length} measurements',
      child: Material(
        key: ValueKey('calendar-day-$key'),
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(date, readings),
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              gradient: isToday
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [LiquidTheme.accent, LiquidTheme.accentGlow],
                    )
                  : null,
              color: isToday
                  ? null
                  : isLogged
                  ? LiquidTheme.accent.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: isToday
                  ? null
                  : Border.all(
                      color: isLogged
                          ? LiquidTheme.accent.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 0.5,
                    ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: isToday
                          ? Colors.white
                          : isLogged
                          ? LiquidTheme.accent
                          : LiquidTheme.inkFaint,
                      fontSize: 9,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (readings.length > 1)
                  Positioned(
                    right: 4,
                    bottom: 3,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isToday ? Colors.white : LiquidTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayReadingsSheet extends StatelessWidget {
  const _DayReadingsSheet({required this.date, required this.readings});

  final DateTime date;
  final List<Reading> readings;

  @override
  Widget build(BuildContext context) {
    final countLabel = readings.length == 1
        ? '1 measurement'
        : '${readings.length} measurements';
    final maxHeight = math.min(MediaQuery.sizeOf(context).height * 0.72, 560.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GlassSurface(
          radius: 32,
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          opacity: 0.66,
          blur: 36,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _sheetDayDate.format(date),
                            style: LiquidTheme.titleL,
                          ),
                          const SizedBox(height: 3),
                          Text(countLabel, style: LiquidTheme.bodyMuted),
                        ],
                      ),
                    ),
                    _CalendarIconButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (readings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No measurements were logged on this day.',
                      style: LiquidTheme.body,
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: readings.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return _DayReadingTile(reading: readings[index]);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayReadingTile extends StatelessWidget {
  const _DayReadingTile({required this.reading});

  final Reading reading;

  @override
  Widget build(BuildContext context) {
    final color = levelColor(reading.pressureLevel);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.44)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reading.bloodPressureLabel,
                      style: LiquidTheme.titleL.copyWith(fontSize: 24),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _readingTime.format(reading.capturedAt),
                        overflow: TextOverflow.ellipsis,
                        style: LiquidTheme.bodyMuted.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(reading.pulseDisplayLabel, style: LiquidTheme.bodyMuted),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _StatusChip(
              label: reading.pressureLevel.label,
              color: color,
              compact: true,
            ),
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
            style: LiquidTheme.numeralL.copyWith(fontSize: 28, color: accent),
          ),
          Text(unit, style: LiquidTheme.bodyMuted),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.summary});

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
            child: const Icon(Icons.lightbulb_rounded, color: Colors.white),
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
  const _RecentTile({required this.reading, required this.onTap});

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
          _StatusChip(
            label: reading.pressureLevel.label,
            color: color,
            compact: true,
          ),
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
    required this.weekdayLabels,
    required this.loggedWeek,
    required this.readingsByDay,
    required this.today,
    required this.streak,
    required this.avgSystolic,
    required this.avgDiastolic,
    required this.avgPulse,
    required this.insightTitle,
    required this.insightBody,
  });

  final List<String> weekdayLabels;
  final List<bool> loggedWeek;
  final Map<String, List<Reading>> readingsByDay;
  final DateTime today;
  final int streak;
  final int avgSystolic;
  final int avgDiastolic;
  final int avgPulse;
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
    final today = DateTime(now.year, now.month, now.day);
    final loggedDays = <String>{};
    final readingsByDay = <String, List<Reading>>{};
    for (final reading in ordered) {
      final capturedDay = DateTime(
        reading.capturedAt.year,
        reading.capturedAt.month,
        reading.capturedAt.day,
      );
      final key = _dayKey.format(capturedDay);
      loggedDays.add(key);
      readingsByDay.putIfAbsent(key, () => <Reading>[]).add(reading);
    }

    final completedDay = today.subtract(const Duration(days: 1));
    final labels = <String>[];
    final loggedWeek = <bool>[];
    for (var index = 6; index >= 0; index--) {
      final day = completedDay.subtract(Duration(days: index));
      labels.add(_weekdayInitial.format(day).substring(0, 1));
      loggedWeek.add(loggedDays.contains(_dayKey.format(day)));
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
      weekdayLabels: labels,
      loggedWeek: loggedWeek,
      readingsByDay: {
        for (final entry in readingsByDay.entries)
          entry.key: List<Reading>.unmodifiable(entry.value),
      },
      today: today,
      streak: _currentStreak(loggedDays, completedDay),
      avgSystolic: avgSystolic,
      avgDiastolic: avgDiastolic,
      avgPulse: avgPulse,
      insightTitle: insightTitle,
      insightBody: insightBody,
    );
  }
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _isBeforeMonth(DateTime a, DateTime b) {
  return a.year < b.year || (a.year == b.year && a.month < b.month);
}

int _currentStreak(Set<String> loggedDays, DateTime today) {
  var count = 0;
  while (loggedDays.contains(
    _dayKey.format(today.subtract(Duration(days: count))),
  )) {
    count++;
  }
  return count;
}
