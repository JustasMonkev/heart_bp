import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'src/app.dart';
import 'src/data/readings_database.dart';
import 'src/data/sqlite_reading_repository.dart';
import 'src/services/capture_and_scan_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final documentsDirectory = await getApplicationDocumentsDirectory();
  final database = await openReadingsDatabase(
    path: p.join(documentsDirectory.path, 'heart_bp.db'),
  );

  runApp(
    HeartBpApp(
      repository: SqliteReadingRepository(database),
      captureAndScanService: CameraCaptureAndScanService(),
    ),
  );
}
