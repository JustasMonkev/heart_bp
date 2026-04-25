import 'ocr_parser.dart';
import 'seven_segment_display_reader.dart';

enum ScanConfidenceLevel { high, medium, low }

class ReadingExtractionDecision {
  const ReadingExtractionDecision({
    required this.parsed,
    required this.confidence,
    required this.confidenceScore,
    required this.confidenceMessage,
    required this.extractionSource,
  });

  final OcrParseResult parsed;
  final ScanConfidenceLevel confidence;
  final double confidenceScore;
  final String confidenceMessage;
  final String extractionSource;
}

class ReadingExtractionResolver {
  const ReadingExtractionResolver();

  ReadingExtractionDecision resolve({
    required OcrParseResult ocrResult,
    required SevenSegmentDisplayReadResult segmentResult,
    required String rawOcrText,
  }) {
    final segmentParsed = OcrParseResult(
      rawText: segmentResult.rawText,
      systolic: segmentResult.systolic,
      diastolic: segmentResult.diastolic,
      pulse: segmentResult.pulse,
      score: (segmentResult.confidence * 100).round(),
    );
    final rawText = _combinedRawText(rawOcrText, segmentResult.rawText);
    final ocrComplete = _isComplete(ocrResult);
    final segmentComplete = segmentResult.hasCompleteReading;
    final ocrReliability = (ocrResult.score / 102).clamp(0, 1).toDouble();
    final segmentReliability = segmentResult.confidence;

    if (ocrComplete &&
        segmentComplete &&
        _sameValues(ocrResult, segmentParsed)) {
      return ReadingExtractionDecision(
        parsed: _withRawText(ocrResult, rawText),
        confidence: ScanConfidenceLevel.high,
        confidenceScore: 0.94,
        confidenceMessage:
            'OCR and display analysis agree. Review before saving.',
        extractionSource: 'OCR + seven-segment agreement',
      );
    }

    if (!ocrComplete && segmentComplete && segmentReliability >= 0.50) {
      return ReadingExtractionDecision(
        parsed: _withRawText(segmentParsed, rawText),
        confidence: segmentReliability >= 0.72
            ? ScanConfidenceLevel.high
            : ScanConfidenceLevel.medium,
        confidenceScore: segmentReliability,
        confidenceMessage:
            'OCR missed part of the display, so the seven-segment reader filled it in. Review before saving.',
        extractionSource: 'Seven-segment fallback',
      );
    }

    if (ocrComplete && !segmentComplete) {
      final confidence = ocrResult.score >= 85
          ? ScanConfidenceLevel.high
          : ScanConfidenceLevel.medium;
      return ReadingExtractionDecision(
        parsed: _withRawText(ocrResult, rawText),
        confidence: confidence,
        confidenceScore: ocrReliability,
        confidenceMessage:
            'OCR found a complete reading. The display fallback was inconclusive, so review before saving.',
        extractionSource: 'OCR',
      );
    }

    if (ocrComplete && segmentComplete) {
      final useSegment = segmentReliability >= ocrReliability + 0.12;
      final selected = useSegment ? segmentParsed : ocrResult;
      return ReadingExtractionDecision(
        parsed: _withRawText(selected, rawText),
        confidence: ScanConfidenceLevel.medium,
        confidenceScore: useSegment ? segmentReliability : ocrReliability,
        confidenceMessage:
            'OCR and display analysis disagreed. The stronger candidate is shown, but check the photo carefully.',
        extractionSource: useSegment
            ? 'Seven-segment fallback'
            : 'OCR with fallback disagreement',
      );
    }

    if (segmentResult.hasAnyReading && segmentReliability >= 0.52) {
      final merged = _mergeMissingValues(ocrResult, segmentParsed, rawText);
      return ReadingExtractionDecision(
        parsed: merged,
        confidence: _isComplete(merged)
            ? ScanConfidenceLevel.medium
            : ScanConfidenceLevel.low,
        confidenceScore: (ocrReliability + segmentReliability) / 2,
        confidenceMessage:
            'Only a partial reading was detected. Fill in or correct the values from the photo.',
        extractionSource: 'Partial OCR + seven-segment fallback',
      );
    }

    return ReadingExtractionDecision(
      parsed: _withRawText(ocrResult, rawText),
      confidence: _isComplete(ocrResult)
          ? ScanConfidenceLevel.medium
          : ScanConfidenceLevel.low,
      confidenceScore: ocrReliability,
      confidenceMessage:
          'The scan was uncertain. Check the photo and correct the values before saving.',
      extractionSource: 'OCR',
    );
  }

  static String _combinedRawText(String ocrText, String segmentText) {
    final parts = <String>[
      if (ocrText.trim().isNotEmpty) ocrText.trim(),
      if (segmentText.trim().isNotEmpty)
        'Seven-segment:\n${segmentText.trim()}',
    ];
    return parts.join('\n\n');
  }

  static bool _isComplete(OcrParseResult result) {
    return result.systolic != null &&
        result.diastolic != null &&
        result.pulse != null;
  }

  static bool _sameValues(OcrParseResult left, OcrParseResult right) {
    return left.systolic == right.systolic &&
        left.diastolic == right.diastolic &&
        left.pulse == right.pulse;
  }

  static OcrParseResult _withRawText(OcrParseResult result, String rawText) {
    return result.copyWith(rawText: rawText);
  }

  static OcrParseResult _mergeMissingValues(
    OcrParseResult ocrResult,
    OcrParseResult segmentResult,
    String rawText,
  ) {
    return OcrParseResult(
      rawText: rawText,
      systolic: ocrResult.systolic ?? segmentResult.systolic,
      diastolic: ocrResult.diastolic ?? segmentResult.diastolic,
      pulse: ocrResult.pulse ?? segmentResult.pulse,
      score: (ocrResult.score + segmentResult.score) ~/ 2,
    );
  }
}
