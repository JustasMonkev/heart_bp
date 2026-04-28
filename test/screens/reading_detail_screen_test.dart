import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_bp/src/data/reading_repository.dart';
import 'package:heart_bp/src/models/reading.dart';
import 'package:heart_bp/src/models/reading_draft.dart';
import 'package:heart_bp/src/screens/reading_detail_screen.dart';

void main() {
  testWidgets('delete waits for confirmation before removing a reading', (
    tester,
  ) async {
    final reading = _reading(id: 1, capturedAt: DateTime(2026, 4, 26, 8));
    final repository = _FakeReadingRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: ReadingDetailScreen(repository: repository, reading: reading),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Delete reading'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete reading'));
    await tester.pumpAndSettle();

    expect(find.text('Delete reading?'), findsOneWidget);
    expect(repository.deletedIds, isEmpty);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repository.deletedIds, isEmpty);

    await tester.tap(find.text('Delete reading'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repository.deletedIds, [1]);
  });
}

Reading _reading({required int id, required DateTime capturedAt}) {
  return Reading(
    id: id,
    capturedAt: capturedAt,
    systolic: 124,
    diastolic: 75,
    pulse: 69,
    imagePath: '',
    rawOcrText: '',
    createdAt: capturedAt,
  );
}

class _FakeReadingRepository implements ReadingRepository {
  final List<int> deletedIds = [];

  @override
  Future<PdfReport> createPdfReport() async {
    return PdfReport(filename: 'report.pdf', bytes: Uint8List(0));
  }

  @override
  Future<void> deleteReading(int id) async {
    deletedIds.add(id);
  }

  @override
  Future<Reading?> getReading(int id) async => null;

  @override
  Future<int> saveReading(ReadingDraft draft) async => 1;

  @override
  Stream<List<Reading>> watchAllReadings() {
    return Stream<List<Reading>>.value(const <Reading>[]);
  }
}
