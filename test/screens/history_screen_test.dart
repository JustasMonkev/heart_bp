import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_bp/src/data/reading_repository.dart';
import 'package:heart_bp/src/models/reading.dart';
import 'package:heart_bp/src/models/reading_draft.dart';
import 'package:heart_bp/src/screens/history_screen.dart';

void main() {
  testWidgets('shows pressure level and SYS/DIA labels for each reading', (
    tester,
  ) async {
    final repository = _FakeReadingRepository(
      readings: [
        Reading(
          id: 1,
          capturedAt: DateTime(2026, 4, 21, 9, 5),
          systolic: 136,
          diastolic: 73,
          pulse: 62,
          imagePath: '/tmp/reading.jpg',
          rawOcrText: '',
          createdAt: DateTime(2026, 4, 21, 9, 5),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryScreen(repository: repository),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('High Stage 1'), findsOneWidget);
    expect(find.text('136/73'), findsOneWidget);
    expect(find.text('62 bpm'), findsOneWidget);
  });
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
