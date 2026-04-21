import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_bp/src/app.dart';
import 'package:heart_bp/src/data/reading_repository.dart';
import 'package:heart_bp/src/models/reading.dart';
import 'package:heart_bp/src/models/reading_draft.dart';
import 'package:heart_bp/src/services/capture_and_scan_service.dart';

void main() {
  Future<void> pumpPhoneApp(
    WidgetTester tester, {
    required ReadingRepository repository,
    required CaptureAndScanService captureAndScanService,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      HeartBpApp(
        repository: repository,
        captureAndScanService: captureAndScanService,
      ),
    );
  }

  testWidgets('shows the redesigned home screen actions', (
    tester,
  ) async {
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
    expect(find.text('Open history'), findsOneWidget);
    expect(find.text('Upload'), findsNothing);
  });

  testWidgets('shows an empty history state when no readings are saved', (
    tester,
  ) async {
    await pumpPhoneApp(
      tester,
      repository: _FakeReadingRepository(),
      captureAndScanService: _FakeCaptureAndScanService(),
    );

    await tester.scrollUntilVisible(find.text('Open history'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open history'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing logged yet'), findsOneWidget);
    expect(find.textContaining('Scan your first reading'), findsOneWidget);
  });

  testWidgets('opens quick entry and saves a manual reading', (
    tester,
  ) async {
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

    expect(find.text('MANUAL'), findsOneWidget);
    expect(find.text('Save reading'), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();

    expect(repository.savedDrafts, hasLength(1));
    expect(repository.savedDrafts.single.systolicText, '120');
    expect(repository.savedDrafts.single.diastolicText, '80');
    expect(repository.savedDrafts.single.pulseText, '72');
    expect(find.text('120/80'), findsOneWidget);
  });
}

class _FakeReadingRepository implements ReadingRepository {
  final _controller = StreamController<List<Reading>>.broadcast();
  final List<Reading> _readings = [];
  final List<ReadingDraft> savedDrafts = [];

  _FakeReadingRepository() {
    _controller.add(const <Reading>[]);
  }

  @override
  Future<PdfReport> createPdfReport() async {
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
  Stream<List<Reading>> watchAllReadings() => _controller.stream;
}

class _FakeCaptureAndScanService implements CaptureAndScanService {
  @override
  Future<ScanCaptureResult?> captureReading(BuildContext context) async {
    return null;
  }
}
