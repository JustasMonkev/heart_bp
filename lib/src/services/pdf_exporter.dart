import 'package:printing/printing.dart';

import '../data/reading_repository.dart';

abstract class PdfExporter {
  Future<void> share(PdfReport report);
}

class PrintingPdfExporter implements PdfExporter {
  const PrintingPdfExporter();

  @override
  Future<void> share(PdfReport report) {
    return Printing.sharePdf(bytes: report.bytes, filename: report.filename);
  }
}
