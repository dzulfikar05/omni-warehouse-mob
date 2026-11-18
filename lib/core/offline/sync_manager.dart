import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../api/api_endpoints.dart';
import '../api/api_exception.dart';
import '../../shared/utils/connectivity_checker.dart';
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
  const InboundSyncFailure({required this.localUuid, required this.message});

  final String localUuid;
  final String message;
}

class InboundSyncResult {
  const InboundSyncResult({required this.syncedCount, required this.failures});

  final int syncedCount;
  final List<InboundSyncFailure> failures;
}

class OutboundSyncFailure {
  const OutboundSyncFailure({required this.localUuid, required this.message});

  final String localUuid;
  final String message;
}

class OutboundSyncResult {
  const OutboundSyncResult({required this.syncedCount, required this.failures});

  final int syncedCount;
  final List<OutboundSyncFailure> failures;
}

/// Manager untuk offline queue — enqueue, sync, retry.
class SyncManager {
  SyncManager._();
  static final SyncManager instance = SyncManager._();
  Future<InboundSyncResult>? _activeInboundSync;
  Future<OutboundSyncResult>? _activeOutboundSync;
  Future<TransferSyncResult>? _activeTransferSync;
  Future<OpnameSyncResult>? _activeOpnameSync;

  Box<Map> get _box => OfflineDb.syncQueueBox;

  Future<bool> shouldSyncAutomatically() async {
    if (!await OfflineDb.isAutomaticSyncEnabled()) return false;
    return ConnectivityChecker.instance.isOnline();
  }

  Future<SyncBatchResult> syncAllQueues({
    required Dio dio,
    required String tenantSlug,
    required String ownerKey,
    required String authToken,
  }) async {
    final inbound = await syncInboundQueue(
      dio: dio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: authToken,
    );
    final outbound = await syncOutboundQueue(
      dio: dio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: authToken,
    );
    final transfer = await syncTransferQueue(
      dio: dio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: authToken,
    );
    final opname = await syncOpnameQueue(
      dio: dio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: authToken,
    );
    return SyncBatchResult(
      inboundSyncedCount: inbound.syncedCount,
      outboundSyncedCount: outbound.syncedCount,
      transferSyncedCount: transfer.syncedCount,
      opnameSyncedCount: opname.syncedCount,
      failureCount:
          inbound.failures.length +
          outbound.failures.length +
          transfer.failures.length +
          opname.failures.length,
    );
  }

  List<SyncQueueItem> getPendingItems() {
    return _box.values
        .map((m) => SyncQueueItem.fromMap(m))
        .where(
          (i) => i.status == SyncStatus.pending || i.status == SyncStatus.error,
        )
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
    operation =
        _performInboundSync(
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
        final manifestMap = manifest is Map
            ? manifest
            : const <String, dynamic>{};
        final serverCode =
            dataMap['manifest_code']?.toString() ??
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
        failures.add(InboundSyncFailure(localUuid: id, message: error.message));
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
  ) => OfflineDb.updateInboundQueueItem(
    localUuid: localUuid,
    tenantSlug: tenantSlug,
    ownerKey: ownerKey,
    status: 'error',
    errorMessage: message,
    incrementRetry: true,
  );

  Future<OutboundSyncResult> syncOutboundQueue({
    required Dio dio,
    required String tenantSlug,
    required String ownerKey,
    required String authToken,
    String? localUuid,
  }) async {
    final activeSync = _activeOutboundSync;
    if (activeSync != null) return activeSync;
    late final Future<OutboundSyncResult> operation;
    operation =
        _performOutboundSync(
          dio: dio,
          tenantSlug: tenantSlug,
          ownerKey: ownerKey,
          authToken: authToken,
          localUuid: localUuid,
        ).whenComplete(() {
          if (identical(_activeOutboundSync, operation)) {
            _activeOutboundSync = null;
          }
        });
    _activeOutboundSync = operation;
    return operation;
  }

  Future<OutboundSyncResult> _performOutboundSync({
    required Dio dio,
    required String tenantSlug,
    required String ownerKey,
    required String authToken,
    String? localUuid,
  }) async {
    var syncedCount = 0;
    final failures = <OutboundSyncFailure>[];
    final rows = await OfflineDb.getOutboundQueue(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      localUuid: localUuid,
    );

    for (final row in rows) {
      final id = row['local_uuid'] as String;
      await OfflineDb.updateOutboundQueueItem(
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
          ApiEndpoints.outboundSyncOffline(tenantSlug),
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
            message ?? 'Server tidak mengonfirmasi sinkronisasi outbound.',
          );
        }

        final data = body['data'];
        final dataMap = data is Map ? data : const <String, dynamic>{};
        final manifest = dataMap['manifest'];
        final manifestMap = manifest is Map
            ? manifest
            : const <String, dynamic>{};
        final serverCode =
            dataMap['manifest_code']?.toString() ??
            manifestMap['manifest_code']?.toString() ??
            dataMap['code']?.toString() ??
            id;
        await OfflineDb.updateOutboundQueueItem(
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
        await _markOutboundFailed(id, tenantSlug, ownerKey, message);
        failures.add(OutboundSyncFailure(localUuid: id, message: message));
      } on AppException catch (error) {
        await _markOutboundFailed(id, tenantSlug, ownerKey, error.message);
        failures.add(
          OutboundSyncFailure(localUuid: id, message: error.message),
        );
      } on FormatException catch (error) {
        final message =
            'Payload offline outbound tidak valid: ${error.message}';
        await _markOutboundFailed(id, tenantSlug, ownerKey, message);
        failures.add(OutboundSyncFailure(localUuid: id, message: message));
      }
    }

    return OutboundSyncResult(syncedCount: syncedCount, failures: failures);
  }

  Future<void> _markOutboundFailed(
    String localUuid,
    String tenantSlug,
    String ownerKey,
    String message,
  ) => OfflineDb.updateOutboundQueueItem(
    localUuid: localUuid,
    tenantSlug: tenantSlug,
    ownerKey: ownerKey,
    status: 'error',
    errorMessage: message,
    incrementRetry: true,
  );

  Future<OpnameSyncResult> syncOpnameQueue({
    required Dio dio,
    required String tenantSlug,
    required String ownerKey,
    required String authToken,
    String? localUuid,
  }) async {
    final activeSync = _activeOpnameSync;
    if (activeSync != null) return activeSync;
    late final Future<OpnameSyncResult> operation;
    operation =
        _performOpnameSync(
          dio: dio,
          tenantSlug: tenantSlug,
          ownerKey: ownerKey,
          authToken: authToken,
          localUuid: localUuid,
        ).whenComplete(() {
          if (identical(_activeOpnameSync, operation)) {
            _activeOpnameSync = null;
          }
        });
    _activeOpnameSync = operation;
    return operation;
  }

  Future<OpnameSyncResult> _performOpnameSync({
    required Dio dio,
    required String tenantSlug,
    required String ownerKey,
    required String authToken,
    String? localUuid,
  }) async {
    var syncedCount = 0;
    final failures = <OpnameSyncFailure>[];
    final rows = await OfflineDb.getOpnameQueue(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      localUuid: localUuid,
    );

    for (final row in rows) {
      final id = row['local_uuid'] as String;
      await OfflineDb.updateOpnameQueueItem(
        localUuid: id,
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
        status: 'syncing',
      );
      try {
        final payload = Map<String, dynamic>.from(
          jsonDecode(row['payload_json'] as String) as Map,
        );
        final identity = _opnameSessionIdentity(payload);
        final shouldSubmitReview = payload['should_submit_review'] == true;
        if (payload['counts_synced'] != true) {
          final response = await dio.post(
            ApiEndpoints.opnameSyncOffline(tenantSlug),
            data: _opnameSyncPayload(payload, identity),
            options: _opnameOptions(tenantSlug, authToken),
          );
          _requireOpnameSuccess(
            response.data,
            'Server tidak mengonfirmasi sinkronisasi opname.',
          );
          if (shouldSubmitReview) {
            payload['counts_synced'] = true;
            await OfflineDb.updateOpnameQueuePayload(
              localUuid: id,
              tenantSlug: tenantSlug,
              ownerKey: ownerKey,
              payload: payload,
            );
          }
        }
        if (shouldSubmitReview) {
          final response = await dio.post(
            ApiEndpoints.opnameSubmitReview(tenantSlug),
            data: identity,
            options: _opnameOptions(tenantSlug, authToken),
          );
          _requireOpnameSuccess(
            response.data,
            'Server tidak mengonfirmasi submit review opname.',
          );
        }
        await OfflineDb.updateOpnameQueueItem(
          localUuid: id,
          tenantSlug: tenantSlug,
          ownerKey: ownerKey,
          status: 'success',
        );
        syncedCount++;
      } on DioException catch (error) {
        final message = error.response?.statusCode == 422
            ? _opnameResponseError(error)
            : error.error is AppException
            ? (error.error as AppException).message
            : _opnameResponseError(error);
        await _markOpnameFailed(id, tenantSlug, ownerKey, message);
        failures.add(OpnameSyncFailure(localUuid: id, message: message));
      } on AppException catch (error) {
        await _markOpnameFailed(id, tenantSlug, ownerKey, error.message);
        failures.add(OpnameSyncFailure(localUuid: id, message: error.message));
      } on FormatException catch (error) {
        final message = 'Payload offline opname tidak valid: ${error.message}';
        await _markOpnameFailed(id, tenantSlug, ownerKey, message);
        failures.add(OpnameSyncFailure(localUuid: id, message: message));
      }
    }

    return OpnameSyncResult(syncedCount: syncedCount, failures: failures);
  }

  Future<void> _markOpnameFailed(
    String localUuid,
    String tenantSlug,
    String ownerKey,
    String message,
  ) => OfflineDb.updateOpnameQueueItem(
    localUuid: localUuid,
    tenantSlug: tenantSlug,
    ownerKey: ownerKey,
    status: 'error',
    errorMessage: message,
    incrementRetry: true,
  );

  Map<String, dynamic> _opnameSessionIdentity(Map<String, dynamic> payload) {
    final sessionId = int.tryParse(payload['session_id']?.toString() ?? '');
    if (sessionId != null && sessionId > 0) {
      return {'session_id': sessionId};
    }
    final sessionCode = payload['session_code']?.toString() ?? '';
    if (sessionCode.isNotEmpty) return {'session_code': sessionCode};
    throw const FormatException(
      'Payload offline opname tidak memiliki identitas sesi.',
    );
  }

  Map<String, dynamic> _opnameSyncPayload(
    Map<String, dynamic> payload,
    Map<String, dynamic> identity,
  ) {
    final rawItems = payload['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      throw const FormatException(
        'Payload offline opname tidak memiliki item untuk disinkronkan.',
      );
    }
    final items = <Map<String, dynamic>>[];
    for (final rawItem in rawItems) {
      if (rawItem is! Map || rawItem['physical_qty'] == null) {
        throw const FormatException(
          'Setiap item opname harus menyertakan physical_qty.',
        );
      }
      final item = <String, dynamic>{
        for (final key in const [
          'item_id',
          'barcode',
          'location_id',
          'target_rack',
        ])
          if (rawItem[key] != null) key: rawItem[key],
        'physical_qty': rawItem['physical_qty'],
      };
      if (!item.containsKey('item_id') && !item.containsKey('barcode')) {
        throw const FormatException(
          'Item opname harus memiliki item_id atau barcode.',
        );
      }
      items.add(item);
    }
    return {...identity, 'items': items};
  }

  Options _opnameOptions(String tenantSlug, String authToken) => Options(
    headers: {
      'Authorization': 'Bearer $authToken',
      'X-Tenant-Slug': tenantSlug,
    },
  );

  void _requireOpnameSuccess(dynamic body, String fallback) {
    if (body is! Map || body['success'] != true) {
      final message = body is Map ? body['message']?.toString() : null;
      throw ServerException(message ?? fallback);
    }
  }

  String _opnameResponseError(DioException error) {
    final body = error.response?.data;
    if (error.response?.statusCode == 422 && body is Map) {
      final rawErrors = body['errors'];
      final details = <String>[];
      if (rawErrors is Map) {
        for (final value in rawErrors.values) {
          if (value is List) {
            details.addAll(value.map((item) => item.toString()));
          }
        }
      }
      final message = body['message']?.toString();
      if (details.isNotEmpty) {
        return '${message ?? 'Validasi gagal.'} ${details.join(' ')}';
      }
      if (message != null) return message;
    }
    return _responseError(error);
  }

  Future<TransferSyncResult> syncTransferQueue({
    required Dio dio,
    required String tenantSlug,
    required String ownerKey,
    required String authToken,
    String? localUuid,
  }) async {
    final activeSync = _activeTransferSync;
    if (activeSync != null) return activeSync;
    late final Future<TransferSyncResult> operation;
    operation =
        _performTransferSync(
          dio: dio,
          tenantSlug: tenantSlug,
          ownerKey: ownerKey,
          authToken: authToken,
          localUuid: localUuid,
        ).whenComplete(() {
          if (identical(_activeTransferSync, operation)) {
            _activeTransferSync = null;
          }
        });
    _activeTransferSync = operation;
    return operation;
  }

  Future<TransferSyncResult> _performTransferSync({
    required Dio dio,
    required String tenantSlug,
    required String ownerKey,
    required String authToken,
    String? localUuid,
  }) async {
    var syncedCount = 0;
    final failures = <TransferSyncFailure>[];
    final rows = await OfflineDb.getTransferQueue(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      localUuid: localUuid,
    );

    for (final row in rows) {
      final id = row['local_uuid'] as String;
      await OfflineDb.updateTransferQueueItem(
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
          ApiEndpoints.transferSyncOffline(tenantSlug),
          data: payload,
          options: Options(
            headers: {
              'Authorization': 'Bearer $authToken',
              'X-Tenant-Slug': tenantSlug,
            },
          ),
        );
        final body = response.data;
        final data = body is Map && body['data'] is Map
            ? Map<String, dynamic>.from(body['data'] as Map)
            : const <String, dynamic>{};
        final alreadySynced = data['already_synced'] == true;
        if (body is! Map || body['success'] != true && !alreadySynced) {
          final message = body is Map ? body['message']?.toString() : null;
          throw ServerException(
            message ?? 'Server tidak mengonfirmasi sinkronisasi transfer.',
          );
        }

        final serverCode = data['transfer_code']?.toString();
        final serverStatus = data['status']?.toString();
        if (serverCode == null ||
            serverCode.isEmpty ||
            serverStatus == null ||
            serverStatus.isEmpty) {
          throw const ServerException(
            'Respons sinkronisasi transfer tidak memuat kode dan status transfer.',
          );
        }
        await OfflineDb.updateTransferQueueItem(
          localUuid: id,
          tenantSlug: tenantSlug,
          ownerKey: ownerKey,
          status: 'success',
          serverTransferCode: serverCode,
          serverStatus: serverStatus,
        );
        syncedCount++;
      } on DioException catch (error) {
        final message = _transferResponseError(error);
        await _markTransferFailed(id, tenantSlug, ownerKey, message);
        failures.add(TransferSyncFailure(localUuid: id, message: message));
      } on AppException catch (error) {
        await _markTransferFailed(id, tenantSlug, ownerKey, error.message);
        failures.add(
          TransferSyncFailure(localUuid: id, message: error.message),
        );
      } on FormatException catch (error) {
        final message =
            'Payload offline transfer tidak valid: ${error.message}';
        await _markTransferFailed(id, tenantSlug, ownerKey, message);
        failures.add(TransferSyncFailure(localUuid: id, message: message));
      }
    }

    return TransferSyncResult(syncedCount: syncedCount, failures: failures);
  }

  Future<void> _markTransferFailed(
    String localUuid,
    String tenantSlug,
    String ownerKey,
    String message,
  ) => OfflineDb.updateTransferQueueItem(
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

  String _transferResponseError(DioException error) {
    final body = error.response?.data;
    if (body is Map) {
      final rawErrors = body['errors'];
      final details = <String>[];
      if (rawErrors is Map) {
        for (final value in rawErrors.values) {
          if (value is List) {
            details.addAll(value.map((item) => item.toString()));
          }
        }
      }
      final message = body['message']?.toString();
      if (details.isNotEmpty) {
        return '${message ?? 'Validasi gagal.'} ${details.join(' ')}';
      }
      if (message != null && message.isNotEmpty) return message;
    }
    if (error.error is ValidationException) {
      final validation = error.error as ValidationException;
      final details = validation.errors.values
          .expand((messages) => messages)
          .join(' ');
      return details.isEmpty
          ? validation.message
          : '${validation.message} $details';
    }
    if (error.error is AppException) {
      return (error.error as AppException).message;
    }
    return _responseError(error);
  }
}

class TransferSyncFailure {
  const TransferSyncFailure({required this.localUuid, required this.message});

  final String localUuid;
  final String message;
}

class TransferSyncResult {
  const TransferSyncResult({required this.syncedCount, required this.failures});

  final int syncedCount;
  final List<TransferSyncFailure> failures;
}

class OpnameSyncFailure {
  const OpnameSyncFailure({required this.localUuid, required this.message});

  final String localUuid;
  final String message;
}

class OpnameSyncResult {
  const OpnameSyncResult({required this.syncedCount, required this.failures});

  final int syncedCount;
  final List<OpnameSyncFailure> failures;
}

class SyncBatchResult {
  const SyncBatchResult({
    required this.inboundSyncedCount,
    required this.outboundSyncedCount,
    required this.transferSyncedCount,
    required this.opnameSyncedCount,
    required this.failureCount,
  });

  final int inboundSyncedCount;
  final int outboundSyncedCount;
  final int transferSyncedCount;
  final int opnameSyncedCount;
  final int failureCount;

  int get syncedCount =>
      inboundSyncedCount +
      outboundSyncedCount +
      transferSyncedCount +
      opnameSyncedCount;
}
