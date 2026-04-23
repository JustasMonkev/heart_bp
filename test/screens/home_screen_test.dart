import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_bp/src/data/reading_repository.dart';
import 'package:heart_bp/src/models/reading.dart';
import 'package:heart_bp/src/models/reading_draft.dart';
import 'package:heart_bp/src/screens/home_screen.dart';
import 'package:heart_bp/src/services/capture_and_scan_service.dart';

void main() {
  testWidgets('7-day systolic delta uses actual readings in the week', (
    tester,
  ) async {
    final today = DateTime.now();
    final currentDay = DateTime(today.year, today.month, today.day);
    final repository = _FakeReadingRepository(
      readings: [
        _reading(
          id: 2,
          capturedAt: currentDay.add(const Duration(hours: 12)),
          systolic: 141,
        ),
        _reading(
          id: 1,
          capturedAt: currentDay
              .subtract(const Duration(days: 2))
              .add(const Duration(hours: 8)),
          systolic: 136,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: repository,
          captureAndScanService: _FakeCaptureAndScanService(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('↗ 5 mmHg'), findsOneWidget);
    expect(find.text('↗ 0 mmHg'), findsNothing);
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
  _FakeReadingRepository({required List<Reading> readings})
    : _readings = readings;

  final List<Reading> _readings;

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
    yield _readings;
  }
}

class _FakeCaptureAndScanService implements CaptureAndScanService {
  @override
  Future<ScanCaptureResult?> captureReading(BuildContext context) async {
    return null;
  }
}
