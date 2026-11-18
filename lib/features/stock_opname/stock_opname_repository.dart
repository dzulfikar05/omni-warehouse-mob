import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/offline/offline_db.dart';
import '../../core/offline/offline_identity.dart';
import '../../core/offline/sync_manager.dart';
import 'stock_opname_local_id.dart';
import 'stock_opname_model.dart';

class OpnameSyncOutcome {
  const OpnameSyncOutcome({required this.synced, this.errorMessage});

  final bool synced;
  final String? errorMessage;
}

abstract class StockOpnameRepository {
  Future<StockOpnameSession?> getActiveSession(String tenantSlug);
  Future<OpnameSyncOutcome> recordCount(
    String tenantSlug, {
    required int itemId,
    required num physicalQty,
  });
  Future<OpnameSyncOutcome> submitReview(
    String tenantSlug, {
    required int sessionId,
  });
}

class ApiStockOpnameRepository implements StockOpnameRepository {
  ApiStockOpnameRepository(this._dio);

  final Dio _dio;

  AppException _mapFailure(DioException error, String fallback) {
    if (error.error is AppException) return error.error as AppException;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return NetworkException(error.message ?? fallback);
    }
    return ServerException(fallback);
  }

  Map<String, dynamic> _asMap(dynamic value, String message) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw ServerException(message);
  }

  void _requireSuccess(Map<String, dynamic> envelope, String fallback) {
    if (envelope['success'] == false) {
      throw ServerException(envelope['message']?.toString() ?? fallback);
    }
  }

  @override
  Future<StockOpnameSession?> getActiveSession(String tenantSlug) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.opnameActiveSession(tenantSlug),
      );
      final envelope = _asMap(
        response.data,
        'Format respons sesi stock opname tidak valid.',
      );
      _requireSuccess(envelope, 'Gagal memuat sesi stock opname aktif.');
      final rawData = envelope['data'];
      if (rawData == null || rawData is List && rawData.isEmpty) return null;

      final data = _asMap(rawData, 'Data sesi stock opname tidak valid.');
      final rawSession = data['session'] ?? data['active_session'];
      if (data.containsKey('session') && rawSession == null ||
          data.containsKey('active_session') && rawSession == null) {
        return null;
      }
      final sessionData =
          rawSession is Map ? Map<String, dynamic>.from(rawSession) : data;
      if (rawSession is Map && !sessionData.containsKey('items')) {
        sessionData['items'] =
            data['items'] ?? data['details'] ?? data['session_items'];
      }
      if (sessionData['id'] == null && sessionData['session_id'] == null) {
        if (sessionData.isEmpty || !sessionData.containsKey('session_code')) {
          return null;
        }
      }
      return StockOpnameSession.fromJson(sessionData);
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal memuat sesi stock opname aktif.');
    }
  }

  @override
  Future<OpnameSyncOutcome> recordCount(
    String tenantSlug, {
    required int itemId,
    required num physicalQty,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.opnameRecordCount(tenantSlug),
        data: {'item_id': itemId, 'physical_qty': physicalQty},
      );
      final envelope = _asMap(
        response.data,
        'Format respons jumlah fisik tidak valid.',
      );
      _requireSuccess(envelope, 'Gagal menyimpan jumlah fisik.');
      return const OpnameSyncOutcome(synced: true);
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal menyimpan jumlah fisik.');
    }
  }

  @override
  Future<OpnameSyncOutcome> submitReview(
    String tenantSlug, {
    required int sessionId,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.opnameSubmitReview(tenantSlug),
        data: {'session_id': sessionId},
      );
      final envelope = _asMap(
        response.data,
        'Format respons submit stock opname tidak valid.',
      );
      _requireSuccess(envelope, 'Gagal mengirim sesi untuk review.');
      return const OpnameSyncOutcome(synced: true);
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal mengirim sesi untuk review.');
    }
  }
}

class OfflineStockOpnameRepository implements StockOpnameRepository {
  OfflineStockOpnameRepository({
    required this.api,
    required this.dio,
    required this.ownerKey,
    required this.authToken,
    required this.operatorName,
  });

  final ApiStockOpnameRepository api;
  final Dio dio;
  final String ownerKey;
  final String authToken;
  final String operatorName;

  @override
  Future<StockOpnameSession?> getActiveSession(String tenantSlug) async {
    try {
      final remote = await api.getActiveSession(tenantSlug);
      if (remote != null) {
        await _cacheSession(tenantSlug, remote);
        return await _applyPending(tenantSlug, remote);
      }
      final cached = await _getCachedSession(tenantSlug);
      if (cached == null) return null;
      final pending = await OfflineDb.getPendingOpnameForSession(
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
        sessionCode: cached.sessionCode,
      );
      return pending.isEmpty ? null : await _applyPending(tenantSlug, cached);
    } on NetworkException {
      final cached = await _getCachedSession(tenantSlug);
      if (cached == null) rethrow;
      return await _applyPending(tenantSlug, cached);
    }
  }

  @override
  Future<OpnameSyncOutcome> recordCount(
    String tenantSlug, {
    required int itemId,
    required num physicalQty,
  }) async {
    if (physicalQty < 0 || physicalQty % 1 != 0) {
      throw const ServerException('Jumlah fisik harus bilangan bulat >= 0.');
    }
    final session = await _sessionForWrite(tenantSlug);
    if (session.isInReview) {
      throw const ServerException('Sesi opname sudah dikirim untuk review.');
    }
    if (session.isReviewPending) {
      throw const ServerException(
        'Submit review opname masih menunggu sinkronisasi.',
      );
    }
    final index = session.items.indexWhere((item) => item.id == itemId);
    if (index < 0) {
      throw const ServerException('Item tidak ditemukan dalam sesi aktif.');
    }
    final item = session.items[index];
    final updatedItems = [...session.items]..[index] =
        item.copyWith(physicalQty: physicalQty);
    final updatedSession = session.copyWith(items: updatedItems);
    await _cacheSession(tenantSlug, updatedSession);

    final outcome = await _enqueueAndSync(
      tenantSlug,
      session: updatedSession,
      items: [_itemPayload(item, physicalQty)],
    );
    await _cacheSession(
      tenantSlug,
      updatedSession.copyWith(
        isOfflinePending: !outcome.synced,
        syncError: outcome.errorMessage,
      ),
    );
    return outcome;
  }

  @override
  Future<OpnameSyncOutcome> submitReview(
    String tenantSlug, {
    required int sessionId,
  }) async {
    final session = await _sessionForWrite(tenantSlug);
    if (sessionId > 0 && session.id != sessionId) {
      throw const ServerException('ID sesi stock opname tidak valid.');
    }
    if (session.id <= 0 && session.sessionCode.isEmpty) {
      throw const ServerException('Kode sesi stock opname tidak valid.');
    }
    if (!session.allItemsCounted) {
      throw const ServerException('Hitung semua item sebelum submit review.');
    }
    if (session.isInReview) {
      return const OpnameSyncOutcome(synced: true);
    }

    final outcome = await _enqueueAndSync(
      tenantSlug,
      session: session,
      items: session.items
          .map((item) => _itemPayload(item, item.physicalQty!))
          .toList(),
      shouldSubmitReview: true,
    );
    await _cacheSession(
      tenantSlug,
      session.copyWith(
        status: outcome.synced ? 'REVIEW' : session.status,
        isOfflinePending: !outcome.synced,
        isReviewPending: !outcome.synced,
        syncError: outcome.errorMessage,
      ),
    );
    return outcome;
  }

  Future<StockOpnameSession> _sessionForWrite(String tenantSlug) async {
    final cached = await _getCachedSession(tenantSlug);
    if (cached != null) return _applyPending(tenantSlug, cached);
    final remote = await api.getActiveSession(tenantSlug);
    if (remote == null) {
      throw const ServerException('Sesi stock opname aktif tidak tersedia.');
    }
    await _cacheSession(tenantSlug, remote);
    return remote;
  }

  Future<OpnameSyncOutcome> _enqueueAndSync(
    String tenantSlug, {
    required StockOpnameSession session,
    required List<Map<String, dynamic>> items,
    bool shouldSubmitReview = false,
  }) async {
    final pendingRows = await OfflineDb.getPendingOpnameForSession(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      sessionCode: session.sessionCode,
    );
    final existingRow = pendingRows.isEmpty ? null : pendingRows.first;
    final localUuid =
        existingRow?['local_uuid']?.toString() ?? generateOpnameLocalId();
    final existingPayload = existingRow == null
        ? <String, dynamic>{}
        : decodeJsonMap(existingRow['payload_json'] as String);
    final existingItems = existingPayload['items'] as List? ?? const [];
    final mergedItems = <String, Map<String, dynamic>>{};
    for (final rawItem in existingItems) {
      final item = Map<String, dynamic>.from(rawItem as Map);
      mergedItems[_itemKey(item)] = item;
    }
    for (final item in items) {
      mergedItems[_itemKey(item)] = item;
    }
    final payload = <String, dynamic>{
      if (session.id > 0) 'session_id': session.id,
      'session_code': session.sessionCode,
      'local_uuid': localUuid,
      'transaction_uuid': localUuid,
      'should_submit_review':
          shouldSubmitReview || existingPayload['should_submit_review'] == true,
      'items': mergedItems.values.toList(),
    };
    final metadata = <String, dynamic>{
      'session_code': session.sessionCode,
      'warehouse_name': session.warehouse,
      'zone_name': session.zone,
      'operator_name': operatorName,
      'items': payload['items'],
    };
    if (existingRow == null) {
      await OfflineDb.enqueueOpname(
        localUuid: localUuid,
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
        sessionId: session.id > 0 ? session.id : null,
        sessionCode: session.sessionCode,
        payload: payload,
        metadata: metadata,
      );
    } else {
      await OfflineDb.saveOpnameProgress(
        localUuid: localUuid,
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
        payload: payload,
        metadata: metadata,
      );
    }

    if (authToken.isEmpty) {
      return const OpnameSyncOutcome(
        synced: false,
        errorMessage:
            'Sesi login tidak tersedia; sinkronisasi akan dicoba ulang.',
      );
    }
    if (!await SyncManager.instance.shouldSyncAutomatically()) {
      final automaticSyncEnabled = await OfflineDb.isAutomaticSyncEnabled();
      return OpnameSyncOutcome(
        synced: false,
        errorMessage: automaticSyncEnabled
            ? 'Hitungan tersimpan lokal dan menunggu koneksi untuk sinkronisasi otomatis.'
            : 'Hitungan tersimpan lokal dan menunggu sinkronisasi manual.',
      );
    }
    final result = await SyncManager.instance.syncOpnameQueue(
      dio: dio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: authToken,
      localUuid: localUuid,
    );
    if (result.syncedCount == 1 && result.failures.isEmpty) {
      return const OpnameSyncOutcome(synced: true);
    }
    return OpnameSyncOutcome(
      synced: false,
      errorMessage: result.failures.isEmpty
          ? 'Hitungan tersimpan dan menunggu sinkronisasi.'
          : result.failures.first.message,
    );
  }

  String _itemKey(Map<String, dynamic> item) =>
      item['item_id']?.toString() ??
      item['sku_id']?.toString() ??
      item['barcode']?.toString() ??
      '';

  Map<String, dynamic> _itemPayload(StockOpnameItem item, num quantity) => {
        'item_id': item.id,
        if (item.skuId != null) 'sku_id': item.skuId,
        if (item.barcode.isNotEmpty) 'barcode': item.barcode,
        if (item.locationId != null) 'location_id': item.locationId,
        if (item.targetRack.isNotEmpty) 'target_rack': item.targetRack,
        'physical_qty': quantity.toInt(),
      };

  Future<void> _cacheSession(
    String tenantSlug,
    StockOpnameSession session,
  ) =>
      OfflineDb.cacheOpnameSession(
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
        sessionCode: session.sessionCode,
        session: session.toJson(),
      );

  Future<StockOpnameSession?> _getCachedSession(String tenantSlug) async {
    final cached = await OfflineDb.getCachedOpnameSession(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
    );
    return cached == null ? null : StockOpnameSession.fromJson(cached);
  }

  Future<StockOpnameSession> _applyPending(
    String tenantSlug,
    StockOpnameSession session,
  ) async {
    final rows = await OfflineDb.getPendingOpnameForSession(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      sessionCode: session.sessionCode,
    );
    final pendingCounts = <int, num>{};
    var reviewPending = false;
    String? syncError;
    for (final row in rows) {
      final payload = decodeJsonMap(row['payload_json'] as String);
      for (final rawItem in payload['items'] as List? ?? const []) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        final id = int.tryParse(item['item_id']?.toString() ?? '');
        final quantity = num.tryParse(item['physical_qty']?.toString() ?? '');
        if (id != null && quantity != null) pendingCounts[id] = quantity;
      }
      reviewPending = reviewPending || payload['should_submit_review'] == true;
      syncError = row['error_message']?.toString() ?? syncError;
    }
    final mergedItems = session.items
        .map(
          (item) => pendingCounts.containsKey(item.id)
              ? item.copyWith(physicalQty: pendingCounts[item.id])
              : item,
        )
        .toList();
    return session.copyWith(
      items: mergedItems,
      isOfflinePending: rows.isNotEmpty,
      isReviewPending: reviewPending,
      syncError: syncError,
    );
  }
}

final stockOpnameDataSourceProvider = Provider<StockOpnameRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final auth = ref.watch(authProvider);
  final token = auth.token ?? '';
  return OfflineStockOpnameRepository(
    api: ApiStockOpnameRepository(dio),
    dio: dio,
    ownerKey: offlineOwnerKey(userId: auth.userId, token: token),
    authToken: token,
    operatorName: auth.userName ?? '',
  );
});

class StockOpnameNotifier
    extends StateNotifier<AsyncValue<StockOpnameSession?>> {
  StockOpnameNotifier(this._repository, this._tenantSlug)
      : super(const AsyncLoading()) {
    loadActiveSession();
  }

  final StockOpnameRepository _repository;
  final String? _tenantSlug;

  Future<void> loadActiveSession() async {
    final slug = _tenantSlug;
    if (slug == null || slug.isEmpty) {
      state = AsyncError(
        const ServerException('Tenant belum dipilih. Silakan login kembali.'),
        StackTrace.current,
      );
      return;
    }
    state = const AsyncLoading();
    try {
      state = AsyncData(await _repository.getActiveSession(slug));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> recordCount({
    required int itemId,
    required num physicalQty,
  }) async {
    final session = state.asData?.value;
    final slug = _tenantSlug;
    if (session == null || slug == null || slug.isEmpty) {
      throw const ServerException('Sesi stock opname aktif tidak tersedia.');
    }
    if (!session.items.any((item) => item.id == itemId)) {
      throw const ServerException('Item tidak ditemukan dalam sesi aktif.');
    }
    final outcome = await _repository.recordCount(
      slug,
      itemId: itemId,
      physicalQty: physicalQty,
    );
    state = AsyncData(
      session.copyWith(
        items: [
          for (final item in session.items)
            if (item.id == itemId)
              item.copyWith(physicalQty: physicalQty)
            else
              item,
        ],
        isOfflinePending: !outcome.synced,
        syncError: outcome.errorMessage,
      ),
    );
  }

  Future<void> submitReview() async {
    final session = state.asData?.value;
    final slug = _tenantSlug;
    if (session == null || slug == null || slug.isEmpty) {
      throw const ServerException('Sesi stock opname aktif tidak tersedia.');
    }
    if (session.id <= 0 && session.sessionCode.isEmpty) {
      throw const ServerException(
          'ID atau kode sesi stock opname tidak valid.');
    }
    final outcome = await _repository.submitReview(slug, sessionId: session.id);
    state = AsyncData(
      session.copyWith(
        status: outcome.synced ? 'REVIEW' : session.status,
        isOfflinePending: !outcome.synced,
        isReviewPending: !outcome.synced,
        syncError: outcome.errorMessage,
      ),
    );
  }
}

final stockOpnameRepositoryProvider =
    StateNotifierProvider<StockOpnameNotifier, AsyncValue<StockOpnameSession?>>(
  (ref) {
    final repository = ref.watch(stockOpnameDataSourceProvider);
    final tenantSlug = ref.watch(authProvider).tenantSlug;
    return StockOpnameNotifier(repository, tenantSlug);
  },
);
