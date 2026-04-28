import 'package:flutter/services.dart';

import '../data/reading_repository.dart';
import '../models/reading.dart';
import '../models/reading_draft.dart';

abstract class HomeWidgetSync {
  const HomeWidgetSync();

  Future<void> updateLatestReading(Reading? reading);
}

class MethodChannelHomeWidgetSync extends HomeWidgetSync {
  const MethodChannelHomeWidgetSync();

  static const MethodChannel _channel = MethodChannel('heart_bp/home_widget');

  @override
  Future<void> updateLatestReading(Reading? reading) async {
    if (reading == null) {
      await _channel.invokeMethod<void>('clearLatestReading');
      return;
    }

    await _channel.invokeMethod<void>('updateLatestReading', {
      'systolic': reading.systolic,
      'diastolic': reading.diastolic,
      'pulse': reading.pulse,
      'capturedAtMillis': reading.capturedAt.millisecondsSinceEpoch,
      'level': reading.pressureLevel.name,
      'levelLabel': reading.pressureLevel.label,
    });
  }
}

class HomeWidgetReadingRepository implements ReadingRepository {
  HomeWidgetReadingRepository(this._delegate, this._sync);

  final ReadingRepository _delegate;
  final HomeWidgetSync _sync;

  Future<void> syncLatestReading() async {
    try {
      final readings = await _delegate.watchAllReadings().first;
      await _sync.updateLatestReading(readings.isEmpty ? null : readings.first);
    } catch (_) {
      // Widget sync must never block the core health log workflow.
    }
  }

  @override
  Future<PdfReport> createPdfReport() {
    return _delegate.createPdfReport();
  }

  @override
  Future<void> deleteReading(int id) async {
    await _delegate.deleteReading(id);
    await syncLatestReading();
  }

  @override
  Future<Reading?> getReading(int id) {
    return _delegate.getReading(id);
  }

  @override
  Future<int> saveReading(ReadingDraft draft) async {
    final id = await _delegate.saveReading(draft);
    await syncLatestReading();
    return id;
  }

  @override
  Stream<List<Reading>> watchAllReadings() {
    return _delegate.watchAllReadings();
  }
}
