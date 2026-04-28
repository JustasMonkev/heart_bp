import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_bp/src/data/reading_repository.dart';
import 'package:heart_bp/src/models/reading.dart';
import 'package:heart_bp/src/models/reading_draft.dart';
import 'package:heart_bp/src/services/home_widget_sync.dart';

void main() {
  test('syncs the latest reading on demand save and delete', () async {
    final firstReading = _reading(
      id: 1,
      capturedAt: DateTime(2026, 4, 24, 8),
      systolic: 124,
    );
    final delegate = _FakeReadingRepository(readings: [firstReading]);
    final sync = _RecordingHomeWidgetSync();
    final repository = HomeWidgetReadingRepository(delegate, sync);

    await repository.syncLatestReading();

    expect(sync.readings.single, same(firstReading));

    await repository.saveReading(
      ReadingDraft(
        systolicText: '157',
        diastolicText: '72',
        pulseText: '67',
        imagePath: '',
        rawOcrText: '',
        capturedAt: DateTime(2026, 4, 25, 6, 30),
      ),
    );

    expect(sync.readings.last?.systolic, 157);
    expect(sync.readings.last?.pulse, 67);

    await repository.deleteReading(2);

    expect(sync.readings.last, same(firstReading));

    await repository.deleteReading(1);

    expect(sync.readings.last, isNull);
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

class _RecordingHomeWidgetSync extends HomeWidgetSync {
  final List<Reading?> readings = [];

  @override
  Future<void> updateLatestReading(Reading? reading) async {
    readings.add(reading);
  }
}

class _FakeReadingRepository implements ReadingRepository {
  _FakeReadingRepository({required List<Reading> readings})
    : _readings = List<Reading>.from(readings);

  final List<Reading> _readings;

  @override
  Future<PdfReport> createPdfReport() async {
    return PdfReport(filename: 'report.pdf', bytes: Uint8List(0));
  }

  @override
  Future<void> deleteReading(int id) async {
    _readings.removeWhere((reading) => reading.id == id);
  }

  @override
  Future<Reading?> getReading(int id) async {
    for (final reading in _readings) {
      if (reading.id == id) return reading;
    }
    return null;
  }

  @override
  Future<int> saveReading(ReadingDraft draft) async {
    final id = (_readings.map((reading) => reading.id).fold(0, _max)) + 1;
    _readings.add(
      _reading(
        id: id,
        capturedAt: draft.capturedAt,
        systolic: int.parse(draft.systolicText),
        diastolic: int.parse(draft.diastolicText),
        pulse: int.parse(draft.pulseText),
      ),
    );
    return id;
  }

  @override
  Stream<List<Reading>> watchAllReadings() async* {
    final readings = List<Reading>.from(_readings)
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    yield readings;
  }
}

int _max(int a, int b) => a > b ? a : b;
