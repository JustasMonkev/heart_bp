import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/reading_repository.dart';
import '../models/reading.dart';
import '../theme/liquid_theme.dart';
import '../theme/pressure_palette.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/zoomable_photo.dart';

class ReadingDetailScreen extends StatefulWidget {
  const ReadingDetailScreen({
    super.key,
    required this.repository,
    required this.reading,
  });

  final ReadingRepository repository;
  final Reading reading;

  @override
  State<ReadingDetailScreen> createState() => _ReadingDetailScreenState();
}

class _ReadingDetailScreenState extends State<ReadingDetailScreen> {
  bool _isDeleting = false;

  Future<void> _deleteReading() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: GlassSurface(
            radius: 28,
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
            opacity: 0.72,
            blur: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delete reading?', style: LiquidTheme.titleL),
                const SizedBox(height: 8),
                Text(
                  'This removes the saved values and the attached photo from this device.',
                  style: LiquidTheme.body,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        label: 'Cancel',
                        dense: true,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassButton(
                        label: 'Delete',
                        primary: true,
                        dense: true,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    await widget.repository.deleteReading(widget.reading.id);
    try {
      final imageFile = File(widget.reading.imagePath);
      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final reading = widget.reading;
    final formatter = DateFormat('MMMM d, yyyy · HH:mm');
    final color = levelColor(reading.pressureLevel);

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
                          Text('READING', style: LiquidTheme.eyebrow),
                          const SizedBox(height: 2),
                          Text(formatter.format(reading.capturedAt), style: LiquidTheme.titleM),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: SizedBox(
                        width: double.infinity,
                        child: ZoomablePhoto(
                          imagePath: reading.imagePath,
                          height: 340,
                          borderRadius: BorderRadius.circular(30),
                          fit: BoxFit.cover,
                          semanticLabel: 'Reading photo',
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    GlassSurface(
                      radius: 30,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                      opacity: 0.6,
                      blur: 32,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('PRESSURE', style: LiquidTheme.eyebrow),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
                                ),
                                child: Text(
                                  reading.pressureLevel.label,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(reading.systolic.toString(),
                                  style: LiquidTheme.numeralXL),
                              Padding(
                                padding: const EdgeInsets.only(left: 6, right: 6, top: 14),
                                child: Text('/',
                                    style: TextStyle(
                                        fontSize: 54,
                                        fontWeight: FontWeight.w300,
                                        color: LiquidTheme.inkFaint.withValues(alpha: 0.8),
                                        height: 1)),
                              ),
                              Text(reading.diastolic.toString(),
                                  style: LiquidTheme.numeralXL),
                              const SizedBox(width: 10),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text('mmHg', style: LiquidTheme.bodyMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(color: Color(0x22000000), height: 1, thickness: 0.6),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _MetricBlock(
                                label: 'PULSE',
                                value: reading.pulse.toString(),
                                unit: 'bpm',
                                icon: Icons.favorite_rounded,
                                iconColor: LiquidTheme.accent,
                              ),
                              const SizedBox(width: 18),
                              _MetricBlock(
                                label: 'CAPTURED',
                                value: DateFormat('HH:mm').format(reading.capturedAt),
                                unit: DateFormat('MMM d').format(reading.capturedAt),
                                icon: Icons.schedule_rounded,
                                iconColor: LiquidTheme.inkMuted,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassButton(
                      label: _isDeleting ? 'Deleting…' : 'Delete reading',
                      icon: Icons.delete_outline_rounded,
                      onPressed: _isDeleting ? null : _deleteReading,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 6),
              Text(label, style: LiquidTheme.eyebrow),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: LiquidTheme.numeralL
                      .copyWith(fontSize: 30, letterSpacing: -0.8)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(unit, style: LiquidTheme.bodyMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
