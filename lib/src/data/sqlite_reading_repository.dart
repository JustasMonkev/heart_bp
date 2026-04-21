import 'dart:async';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite/sqflite.dart';

import 'reading_repository.dart';
import '../models/reading.dart';
import '../models/reading_draft.dart';

class SqliteReadingRepository implements ReadingRepository {
  SqliteReadingRepository(this._database);

  final Database _database;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<List<Reading>> watchAllReadings() async* {
    yield await _fetchAllReadings();
    yield* _changes.stream.asyncMap((_) => _fetchAllReadings());
  }

  @override
  Future<Reading?> getReading(int id) async {
    final rows = await _database.query(
      'readings',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return Reading.fromMap(rows.first);
  }

  @override
  Future<int> saveReading(ReadingDraft draft) async {
    final now = DateTime.now();
    final id = await _database.insert('readings', {
      'captured_at': draft.capturedAt.millisecondsSinceEpoch,
      'systolic': int.parse(draft.systolicText.trim()),
      'diastolic': int.parse(draft.diastolicText.trim()),
      'pulse': int.parse(draft.pulseText.trim()),
      'image_path': draft.imagePath,
      'raw_ocr_text': draft.rawOcrText,
      'created_at': now.millisecondsSinceEpoch,
    });
    _changes.add(null);
    return id;
  }

  @override
  Future<void> deleteReading(int id) async {
    await _database.delete('readings', where: 'id = ?', whereArgs: [id]);
    _changes.add(null);
  }

  @override
  Future<PdfReport> createPdfReport() async {
    final readings = await _fetchAllReadings();
    final document = pw.Document(compress: false);
    final formatter = DateFormat('yyyy-MM-dd HH:mm');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            pw.Text(
              'Blood Pressure Report',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: const ['Date/Time', 'Systolic', 'Diastolic', 'Pulse'],
              data: [
                for (final reading in readings)
                  [
                    formatter.format(reading.capturedAt),
                    '${reading.systolic}',
                    '${reading.diastolic}',
                    '${reading.pulse}',
                  ],
              ],
            ),
          ];
        },
      ),
    );

    final bytes = await document.save();
    return PdfReport(
      filename:
          'blood-pressure-report-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.pdf',
      bytes: bytes,
    );
  }

  Future<List<Reading>> _fetchAllReadings() async {
    final rows = await _database.query(
      'readings',
      orderBy: 'captured_at DESC, id DESC',
    );
    return rows.map(Reading.fromMap).toList();
  }
}
