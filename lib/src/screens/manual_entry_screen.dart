import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../data/reading_repository.dart';
import '../models/reading.dart';
import '../models/reading_draft.dart';
import '../services/reading_validator.dart';
import '../theme/liquid_theme.dart';
import '../theme/pressure_palette.dart';
import '../widgets/liquid_glass.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key, required this.repository});

  final ReadingRepository repository;

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  static const List<String> _noteOptions = <String>[
    'After meds',
    'Exercise',
    'Stressed',
    'Caffeine',
    'Fasting',
  ];

  bool _isSaving = false;
  final Set<String> _selectedNotes = <String>{};
  late final TextEditingController _systolicController;
  late final TextEditingController _diastolicController;
  late final TextEditingController _pulseController;

  int get _systolic => int.tryParse(_systolicController.text.trim()) ?? 120;
  int get _diastolic => int.tryParse(_diastolicController.text.trim()) ?? 80;

  BloodPressureLevel get _level => pressureLevelFor(_systolic, _diastolic);

  @override
  void initState() {
    super.initState();
    _systolicController = TextEditingController(text: '120');
    _diastolicController = TextEditingController(text: '80');
    _pulseController = TextEditingController(text: '72');
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

  Future<void> _saveReading() async {
    if (_isSaving) return;
    final validation = ReadingValidator.validate(
      systolic: _systolicController.text,
      diastolic: _diastolicController.text,
      pulse: _pulseController.text,
    );
    if (!validation.isValid) {
      setState(() {});
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.repository.saveReading(
        ReadingDraft(
          systolicText: _systolicController.text.trim(),
          diastolicText: _diastolicController.text.trim(),
          pulseText: _pulseController.text.trim(),
          imagePath: '',
          rawOcrText: '',
          capturedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save reading: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = levelColor(_level);
    final validation = ReadingValidator.validate(
      systolic: _systolicController.text,
      diastolic: _diastolicController.text,
      pulse: _pulseController.text,
    );

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            physics: const BouncingScrollPhysics(),
            children: [
              Row(
                children: [
                  const LiquidBackButton(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MANUAL', style: LiquidTheme.eyebrow),
                        const SizedBox(height: 2),
                        Text('Quick entry', style: LiquidTheme.displayM),
                      ],
                    ),
                  ),
                  _StageChip(level: _level, color: color),
                ],
              ),
              const SizedBox(height: 22),
              GlassSurface(
                radius: 34,
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                opacity: 0.58,
                blur: 34,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ENTER VALUES', style: LiquidTheme.eyebrow),
                    const SizedBox(height: 16),
                    _MetricTextField(
                      label: 'Systolic',
                      helper: '50 – 260',
                      unit: 'mmHg',
                      controller: _systolicController,
                      errorText: validation.systolicError,
                    ),
                    const SizedBox(height: 14),
                    _MetricTextField(
                      label: 'Diastolic',
                      helper: '30 – 180',
                      unit: 'mmHg',
                      controller: _diastolicController,
                      errorText: validation.diastolicError,
                    ),
                    const SizedBox(height: 14),
                    _MetricTextField(
                      label: 'Pulse',
                      helper: '30 – 220',
                      unit: 'bpm',
                      controller: _pulseController,
                      errorText: validation.pulseError,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GlassSurface(
                radius: 34,
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                opacity: 0.52,
                blur: 32,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ADD NOTES', style: LiquidTheme.eyebrow),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _noteOptions.map((note) {
                        final selected = _selectedNotes.contains(note);
                        return GlassPill(
                          key: ValueKey<String>('note-$note'),
                          label: note,
                          accent: selected
                              ? LiquidTheme.ink
                              : LiquidTheme.inkMuted,
                          leading: Icon(
                            Icons.label_rounded,
                            size: 14,
                            color: selected
                                ? LiquidTheme.accent
                                : LiquidTheme.inkMuted,
                          ),
                          onTap: () {
                            setState(() {
                              if (!_selectedNotes.add(note)) {
                                _selectedNotes.remove(note);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GlassSurface(
                radius: 30,
                padding: const EdgeInsets.all(18),
                opacity: 0.48,
                blur: 28,
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: reminderTint,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.schedule_rounded,
                        color: LiquidTheme.amber,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Evening reminder set',
                            style: LiquidTheme.titleM,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Daily at 8:00 PM',
                            style: LiquidTheme.bodyMuted,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Edit',
                      style: LiquidTheme.titleM.copyWith(
                        color: LiquidTheme.amber,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              GlassButton(
                label: _isSaving ? 'Saving…' : 'Save reading',
                icon: Icons.check_rounded,
                primary: true,
                onPressed: _isSaving || !validation.isValid
                    ? null
                    : _saveReading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTextField extends StatelessWidget {
  const _MetricTextField({
    required this.label,
    required this.helper,
    required this.unit,
    required this.controller,
    this.errorText,
  });

  final String label;
  final String helper;
  final String unit;
  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label.toUpperCase(), style: LiquidTheme.eyebrow),
            const SizedBox(width: 8),
            Text(helper, style: LiquidTheme.bodyMuted.copyWith(fontSize: 11)),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: LiquidTheme.titleM,
          decoration: InputDecoration(
            errorText: errorText,
            suffixText: unit,
            suffixStyle: LiquidTheme.bodyMuted,
          ),
        ),
      ],
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.level, required this.color});

  final BloodPressureLevel level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            level.label,
            style: LiquidTheme.titleM.copyWith(color: color, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
