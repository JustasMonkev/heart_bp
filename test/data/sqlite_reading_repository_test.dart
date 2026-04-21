import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:heart_bp/src/data/readings_database.dart';
import 'package:heart_bp/src/data/sqlite_reading_repository.dart';
import 'package:heart_bp/src/models/reading_draft.dart';

void main() {
  late Database database;
  late SqliteReadingRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    database = await openReadingsDatabase(
      path: inMemoryDatabasePath,
      factoryOverride: databaseFactoryFfi,
    );
    repository = SqliteReadingRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('saves and reads back a blood pressure reading', () async {
    final id = await repository.saveReading(
      ReadingDraft(
        systolicText: '139',
        diastolicText: '72',
        pulseText: '62',
        imagePath: p.join('/tmp', 'reading.jpg'),
        rawOcrText: 'SYS 139 DIA 72 PULSE 62',
        capturedAt: DateTime(2026, 4, 21, 9, 5),
      ),
    );

    final saved = await repository.getReading(id);

    expect(saved, isNotNull);
    expect(saved!.systolic, 139);
    expect(saved.diastolic, 72);
    expect(saved.pulse, 62);
    expect(saved.imagePath, endsWith('reading.jpg'));
  });

  test('watches readings newest first', () async {
    await repository.saveReading(
      ReadingDraft(
        systolicText: '121',
        diastolicText: '79',
        pulseText: '67',
        imagePath: '/tmp/one.jpg',
        rawOcrText: 'one',
        capturedAt: DateTime(2026, 4, 20, 18, 41),
      ),
    );
    await repository.saveReading(
      ReadingDraft(
        systolicText: '139',
        diastolicText: '72',
        pulseText: '62',
        imagePath: '/tmp/two.jpg',
        rawOcrText: 'two',
        capturedAt: DateTime(2026, 4, 21, 9, 5),
      ),
    );

    final readings = await repository.watchAllReadings().first;

    expect(readings, hasLength(2));
    expect(readings.first.systolic, 139);
    expect(readings.last.systolic, 121);
  });

  test('deletes a saved reading', () async {
    final id = await repository.saveReading(
      ReadingDraft(
        systolicText: '139',
        diastolicText: '72',
        pulseText: '62',
        imagePath: '/tmp/one.jpg',
        rawOcrText: 'one',
        capturedAt: DateTime(2026, 4, 21, 9, 5),
      ),
    );

    await repository.deleteReading(id);

    final reading = await repository.getReading(id);

    expect(reading, isNull);
  });

  test('creates a pdf report containing the saved values', () async {
    await repository.saveReading(
      ReadingDraft(
        systolicText: '139',
        diastolicText: '72',
        pulseText: '62',
        imagePath: '/tmp/one.jpg',
        rawOcrText: 'one',
        capturedAt: DateTime(2026, 4, 21, 9, 5),
      ),
    );

    final report = await repository.createPdfReport();
    final content = String.fromCharCodes(report.bytes);

    expect(report.filename, contains('blood-pressure-report'));
    expect(report.bytes, isNotEmpty);
    expect(content, contains('139'));
    expect(content, contains('72'));
    expect(content, contains('62'));
  });
}
