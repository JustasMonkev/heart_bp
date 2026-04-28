import 'package:flutter/material.dart';

import '../data/reading_repository.dart';
import '../services/capture_and_scan_service.dart';
import '../services/pdf_exporter.dart';
import '../theme/liquid_theme.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.repository,
    required this.captureAndScanService,
    required this.pdfExporter,
  });

  final ReadingRepository repository;
  final CaptureAndScanService captureAndScanService;
  final PdfExporter pdfExporter;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _selectedIndex = 0;
  var _isExporting = false;

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);

    try {
      final report = await widget.repository.createPdfReport();
      await widget.pdfExporter.share(report);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not export PDF: $error')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        repository: widget.repository,
        captureAndScanService: widget.captureAndScanService,
      ),
      InsightsScreen(repository: widget.repository),
      HistoryScreen(repository: widget.repository),
      SettingsScreen(
        onExportPdf: _isExporting ? null : _exportPdf,
        isExporting: _isExporting,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: KeyedSubtree(
        key: ValueKey<int>(_selectedIndex),
        child: pages[_selectedIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        height: 82,
        backgroundColor: LiquidTheme.canvasTop.withValues(alpha: 0.88),
        indicatorColor: LiquidTheme.accent.withValues(alpha: 0.16),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
