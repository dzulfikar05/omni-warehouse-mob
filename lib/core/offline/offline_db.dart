import 'package:hive_flutter/hive_flutter.dart';

/// Inisialisasi Hive untuk offline sync queue.
/// Panggil initOfflineDb() di main.dart sebelum runApp().
class OfflineDb {
  OfflineDb._();

  static const _syncQueueBoxName = 'sync_queue';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(_syncQueueBoxName);
  }

  static Box<Map> get syncQueueBox => Hive.box<Map>(_syncQueueBoxName);
}
