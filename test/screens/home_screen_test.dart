import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_bp/src/data/reading_repository.dart';
import 'package:heart_bp/src/models/reading.dart';
import 'package:heart_bp/src/models/reading_draft.dart';
import 'package:heart_bp/src/screens/home_screen.dart';
import 'package:heart_bp/src/services/capture_and_scan_service.dart';
import 'package:intl/intl.dart';

void main() {
  testWidgets('latest card shows the newest pressure pulse and time only', (
    tester,
  ) async {
    final repository = _FakeReadingRepository(
      readings: [
        _reading(
          id: 1,
          capturedAt: DateTime(2026, 4, 25, 6, 30),
          systolic: 157,
          diastolic: 72,
          pulse: 67,
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

    expect(find.text('HEART BP'), findsOneWidget);
    expect(find.text('157'), findsWidgets);
    expect(find.text('72'), findsWidgets);
    expect(find.text('mmHg'), findsWidgets);
    expect(find.text('06:30'), findsOneWidget);
    expect(find.text('67 bpm'), findsOneWidget);
    expect(find.text('High Stage 2'), findsOneWidget);
    expect(find.text('7-DAY SYSTOLIC'), findsNothing);
  });

  testWidgets('shows the logging streak from completed saved days', (
    tester,
  ) async {
    final today = DateTime.now();
    final currentDay = DateTime(today.year, today.month, today.day);
    final repository = _FakeReadingRepository(
      readings: [
        _reading(
          id: 2,
          capturedAt: currentDay.add(const Duration(hours: 8)),
          systolic: 124,
        ),
        _reading(
          id: 1,
          capturedAt: currentDay
              .subtract(const Duration(days: 1))
              .add(const Duration(hours: 8)),
          systolic: 121,
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

    expect(find.text('1-day streak'), findsOneWidget);
    expect(find.text('Log today to keep it going.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Quick entry'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Quick entry'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Open history'), findsNothing);
  });

  testWidgets('keeps a streak when today has not been logged', (tester) async {
    final today = DateTime.now();
    final currentDay = DateTime(today.year, today.month, today.day);
    final repository = _FakeReadingRepository(
      readings: [
        for (var daysAgo = 1; daysAgo <= 6; daysAgo++)
          _reading(
            id: daysAgo,
            capturedAt: currentDay
                .subtract(Duration(days: daysAgo))
                .add(const Duration(hours: 8)),
            systolic: 121,
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

    expect(find.text('6-day streak'), findsOneWidget);
  });

  testWidgets('recent reading opens the blood pressure result detail', (
    tester,
  ) async {
    final today = DateTime.now();
    final currentDay = DateTime(today.year, today.month, today.day);
    final repository = _FakeReadingRepository(
      readings: [
        _reading(
          id: 1,
          capturedAt: currentDay.add(const Duration(hours: 8)),
          systolic: 124,
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
    await tester.scrollUntilVisible(find.text('124/75'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('124/75').last);
    await tester.pumpAndSettle();

    expect(find.text('READING'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
  });

  testWidgets('calendar jumps through months from the home streak card', (
    tester,
  ) async {
    final today = DateTime.now();
    final currentDay = DateTime(today.year, today.month, today.day);
    final previousMonth = DateTime(currentDay.year, currentDay.month - 1);
    final repository = _FakeReadingRepository(
      readings: [
        _reading(
          id: 1,
          capturedAt: currentDay.add(const Duration(hours: 8)),
          systolic: 124,
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
    await tester.tap(find.text('0-day streak'));
    await tester.pumpAndSettle();

    expect(find.text(_monthLabel(currentDay)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-previous-month')));
    await tester.pumpAndSettle();

    expect(find.text(_monthLabel(previousMonth)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-next-month')));
    await tester.pumpAndSettle();

    expect(find.text(_monthLabel(currentDay)), findsOneWidget);
  });

  testWidgets('calendar day opens a modal with every reading from that day', (
    tester,
  ) async {
    final today = DateTime.now();
    final currentDay = DateTime(today.year, today.month, today.day);
    final repository = _FakeReadingRepository(
      readings: [
        _reading(
          id: 2,
          capturedAt: currentDay.add(const Duration(hours: 19, minutes: 15)),
          systolic: 132,
        ),
        _reading(
          id: 1,
          capturedAt: currentDay.add(const Duration(hours: 8, minutes: 5)),
          systolic: 124,
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
    await tester.tap(find.text('0-day streak'));
    await tester.pumpAndSettle();
    final dayFinder = find.byKey(
      ValueKey('calendar-day-${_dateKey(currentDay)}'),
    );
    await tester.ensureVisible(dayFinder);
    await tester.pumpAndSettle();
    await tester.tap(dayFinder);
    await tester.pumpAndSettle();

    expect(find.text('2 measurements'), findsOneWidget);
    expect(find.text('124/75'), findsWidgets);
    expect(find.text('132/75'), findsWidgets);
    expect(find.text('Pulse 69'), findsNWidgets(2));
  });
}

Reading _reading({
  required int id,
  required DateTime capturedAt,
  required int systolic,
  int diastolic = 75,
  int pulse = 69,
}) {
  return Reading(
    id: id,
    capturedAt: capturedAt,
    systolic: systolic,
    diastolic: diastolic,
    pulse: pulse,
    imagePath: '',
    rawOcrText: '',
    createdAt: capturedAt,
  );
}

String _monthLabel(DateTime date) {
  return DateFormat('MMMM yyyy').format(date).toUpperCase();
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
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
