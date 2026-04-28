import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_bp/src/app.dart';
import 'package:heart_bp/src/data/reading_repository.dart';
import 'package:heart_bp/src/models/reading.dart';
import 'package:heart_bp/src/models/reading_draft.dart';
import 'package:heart_bp/src/services/capture_and_scan_service.dart';
import 'package:heart_bp/src/services/pdf_exporter.dart';

void main() {
  Future<void> pumpPhoneApp(
    WidgetTester tester, {
    required ReadingRepository repository,
    required CaptureAndScanService captureAndScanService,
    PdfExporter? pdfExporter,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      HeartBpApp(
        repository: repository,
        captureAndScanService: captureAndScanService,
        pdfExporter: pdfExporter,
      ),
    );
  }

  testWidgets('settings tab only exposes PDF export', (tester) async {
    await pumpPhoneApp(
      tester,
      repository: _FakeReadingRepository(),
      captureAndScanService: _FakeCaptureAndScanService(),
    );

    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
    expect(find.text('Units (mmHg)'), findsNothing);
    expect(find.text('Notifications'), findsNothing);
    expect(find.text('Apple Health Sync'), findsNothing);
    expect(find.text('Family Profiles'), findsNothing);
    expect(find.text('About'), findsNothing);
  });

  testWidgets('settings export shares a generated PDF report', (tester) async {
    final repository = _FakeReadingRepository();
    final pdfExporter = _FakePdfExporter();

    await pumpPhoneApp(
      tester,
      repository: repository,
      captureAndScanService: _FakeCaptureAndScanService(),
      pdfExporter: pdfExporter,
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export PDF'));
    await tester.pumpAndSettle();

    expect(repository.createPdfReportCount, 1);
    expect(pdfExporter.sharedReports, hasLength(1));
    expect(pdfExporter.sharedReports.single.filename, 'report.pdf');
  });

  testWidgets('insights tab builds the time-of-day graph from readings', (
    tester,
  ) async {
    final baseDay = DateTime(2026, 4, 24);

    await pumpPhoneApp(
      tester,
      repository: _FakeReadingRepository(
        readings: [
          _reading(
            id: 1,
            capturedAt: baseDay.add(const Duration(hours: 3)),
            systolic: 128,
          ),
          _reading(
            id: 2,
            capturedAt: baseDay.add(const Duration(hours: 4)),
            systolic: 127,
          ),
          _reading(
            id: 3,
            capturedAt: baseDay.add(const Duration(hours: 5)),
            systolic: 129,
          ),
          _reading(
            id: 4,
            capturedAt: baseDay.add(const Duration(hours: 6)),
            systolic: 155,
          ),
          _reading(
            id: 5,
            capturedAt: baseDay.add(const Duration(hours: 7)),
            systolic: 154,
          ),
          _reading(
            id: 6,
            capturedAt: baseDay.add(const Duration(hours: 8)),
            systolic: 156,
          ),
        ],
      ),
      captureAndScanService: _FakeCaptureAndScanService(),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();

    expect(find.text('INSIGHTS'), findsOneWidget);
    expect(find.text('Time of Day'), findsOneWidget);
    expect(find.text('AVG SYSTOLIC BY HOUR'), findsOneWidget);
    expect(find.text('Peak at 6 - 8 AM'), findsOneWidget);
    expect(find.textContaining('Avg 155 mmHg'), findsOneWidget);
    expect(find.text('Lowest at 3 - 5 AM'), findsOneWidget);
    expect(find.textContaining('Avg 128 mmHg'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('High 2'), findsOneWidget);
  });

  testWidgets('shows the redesigned home screen actions', (tester) async {
    await pumpPhoneApp(
      tester,
      repository: _FakeReadingRepository(),
      captureAndScanService: _FakeCaptureAndScanService(),
    );

    await tester.pumpAndSettle();

    expect(find.text('Heart'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Quick entry'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Quick entry'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Open history'), findsNothing);
    expect(find.text('7-DAY SYSTOLIC'), findsNothing);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Upload'), findsNothing);
  });

  testWidgets('switching tabs resets the previous tab scroll position', (
    tester,
  ) async {
    await pumpPhoneApp(
      tester,
      repository: _FakeReadingRepository(),
      captureAndScanService: _FakeCaptureAndScanService(),
    );

    await tester.pumpAndSettle();
    expect(find.text('Heart'), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -520));
    await tester.pumpAndSettle();

    expect(find.text('Heart'), findsNothing);

    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('Heart'), findsOneWidget);
  });

  testWidgets('shows an empty history state when no readings are saved', (
    tester,
  ) async {
    await pumpPhoneApp(
      tester,
      repository: _FakeReadingRepository(),
      captureAndScanService: _FakeCaptureAndScanService(),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing logged yet'), findsOneWidget);
    expect(find.textContaining('Scan your first reading'), findsOneWidget);
  });

  testWidgets('opens quick entry and saves a manual reading', (tester) async {
    final repository = _FakeReadingRepository();

    await pumpPhoneApp(
      tester,
      repository: repository,
      captureAndScanService: _FakeCaptureAndScanService(),
    );

    await tester.scrollUntilVisible(find.text('Quick entry'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick entry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final manualScroll = find.byType(Scrollable).last;

    expect(find.text('MANUAL'), findsOneWidget);
    await tester.drag(manualScroll, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Save reading'), findsOneWidget);

    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();

    expect(repository.savedDrafts, hasLength(1));
    expect(repository.savedDrafts.single.systolicText, '120');
    expect(repository.savedDrafts.single.diastolicText, '80');
    expect(repository.savedDrafts.single.pulseText, '72');
    expect(find.text('120/80'), findsOneWidget);
  });

  testWidgets('quick entry accepts typed values before saving', (tester) async {
    final repository = _FakeReadingRepository();

    await pumpPhoneApp(
      tester,
      repository: repository,
      captureAndScanService: _FakeCaptureAndScanService(),
    );

    await tester.scrollUntilVisible(find.text('Quick entry'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick entry'));
    await tester.pumpAndSettle();
    final manualScroll = find.byType(Scrollable).last;

    expect(find.byType(TextField), findsNWidgets(3));

    await tester.enterText(find.byType(TextField).at(0), '136');
    await tester.enterText(find.byType(TextField).at(1), '73');
    await tester.enterText(find.byType(TextField).at(2), '68');
    await tester.pumpAndSettle();

    await tester.drag(manualScroll, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();

    expect(repository.savedDrafts, hasLength(1));
    expect(repository.savedDrafts.single.systolicText, '136');
    expect(repository.savedDrafts.single.diastolicText, '73');
    expect(repository.savedDrafts.single.pulseText, '68');
    expect(find.text('136/73'), findsOneWidget);
  });
}

Reading _reading({
  required int id,
  required DateTime capturedAt,
  required int systolic,
}) {
  return Reading(
    id: id,
    capturedAt: capturedAt,
    systolic: systolic,
    diastolic: 75,
    pulse: 69,
    imagePath: '',
    rawOcrText: '',
    createdAt: capturedAt,
  );
}

class _FakeReadingRepository implements ReadingRepository {
  final _controller = StreamController<List<Reading>>.broadcast();
  final List<Reading> _readings;
  final List<ReadingDraft> savedDrafts = [];
  int createPdfReportCount = 0;

  _FakeReadingRepository({List<Reading> readings = const []})
    : _readings = List<Reading>.from(readings)
        ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

  @override
  Future<PdfReport> createPdfReport() async {
    createPdfReportCount++;
    return PdfReport(filename: 'report.pdf', bytes: Uint8List(0));
  }

  @override
  Future<void> deleteReading(int id) async {}

  @override
  Future<Reading?> getReading(int id) async => null;

  @override
  Future<int> saveReading(ReadingDraft draft) async {
    savedDrafts.add(draft);
    final reading = Reading(
      id: savedDrafts.length,
      capturedAt: draft.capturedAt,
      systolic: int.parse(draft.systolicText),
      diastolic: int.parse(draft.diastolicText),
      pulse: int.parse(draft.pulseText),
      imagePath: draft.imagePath,
      rawOcrText: draft.rawOcrText,
      createdAt: draft.capturedAt,
    );
    _readings
      ..removeWhere((item) => item.id == reading.id)
      ..insert(0, reading);
    _controller.add(List<Reading>.unmodifiable(_readings));
    return reading.id;
  }

  @override
  Stream<List<Reading>> watchAllReadings() async* {
    yield List<Reading>.unmodifiable(_readings);
    yield* _controller.stream;
  }
}

class _FakeCaptureAndScanService implements CaptureAndScanService {
  @override
  Future<ScanCaptureResult?> captureReading(BuildContext context) async {
    return null;
  }
}

class _FakePdfExporter implements PdfExporter {
  final List<PdfReport> sharedReports = [];

  @override
  Future<void> share(PdfReport report) async {
    sharedReports.add(report);
  }
}
