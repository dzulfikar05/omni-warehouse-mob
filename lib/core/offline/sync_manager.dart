import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../api/api_endpoints.dart';
import '../api/api_exception.dart';
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

class InboundSyncFailure {
  const InboundSyncFailure({
    required this.localUuid,
    required this.message,
  });

  final String localUuid;
  final String message;
}

class InboundSyncResult {
  const InboundSyncResult({
    required this.syncedCount,
    required this.failures,
  });

  final int syncedCount;
  final List<InboundSyncFailure> failures;
}

/// Manager untuk offline queue — enqueue, sync, retry.
class SyncManager {
  SyncManager._();
  static final SyncManager instance = SyncManager._();
  Future<InboundSyncResult>? _activeInboundSync;

  Box<Map> get _box => OfflineDb.syncQueueBox;

  List<SyncQueueItem> getPendingItems() {
    return _box.values
        .map((m) => SyncQueueItem.fromMap(m))
        .where((i) =>
            i.status == SyncStatus.pending || i.status == SyncStatus.error)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // FIFO
  }

  Future<void> enqueue(SyncQueueItem item) async {
    await _box.put(item.id, item.toMap() as Map<dynamic, dynamic>);
  }

  Future<InboundSyncResult> syncInboundQueue({
    required Dio dio,
    required String tenantSlug,
    required String ownerKey,
    required String authToken,
    String? localUuid,
  }) async {
    final activeSync = _activeInboundSync;
    if (activeSync != null) return activeSync;
    late final Future<InboundSyncResult> operation;
    operation = _performInboundSync(
      dio: dio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: authToken,
      localUuid: localUuid,
    ).whenComplete(() {
      if (identical(_activeInboundSync, operation)) {
        _activeInboundSync = null;
      }
    });
    _activeInboundSync = operation;
    return operation;
  }

  Future<InboundSyncResult> _performInboundSync({
    required Dio dio,
    required String tenantSlug,
    required String ownerKey,
    required String authToken,
    String? localUuid,
  }) async {
    var syncedCount = 0;
    final failures = <InboundSyncFailure>[];

    final rows = await OfflineDb.getInboundQueue(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      localUuid: localUuid,
    );
    for (final row in rows) {
      final id = row['local_uuid'] as String;
      await OfflineDb.updateInboundQueueItem(
        localUuid: id,
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
        status: 'syncing',
      );

      try {
        final payload = Map<String, dynamic>.from(
          jsonDecode(row['payload_json'] as String) as Map,
        );
        final response = await dio.post(
          ApiEndpoints.inboundSyncOffline(tenantSlug),
          data: payload,
          options: Options(
            headers: {
              'Authorization': 'Bearer $authToken',
              'X-Tenant-Slug': tenantSlug,
            },
          ),
        );
        final body = response.data;
        if (body is! Map || body['success'] != true) {
          final message = body is Map ? body['message']?.toString() : null;
          throw ServerException(
            message ?? 'Server tidak mengonfirmasi sinkronisasi inbound.',
          );
        }

        final data = body['data'];
        final dataMap = data is Map ? data : const <String, dynamic>{};
        final manifest = dataMap['manifest'];
        final manifestMap =
            manifest is Map ? manifest : const <String, dynamic>{};
        final serverCode = dataMap['manifest_code']?.toString() ??
            manifestMap['manifest_code']?.toString();
        await OfflineDb.updateInboundQueueItem(
          localUuid: id,
          tenantSlug: tenantSlug,
          ownerKey: ownerKey,
          status: 'success',
          serverManifestCode: serverCode,
        );
        syncedCount++;
      } on DioException catch (error) {
        final message = error.error is AppException
            ? (error.error as AppException).message
            : _responseError(error);
        await _markFailed(id, tenantSlug, ownerKey, message);
        failures.add(InboundSyncFailure(localUuid: id, message: message));
      } on AppException catch (error) {
        await _markFailed(id, tenantSlug, ownerKey, error.message);
        failures.add(
          InboundSyncFailure(localUuid: id, message: error.message),
        );
      } on FormatException catch (error) {
        final message = 'Payload offline tidak valid: ${error.message}';
        await _markFailed(id, tenantSlug, ownerKey, message);
        failures.add(InboundSyncFailure(localUuid: id, message: message));
      }
    }

    return InboundSyncResult(syncedCount: syncedCount, failures: failures);
  }

  Future<void> _markFailed(
    String localUuid,
    String tenantSlug,
    String ownerKey,
    String message,
  ) =>
      OfflineDb.updateInboundQueueItem(
        localUuid: localUuid,
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
        status: 'error',
        errorMessage: message,
        incrementRetry: true,
      );

  String _responseError(DioException error) {
    final body = error.response?.data;
    if (body is Map && body['message'] != null) {
      return body['message'].toString();
    }
    return error.message ?? 'Sinkronisasi gagal karena koneksi/server.';
  }
}
