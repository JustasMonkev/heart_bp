class ReadingDraft {
  const ReadingDraft({
    required this.systolicText,
    required this.diastolicText,
    required this.pulseText,
    required this.imagePath,
    required this.rawOcrText,
    required this.capturedAt,
  });

  final String systolicText;
  final String diastolicText;
  final String pulseText;
  final String imagePath;
  final String rawOcrText;
  final DateTime capturedAt;
}
