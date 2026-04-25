import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reading_draft.dart';
import '../services/capture_and_scan_service.dart';
import '../services/reading_extraction_resolver.dart';
import '../services/reading_validator.dart';
import '../theme/liquid_theme.dart';
import 'liquid_glass.dart';
import 'zoomable_photo.dart';

class ReadingEditorSheet extends StatefulWidget {
  const ReadingEditorSheet({super.key, required this.scanResult});

  final ScanCaptureResult scanResult;

  @override
  State<ReadingEditorSheet> createState() => _ReadingEditorSheetState();
}

class _ReadingEditorSheetState extends State<ReadingEditorSheet> {
  late final TextEditingController _systolicController;
  late final TextEditingController _diastolicController;
  late final TextEditingController _pulseController;

  @override
  void initState() {
    super.initState();
    _systolicController = TextEditingController(
      text: widget.scanResult.parsed.systolic?.toString() ?? '',
    );
    _diastolicController = TextEditingController(
      text: widget.scanResult.parsed.diastolic?.toString() ?? '',
    );
    _pulseController = TextEditingController(
      text: widget.scanResult.parsed.pulse?.toString() ?? '',
    );
    _systolicController.addListener(_onChanged);
    _diastolicController.addListener(_onChanged);
    _pulseController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _systolicController
      ..removeListener(_onChanged)
      ..dispose();
    _diastolicController
      ..removeListener(_onChanged)
      ..dispose();
    _pulseController
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final validation = ReadingValidator.validate(
      systolic: _systolicController.text,
      diastolic: _diastolicController.text,
      pulse: _pulseController.text,
    );
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, insets + 14),
      child: GlassSurface(
        radius: 34,
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
        opacity: 0.72,
        blur: 40,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: LiquidTheme.inkFaint.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('REVIEW', style: LiquidTheme.eyebrow),
              const SizedBox(height: 4),
              Text('Detected values', style: LiquidTheme.titleL),
              const SizedBox(height: 6),
              Text(
                'Captured ${DateFormat('MMM d, yyyy · HH:mm').format(widget.scanResult.capturedAt)}',
                style: LiquidTheme.bodyMuted,
              ),
              const SizedBox(height: 12),
              _ConfidenceBanner(scanResult: widget.scanResult),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  width: double.infinity,
                  child: ZoomablePhoto(
                    imagePath: widget.scanResult.imagePath,
                    height: 180,
                    borderRadius: BorderRadius.circular(22),
                    fit: BoxFit.cover,
                    semanticLabel: 'Captured reading photo',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _FieldLabel('Systolic', helper: '50 – 260'),
              TextField(
                controller: _systolicController,
                keyboardType: TextInputType.number,
                style: LiquidTheme.titleM,
                decoration: InputDecoration(
                  errorText: validation.systolicError,
                  suffixText: 'mmHg',
                  suffixStyle: LiquidTheme.bodyMuted,
                ),
              ),
              const SizedBox(height: 14),
              _FieldLabel('Diastolic', helper: '30 – 180'),
              TextField(
                controller: _diastolicController,
                keyboardType: TextInputType.number,
                style: LiquidTheme.titleM,
                decoration: InputDecoration(
                  errorText: validation.diastolicError,
                  suffixText: 'mmHg',
                  suffixStyle: LiquidTheme.bodyMuted,
                ),
              ),
              const SizedBox(height: 14),
              _FieldLabel('Pulse', helper: '30 – 220'),
              TextField(
                controller: _pulseController,
                keyboardType: TextInputType.number,
                style: LiquidTheme.titleM,
                decoration: InputDecoration(
                  errorText: validation.pulseError,
                  suffixText: 'bpm',
                  suffixStyle: LiquidTheme.bodyMuted,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassButton(
                      label: 'Save',
                      primary: true,
                      icon: Icons.check_rounded,
                      onPressed: validation.isValid
                          ? () {
                              Navigator.of(context).pop(
                                ReadingDraft(
                                  systolicText: _systolicController.text.trim(),
                                  diastolicText: _diastolicController.text
                                      .trim(),
                                  pulseText: _pulseController.text.trim(),
                                  imagePath: widget.scanResult.imagePath,
                                  rawOcrText: widget.scanResult.rawText,
                                  capturedAt: widget.scanResult.capturedAt,
                                ),
                              );
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfidenceBanner extends StatelessWidget {
  const _ConfidenceBanner({required this.scanResult});

  final ScanCaptureResult scanResult;

  @override
  Widget build(BuildContext context) {
    final accent = switch (scanResult.confidence) {
      ScanConfidenceLevel.high => const Color(0xFF1B8F63),
      ScanConfidenceLevel.medium => LiquidTheme.amber,
      ScanConfidenceLevel.low => LiquidTheme.accent,
    };
    final icon = switch (scanResult.confidence) {
      ScanConfidenceLevel.high => Icons.verified_rounded,
      ScanConfidenceLevel.medium => Icons.rate_review_rounded,
      ScanConfidenceLevel.low => Icons.error_outline_rounded,
    };
    final label = switch (scanResult.confidence) {
      ScanConfidenceLevel.high => 'High confidence',
      ScanConfidenceLevel.medium => 'Review values',
      ScanConfidenceLevel.low => 'Check photo',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label · ${scanResult.extractionSource}',
                    style: LiquidTheme.titleM.copyWith(
                      color: LiquidTheme.ink,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scanResult.confidenceMessage,
                    style: LiquidTheme.bodyMuted.copyWith(
                      color: LiquidTheme.inkSoft,
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label, {this.helper});

  final String label;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: LiquidTheme.eyebrow),
          if (helper != null) ...[
            const SizedBox(width: 8),
            Text(helper!, style: LiquidTheme.bodyMuted.copyWith(fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
