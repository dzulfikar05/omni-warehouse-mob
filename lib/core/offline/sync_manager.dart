import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'offline_db.dart';

/// Tipe transaksi yang bisa masuk ke offline queue.
enum SyncTransactionType {
  inboundPutaway,
  outboundPacking,
  opnameCount,
  stockTransfer,
}

/// Status item di queue.
enum SyncStatus { pending, syncing, success, error }

/// Model untuk satu item di sync queue.
class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.status = SyncStatus.pending,
    this.errorMessage,
    this.retryCount = 0,
  });

  final String id;
  final SyncTransactionType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final SyncStatus status;
  final String? errorMessage;
  final int retryCount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'payload': jsonEncode(payload),
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'errorMessage': errorMessage,
        'retryCount': retryCount,
      };

  factory SyncQueueItem.fromMap(Map map) => SyncQueueItem(
        id: map['id'] as String,
        type: SyncTransactionType.values.byName(map['type'] as String),
        payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
        createdAt: DateTime.parse(map['createdAt'] as String),
        status: SyncStatus.values.byName(map['status'] as String),
        errorMessage: map['errorMessage'] as String?,
        retryCount: (map['retryCount'] as int?) ?? 0,
      );
}

/// Manager untuk offline queue — enqueue, sync, retry.
class SyncManager {
  SyncManager._();
  static final SyncManager instance = SyncManager._();

  Box<Map> get _box => OfflineDb.syncQueueBox;

  List<SyncQueueItem> getPendingItems() {
    return _box.values
        .map((m) => SyncQueueItem.fromMap(m))
        .where((i) => i.status == SyncStatus.pending || i.status == SyncStatus.error)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // FIFO
  }

  Future<void> enqueue(SyncQueueItem item) async {
    await _box.put(item.id, item.toMap() as Map<dynamic, dynamic>);
  }

  // TODO: syncAll() — dipanggil saat connectivity kembali online
  // Iterate getPendingItems(), POST ke API, update status
}
