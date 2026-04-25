import 'package:flutter_test/flutter_test.dart';
import 'package:heart_bp/src/services/ocr_parser.dart';
import 'package:heart_bp/src/services/reading_extraction_resolver.dart';
import 'package:heart_bp/src/services/seven_segment_display_reader.dart';

void main() {
  group('ReadingExtractionResolver', () {
    const resolver = ReadingExtractionResolver();

    test(
      'marks agreement between OCR and seven-segment reader as high confidence',
      () {
        final decision = resolver.resolve(
          rawOcrText: 'SYS 139 DIA 72 PULSE 62',
          ocrResult: const OcrParseResult(
            rawText: 'SYS 139 DIA 72 PULSE 62',
            systolic: 139,
            diastolic: 72,
            pulse: 62,
            score: 102,
          ),
          segmentResult: const SevenSegmentDisplayReadResult(
            systolic: 139,
            diastolic: 72,
            pulse: 62,
            confidence: 0.83,
          ),
        );

        expect(decision.parsed.systolic, 139);
        expect(decision.parsed.diastolic, 72);
        expect(decision.parsed.pulse, 62);
        expect(decision.confidence, ScanConfidenceLevel.high);
        expect(decision.extractionSource, contains('agreement'));
      },
    );

    test('uses seven-segment fallback when OCR is incomplete', () {
      final decision = resolver.resolve(
        rawOcrText: 'SYS 153',
        ocrResult: const OcrParseResult(
          rawText: 'SYS 153',
          systolic: 153,
          score: 25,
        ),
        segmentResult: const SevenSegmentDisplayReadResult(
          systolic: 153,
          diastolic: 77,
          pulse: 68,
          confidence: 0.76,
        ),
      );

      expect(decision.parsed.systolic, 153);
      expect(decision.parsed.diastolic, 77);
      expect(decision.parsed.pulse, 68);
      expect(decision.confidence, ScanConfidenceLevel.high);
      expect(decision.extractionSource, 'Seven-segment fallback');
    });

    test('keeps disagreement visible with medium confidence', () {
      final decision = resolver.resolve(
        rawOcrText: 'SYS 159 DIA 77 PULSE 68',
        ocrResult: const OcrParseResult(
          rawText: 'SYS 159 DIA 77 PULSE 68',
          systolic: 159,
          diastolic: 77,
          pulse: 68,
          score: 58,
        ),
        segmentResult: const SevenSegmentDisplayReadResult(
          systolic: 153,
          diastolic: 77,
          pulse: 68,
          confidence: 0.82,
        ),
      );

      expect(decision.parsed.systolic, 153);
      expect(decision.confidence, ScanConfidenceLevel.medium);
      expect(decision.confidenceMessage, contains('disagreed'));
    });
  });
}
