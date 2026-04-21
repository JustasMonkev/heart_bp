import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_bp/src/app.dart';
import 'package:heart_bp/src/data/reading_repository.dart';
import 'package:heart_bp/src/models/reading.dart';
import 'package:heart_bp/src/models/reading_draft.dart';
import 'package:heart_bp/src/services/capture_and_scan_service.dart';

void main() {
  testWidgets('shows the home screen with scan and history actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      HeartBpApp(
        repository: _FakeReadingRepository(),
        captureAndScanService: _FakeCaptureAndScanService(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Heart'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Open history'), findsOneWidget);
  });

  testWidgets('shows an empty history state when no readings are saved', (
    tester,
  ) async {
    await tester.pumpWidget(
      HeartBpApp(
        repository: _FakeReadingRepository(),
        captureAndScanService: _FakeCaptureAndScanService(),
      ),
    );

    await tester.tap(find.text('Open history'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing logged yet'), findsOneWidget);
    expect(find.textContaining('Scan your first reading'), findsOneWidget);
  });

  testWidgets('shows a loader while an uploaded photo is being analyzed', (
    tester,
  ) async {
    final uploadCompleter = Completer<ScanCaptureResult?>();

    await tester.pumpWidget(
      HeartBpApp(
        repository: _FakeReadingRepository(),
        captureAndScanService: _FakeCaptureAndScanService(
          uploadFuture: uploadCompleter.future,
        ),
      ),
    );

    await tester.tap(find.text('Upload'));
    await tester.pump();

    expect(find.text('Analyzing photo…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    uploadCompleter.complete(null);
    await tester.pumpAndSettle();

    expect(find.text('Analyzing photo…'), findsNothing);
  });
}

class _FakeReadingRepository implements ReadingRepository {
  @override
  Future<PdfReport> createPdfReport() async {
    return PdfReport(filename: 'report.pdf', bytes: Uint8List(0));
  }

  @override
  Future<void> deleteReading(int id) async {}

  @override
  Future<Reading?> getReading(int id) async => null;

  @override
  Future<int> saveReading(ReadingDraft draft) async => 1;

  @override
  Stream<List<Reading>> watchAllReadings() async* {
    yield const <Reading>[];
  }
}

class _FakeCaptureAndScanService implements CaptureAndScanService {
  _FakeCaptureAndScanService({
    Future<ScanCaptureResult?>? uploadFuture,
  }) : _uploadFuture = uploadFuture;

  final Future<ScanCaptureResult?>? _uploadFuture;

  @override
  Future<ScanCaptureResult?> captureReading(BuildContext context) async {
    return null;
  }

  @override
  Future<ScanCaptureResult?> pickReadingFromFiles(BuildContext context) async {
    return _uploadFuture;
  }
}
