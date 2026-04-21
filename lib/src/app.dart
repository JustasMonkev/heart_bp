import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'data/reading_repository.dart';
import 'models/reading.dart';
import 'screens/history_screen.dart';
import 'services/capture_and_scan_service.dart';
import 'theme/liquid_theme.dart';
import 'widgets/liquid_glass.dart';
import 'widgets/reading_editor_sheet.dart';

class HeartBpApp extends StatelessWidget {
  const HeartBpApp({
    super.key,
    required this.repository,
    required this.captureAndScanService,
  });

  final ReadingRepository repository;
  final CaptureAndScanService captureAndScanService;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: LiquidTheme.accent,
      brightness: Brightness.light,
      surface: LiquidTheme.canvasTop,
    );

    return MaterialApp(
      title: 'Blood Pressure Log',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: Typography.blackCupertino.apply(
          bodyColor: LiquidTheme.ink,
          displayColor: LiquidTheme.ink,
        ),
        splashFactory: InkRipple.splashFactory,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: LiquidTheme.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.55),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: LiquidTheme.ink, width: 1.2),
          ),
          labelStyle: const TextStyle(color: LiquidTheme.inkMuted, letterSpacing: -0.1),
          helperStyle: const TextStyle(color: LiquidTheme.inkFaint, letterSpacing: -0.05),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: LiquidTheme.ink,
          contentTextStyle: const TextStyle(color: Colors.white, letterSpacing: -0.1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      home: HomeScreen(
        repository: repository,
        captureAndScanService: captureAndScanService,
      ),
    );
  }
}

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
  bool _isAnalyzingUpload = false;

  Future<void> _startScan() async {
    final scanResult = await widget.captureAndScanService.captureReading(context);
    await _handleScanResult(scanResult);
  }

  Future<void> _startUpload() async {
    setState(() => _isAnalyzingUpload = true);

    ScanCaptureResult? scanResult;
    try {
      scanResult = await widget.captureAndScanService.pickReadingFromFiles(context);
    } finally {
      if (mounted) setState(() => _isAnalyzingUpload = false);
    }

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

  void _openHistory() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => HistoryScreen(repository: widget.repository),
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
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isSaving || _isAnalyzingUpload;

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              StreamBuilder<List<Reading>>(
                stream: widget.repository.watchAllReadings(),
                builder: (context, snapshot) {
                  final readings = snapshot.data ?? const <Reading>[];
                  final latest = readings.isNotEmpty ? readings.first : null;
                  final recent = readings.length > 1
                      ? readings.skip(1).take(3).toList()
                      : const <Reading>[];

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      const _TopBar(),
                      const SizedBox(height: 24),
                      _HeroCard(reading: latest),
                      const SizedBox(height: 22),
                      _ActionsRow(
                        isBusy: isBusy,
                        isSaving: _isSaving,
                        onScan: isBusy ? null : _startScan,
                        onUpload: isBusy ? null : _startUpload,
                      ),
                      const SizedBox(height: 14),
                      GlassButton(
                        label: 'Open history',
                        icon: Icons.auto_stories_outlined,
                        onPressed: isBusy ? null : _openHistory,
                      ),
                      if (recent.isNotEmpty) ...[
                        const SizedBox(height: 34),
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 10),
                          child: Text('RECENT', style: LiquidTheme.eyebrow),
                        ),
                        ...recent.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RecentTile(reading: r, onTap: _openHistory),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              if (_isAnalyzingUpload) const _BusyOverlay(message: 'Analyzing photo…'),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = DateFormat('EEEE, MMM d').format(now);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date.toUpperCase(), style: LiquidTheme.eyebrow),
                const SizedBox(height: 4),
                Text('Heart', style: LiquidTheme.displayM),
              ],
            ),
          ),
          GlassSurface(
            radius: 99,
            padding: const EdgeInsets.all(12),
            opacity: 0.5,
            blur: 22,
            shadow: false,
            child: const Icon(Icons.favorite_rounded, size: 18, color: LiquidTheme.accent),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.reading});

  final Reading? reading;

  @override
  Widget build(BuildContext context) {
    if (reading == null) return const _EmptyHero();

    final r = reading!;
    final level = r.pressureLevel;
    final capturedAt = DateFormat('MMM d · HH:mm').format(r.capturedAt);

    return GlassSurface(
      radius: 34,
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
      opacity: 0.58,
      blur: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('LATEST READING', style: LiquidTheme.eyebrow),
              const Spacer(),
              _LevelChip(level: level),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                r.systolic.toString(),
                style: LiquidTheme.numeralXL.copyWith(color: LiquidTheme.ink),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8, top: 14),
                child: Text(
                  '/',
                  style: TextStyle(
                    fontSize: 54,
                    fontWeight: FontWeight.w300,
                    color: LiquidTheme.inkFaint.withValues(alpha: 0.8),
                    height: 1,
                  ),
                ),
              ),
              Text(
                r.diastolic.toString(),
                style: LiquidTheme.numeralXL.copyWith(color: LiquidTheme.ink),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('mmHg', style: LiquidTheme.bodyMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _PulseBadge(bpm: r.pulse),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  capturedAt,
                  style: LiquidTheme.bodyMuted,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 34,
      padding: const EdgeInsets.fromLTRB(26, 28, 26, 28),
      opacity: 0.5,
      blur: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GET STARTED', style: LiquidTheme.eyebrow),
          const SizedBox(height: 12),
          Text('Your first reading\nlives here.', style: LiquidTheme.displayM),
          const SizedBox(height: 10),
          Text(
            'Scan your monitor or upload a photo — we keep the data on-device and can export a clean PDF history whenever you need it.',
            style: LiquidTheme.body,
          ),
        ],
      ),
    );
  }
}

class _PulseBadge extends StatelessWidget {
  const _PulseBadge({required this.bpm});

  final int bpm;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      opacity: 0.42,
      blur: 20,
      shadow: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_rounded, size: 13, color: LiquidTheme.accent),
          const SizedBox(width: 6),
          Text(
            '$bpm BPM',
            style: const TextStyle(
              color: LiquidTheme.ink,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.isBusy,
    required this.isSaving,
    required this.onScan,
    required this.onUpload,
  });

  final bool isBusy;
  final bool isSaving;
  final VoidCallback? onScan;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: GlassButton(
            label: isSaving ? 'Saving…' : 'Scan',
            icon: Icons.center_focus_strong_rounded,
            primary: true,
            onPressed: onScan,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: GlassButton(
            label: 'Upload',
            icon: Icons.image_outlined,
            onPressed: onUpload,
          ),
        ),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.reading, required this.onTap});

  final Reading reading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      opacity: 0.48,
      blur: 22,
      onTap: onTap,
      child: Row(
        children: [
          Text(
            reading.bloodPressureLabel,
            style: LiquidTheme.titleL.copyWith(letterSpacing: -0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              DateFormat('MMM d · HH:mm').format(reading.capturedAt),
              style: LiquidTheme.bodyMuted,
            ),
          ),
          _LevelChip(level: reading.pressureLevel, compact: true),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level, this.compact = false});

  final BloodPressureLevel level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = levelColor(level);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 5 : 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            level.label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

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

class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.25),
        child: Center(
          child: GlassSurface(
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            opacity: 0.7,
            blur: 30,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(LiquidTheme.ink),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  message,
                  style: LiquidTheme.titleM,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
