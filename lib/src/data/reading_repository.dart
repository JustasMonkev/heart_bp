import 'dart:typed_data';

import '../models/reading.dart';
import '../models/reading_draft.dart';

class PdfReport {
  PdfReport({
    required this.filename,
    required this.bytes,
  });

  final String filename;
  final Uint8List bytes;
}

abstract class ReadingRepository {
  Stream<List<Reading>> watchAllReadings();

  Future<Reading?> getReading(int id);

  Future<int> saveReading(ReadingDraft draft);

  Future<void> deleteReading(int id);

  Future<PdfReport> createPdfReport();
}
