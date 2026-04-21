import 'package:sqflite/sqflite.dart';

Future<Database> openReadingsDatabase({
  required String path,
  DatabaseFactory? factoryOverride,
}) {
  final factory = factoryOverride ?? databaseFactory;

  return factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE readings(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            captured_at INTEGER NOT NULL,
            systolic INTEGER NOT NULL,
            diastolic INTEGER NOT NULL,
            pulse INTEGER NOT NULL,
            image_path TEXT NOT NULL,
            raw_ocr_text TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    ),
  );
}
