import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_bp/src/services/capture_and_scan_service.dart';
import 'package:heart_bp/src/services/ocr_parser.dart';
import 'package:heart_bp/src/services/reading_extraction_resolver.dart';
import 'package:heart_bp/src/widgets/reading_editor_sheet.dart';

void main() {
  testWidgets('does not show raw OCR text in the review sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadingEditorSheet(
            scanResult: ScanCaptureResult(
              imagePath: '/tmp/nonexistent.jpg',
              rawText: 'SYS 139 DIA 72 PULSE 62',
              parsed: const OcrParseResult(
                rawText: 'SYS 139 DIA 72 PULSE 62',
                systolic: 139,
                diastolic: 72,
                pulse: 62,
              ),
              capturedAt: DateTime(2026, 4, 21, 9, 5),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('OCR text'), findsNothing);
    expect(find.text('SYS 139 DIA 72 PULSE 62'), findsNothing);
  });

  testWidgets('opens the photo in a full screen viewer when tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadingEditorSheet(
            scanResult: ScanCaptureResult(
              imagePath: '/tmp/nonexistent.jpg',
              rawText: 'SYS 139 DIA 72 PULSE 62',
              parsed: const OcrParseResult(
                rawText: 'SYS 139 DIA 72 PULSE 62',
                systolic: 139,
                diastolic: 72,
                pulse: 62,
              ),
              capturedAt: DateTime(2026, 4, 21, 9, 5),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();

    expect(find.text('Photo'), findsOneWidget);
  });

  testWidgets('shows scan confidence in the review sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadingEditorSheet(
            scanResult: ScanCaptureResult(
              imagePath: '/tmp/nonexistent.jpg',
              rawText: 'SYS 139 DIA 72 PULSE 62',
              parsed: const OcrParseResult(
                rawText: 'SYS 139 DIA 72 PULSE 62',
                systolic: 139,
                diastolic: 72,
                pulse: 62,
              ),
              capturedAt: DateTime(2026, 4, 21, 9, 5),
              confidence: ScanConfidenceLevel.medium,
              confidenceMessage:
                  'OCR and display analysis disagreed. Check the photo carefully.',
              extractionSource: 'Seven-segment fallback',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Review values'), findsOneWidget);
    expect(find.textContaining('Seven-segment fallback'), findsOneWidget);
    expect(find.textContaining('disagreed'), findsOneWidget);
  });
}
