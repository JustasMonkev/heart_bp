class BloodPressureTip {
  const BloodPressureTip({required this.title, required this.message});

  final String title;
  final String message;
}

class BloodPressureTips {
  BloodPressureTips._();

  // General home-monitoring and lifestyle reminders adapted from AHA and CDC
  // public guidance so the app can show short offline tips while OCR runs.
  static const List<BloodPressureTip> items = [
    BloodPressureTip(
      title: 'Rest first',
      message: 'Sit quietly for five minutes before taking a reading.',
    ),
    BloodPressureTip(
      title: 'Posture matters',
      message: 'Keep your feet flat, back supported, and arm at heart level.',
    ),
    BloodPressureTip(
      title: 'Use the same time',
      message:
          'Checking at the same time each day makes trends easier to compare.',
    ),
    BloodPressureTip(
      title: 'Take two readings',
      message:
          'Two measurements about a minute apart can give a steadier picture.',
    ),
    BloodPressureTip(
      title: 'Check cuff fit',
      message:
          'An upper-arm cuff that fits correctly helps avoid inaccurate readings.',
    ),
    BloodPressureTip(
      title: 'Watch sodium',
      message:
          'Lower-sodium food choices can support healthier blood pressure over time.',
    ),
    BloodPressureTip(
      title: 'Keep moving',
      message:
          'Regular physical activity can help support blood pressure control.',
    ),
  ];

  static BloodPressureTip tipForSeed(int seed) {
    final normalizedSeed = seed < 0 ? -seed : seed;
    return items[normalizedSeed % items.length];
  }
}
