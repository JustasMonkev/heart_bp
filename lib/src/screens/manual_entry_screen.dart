import 'package:flutter/material.dart';

import '../data/reading_repository.dart';
import '../models/reading.dart';
import '../models/reading_draft.dart';
import '../theme/liquid_theme.dart';
import '../theme/pressure_palette.dart';
import '../widgets/liquid_glass.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({
    super.key,
    required this.repository,
  });

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

  int _systolic = 120;
  int _diastolic = 80;
  int _pulse = 72;
  bool _isSaving = false;
  final Set<String> _selectedNotes = <String>{};

  BloodPressureLevel get _level => pressureLevelFor(_systolic, _diastolic);

  Future<void> _saveReading() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      await widget.repository.saveReading(
        ReadingDraft(
          systolicText: _systolic.toString(),
          diastolicText: _diastolic.toString(),
          pulseText: _pulse.toString(),
          imagePath: '',
          rawOcrText: '',
          capturedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save reading: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _stepSystolic(int delta) =>
      setState(() => _systolic = (_systolic + delta).clamp(50, 260));
  void _stepDiastolic(int delta) =>
      setState(() => _diastolic = (_diastolic + delta).clamp(30, 180));
  void _stepPulse(int delta) =>
      setState(() => _pulse = (_pulse + delta).clamp(30, 220));

  @override
  Widget build(BuildContext context) {
    final color = levelColor(_level);

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
                child: Row(
                  children: [
                    Expanded(
                      child: _MetricStepper(
                        label: 'SYSTOLIC',
                        value: _systolic,
                        unit: 'mmHg',
                        onIncrement: () => _stepSystolic(1),
                        onDecrement: () => _stepSystolic(-1),
                      ),
                    ),
                    Expanded(
                      child: _MetricStepper(
                        label: 'DIASTOLIC',
                        value: _diastolic,
                        unit: 'mmHg',
                        onIncrement: () => _stepDiastolic(1),
                        onDecrement: () => _stepDiastolic(-1),
                      ),
                    ),
                    Expanded(
                      child: _MetricStepper(
                        label: 'PULSE',
                        value: _pulse,
                        unit: 'bpm',
                        onIncrement: () => _stepPulse(1),
                        onDecrement: () => _stepPulse(-1),
                      ),
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
                          accent: selected ? LiquidTheme.ink : LiquidTheme.inkMuted,
                          leading: Icon(
                            Icons.label_rounded,
                            size: 14,
                            color: selected ? LiquidTheme.accent : LiquidTheme.inkMuted,
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
                          Text('Evening reminder set', style: LiquidTheme.titleM),
                          const SizedBox(height: 2),
                          Text('Daily at 8:00 PM', style: LiquidTheme.bodyMuted),
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
                onPressed: _isSaving ? null : _saveReading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricStepper extends StatelessWidget {
  const _MetricStepper({
    required this.label,
    required this.value,
    required this.unit,
    required this.onIncrement,
    required this.onDecrement,
  });

  final String label;
  final int value;
  final String unit;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: LiquidTheme.eyebrow, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CircleAction(icon: Icons.remove_rounded, onTap: onDecrement),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.12),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  '$value',
                  key: ValueKey<int>(value),
                  style: LiquidTheme.numeralL.copyWith(fontSize: 40),
                ),
              ),
              const SizedBox(width: 8),
              _CircleAction(icon: Icons.add_rounded, onTap: onIncrement),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(unit, style: LiquidTheme.bodyMuted),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 999,
      padding: const EdgeInsets.all(10),
      opacity: 0.34,
      blur: 16,
      shadow: false,
      onTap: onTap,
      child: Icon(icon, size: 20, color: LiquidTheme.ink),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({
    required this.level,
    required this.color,
  });

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
            style: LiquidTheme.titleM.copyWith(
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
