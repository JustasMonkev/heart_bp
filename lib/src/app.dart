import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/reading_repository.dart';
import 'screens/home_screen.dart';
import 'services/capture_and_scan_service.dart';
import 'theme/liquid_theme.dart';

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
          labelStyle: const TextStyle(
            color: LiquidTheme.inkMuted,
            letterSpacing: -0.1,
          ),
          helperStyle: const TextStyle(
            color: LiquidTheme.inkFaint,
            letterSpacing: -0.05,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: LiquidTheme.ink,
          contentTextStyle: const TextStyle(
            color: Colors.white,
            letterSpacing: -0.1,
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: HomeScreen(
        repository: repository,
        captureAndScanService: captureAndScanService,
      ),
    );
  }
}
