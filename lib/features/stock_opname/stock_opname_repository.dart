import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/offline/offline_db.dart';
import '../../core/offline/offline_identity.dart';
import 'stock_opname_local_id.dart';
import 'stock_opname_model.dart';

class OpnameSyncOutcome {
  const OpnameSyncOutcome({required this.synced, this.errorMessage});

  final bool synced;
  final String? errorMessage;
}

abstract class StockOpnameRepository {
  Future<StockOpnameSessionPage> getSessions(String tenantSlug, {int page});
  Future<StockOpnameSession> getSessionDetail(
    String tenantSlug, {
    required int sessionId,
    String? sessionCode,
  });
  Future<StockOpnameSession?> getActiveSession(
    String tenantSlug, {
    int? sessionId,
  });
  Future<OpnameSyncOutcome> recordCount(
    String tenantSlug, {
    required int itemId,
    required num physicalQty,
    int? sessionId,
    String? sessionCode,
    int? locationId,
    String? targetRack,
  });
  Future<OpnameSyncOutcome> submitReview(
    String tenantSlug, {
    int? sessionId,
    String? sessionCode,
  });
}

class ApiStockOpnameRepository implements StockOpnameRepository {
  ApiStockOpnameRepository(this._dio, {this.ownerKey});

  final Dio _dio;
  final String? ownerKey;

  AppException _mapFailure(DioException error, String fallback) {
    if (error.response?.statusCode == 422 && error.response?.data is Map) {
      final body = Map<String, dynamic>.from(error.response!.data as Map);
      final rawErrors = body['errors'];
      final errors = <String, List<String>>{};
      if (rawErrors is Map) {
        rawErrors.forEach((key, value) {
          if (value is List) {
            errors[key.toString()] = value
                .map((item) => item.toString())
                .toList();
          }
        });
      }
      final message = body['message']?.toString() ?? 'Validasi gagal.';
      final details = errors.values.expand((messages) => messages).join(' ');
      return ValidationException(
        details.isEmpty ? message : '$message $details',
        errors: errors,
      );
    }
    if (error.error is AppException) return error.error as AppException;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return NetworkException(error.message ?? fallback);
    }
    final body = error.response?.data;
    final message = body is Map ? body['message']?.toString() : null;
    if (error.response?.statusCode == 401) {
      return UnauthorizedException(
        message ?? 'Sesi login berakhir. Silakan login kembali.',
      );
    }
    return ServerException(message ?? fallback);
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
  Future<StockOpnameSessionPage> getSessions(
    String tenantSlug, {
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.opnameList(tenantSlug),
        queryParameters: {'page': page},
      );
      final result = _parseSessionPage(response.data, page);
      if (ownerKey != null) {
        await OfflineDb.cacheListSnapshot(
          tenantSlug: tenantSlug,
          ownerKey: ownerKey!,
          feature: 'opname',
          filters: {'page': page},
          payload: response.data,
        );
      }
      return result;
    } on DioException catch (error) {
      final failure =
          _mapFailure(error, 'Gagal memuat daftar sesi stock opname.');
      if (failure is NetworkException && ownerKey != null) {
        final cached = await OfflineDb.getCachedListSnapshot(
          tenantSlug: tenantSlug,
          ownerKey: ownerKey!,
          feature: 'opname',
          filters: {'page': page},
        );
        if (cached != null) {
          return _parseSessionPage(cached, page, isOfflineSnapshot: true);
        }
      }
      throw failure;
    }
  }

  StockOpnameSessionPage _parseSessionPage(
    dynamic responseData,
    int page, {
    bool isOfflineSnapshot = false,
  }) {
    final envelope = _asMap(
      responseData,
      'Format daftar sesi stock opname tidak valid.',
    );
    _requireSuccess(envelope, 'Gagal memuat daftar sesi stock opname.');
    final pagination = _asMap(
      envelope['data'],
      'Data daftar sesi stock opname tidak valid.',
    );
    final rawSessions = pagination['data'];
    if (rawSessions is! List) {
      throw const ServerException(
        'Format pagination daftar sesi stock opname tidak valid.',
      );
    }
    return StockOpnameSessionPage(
      sessions: rawSessions
          .whereType<Map>()
          .map(
            (session) => StockOpnameSessionSummary.fromJson(
              Map<String, dynamic>.from(session),
            ),
          )
          .toList(),
      currentPage: _asPageNumber(pagination['current_page'], page),
      lastPage: _asPageNumber(pagination['last_page'], page),
      total: _asPageNumber(pagination['total'], rawSessions.length),
      isOfflineSnapshot: isOfflineSnapshot,
    );
  }

  @override
  Future<StockOpnameSession> getSessionDetail(
    String tenantSlug, {
    required int sessionId,
    String? sessionCode,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.opnameDetail(tenantSlug, sessionId),
      );
      final envelope = _asMap(
        response.data,
        'Format detail sesi stock opname tidak valid.',
      );
      _requireSuccess(envelope, 'Gagal memuat detail sesi stock opname.');
      final data = _asMap(
        envelope['data'],
        'Data detail sesi stock opname tidak valid.',
      );
      final rawSession = data['session'];
      if (rawSession is! Map) {
        throw const ServerException('Detail sesi stock opname tidak tersedia.');
      }
      final sessionData = Map<String, dynamic>.from(rawSession);
      sessionData['items'] = data['items'];
      return StockOpnameSession.fromJson(sessionData);
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal memuat detail sesi stock opname.');
    }
  }

  @override
  Future<StockOpnameSession?> getActiveSession(
    String tenantSlug, {
    int? sessionId,
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.opnameActiveSession(tenantSlug),
        queryParameters: sessionId == null || sessionId <= 0
            ? null
            : {'session_id': sessionId},
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
      final sessionData = rawSession is Map
          ? Map<String, dynamic>.from(rawSession)
          : data;
      if (rawSession is Map) sessionData['items'] = data['items'];
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

  int _asPageNumber(dynamic value, int fallback) =>
      int.tryParse(value?.toString() ?? '') ?? fallback;

  @override
  Future<OpnameSyncOutcome> recordCount(
    String tenantSlug, {
    required int itemId,
    required num physicalQty,
    int? sessionId,
    String? sessionCode,
    int? locationId,
    String? targetRack,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.opnameRecordCount(tenantSlug),
        data: {
          'item_id': itemId,
          'physical_qty': physicalQty,
          ...?(locationId == null ? null : {'location_id': locationId}),
          ...?(targetRack?.isNotEmpty == true
              ? {'target_rack': targetRack}
              : null),
        },
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
    int? sessionId,
    String? sessionCode,
  }) async {
    try {
      final identity = <String, dynamic>{
        if (sessionId != null && sessionId > 0) 'session_id': sessionId,
        if ((sessionId == null || sessionId <= 0) &&
            sessionCode != null &&
            sessionCode.isNotEmpty)
          'session_code': sessionCode,
      };
      if (identity.isEmpty) {
        throw const ServerException(
          'ID atau kode sesi stock opname tidak valid.',
        );
      }
      final response = await _dio.post(
        ApiEndpoints.opnameSubmitReview(tenantSlug),
        data: identity,
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
  Future<StockOpnameSessionPage> getSessions(
    String tenantSlug, {
    int page = 1,
  }) async {
    try {
      final result = await api.getSessions(tenantSlug, page: page);
      if (!result.isOfflineSnapshot || page != 1) return result;

      final cachedSessions = await OfflineDb.getCachedOpnameSessions(
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
      );
      if (cachedSessions.isEmpty) return result;
      final cachedByCode = <String, StockOpnameSession>{};
      for (final cached in cachedSessions) {
        final session = StockOpnameSession.fromJson(cached);
        cachedByCode[session.sessionCode] = session;
      }
      final summaries = <StockOpnameSessionSummary>[];
      for (final summary in result.sessions) {
        final cached = cachedByCode[summary.sessionCode];
        if (cached == null) {
          summaries.add(summary);
          continue;
        }
        final session = await _applyPending(tenantSlug, cached);
        summaries.add(
          StockOpnameSessionSummary(
            id: summary.id,
            sessionCode: summary.sessionCode,
            status: session.status,
            warehouseName: summary.warehouseName,
            warehouseCode: summary.warehouseCode,
            locationId: summary.locationId,
            locationLabel: summary.locationLabel,
            auditorName: summary.auditorName,
            createdAt: summary.createdAt,
            totalItems: summary.totalItems,
            countedItems: session.countedItems,
          ),
        );
      }
      return StockOpnameSessionPage(
        sessions: summaries,
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        total: result.total,
        isOfflineSnapshot: true,
      );
    } on NetworkException {
      if (page != 1) rethrow;
      final cachedSessions = await OfflineDb.getCachedOpnameSessions(
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
      );
      if (cachedSessions.isEmpty) rethrow;
      final sessions = <StockOpnameSessionSummary>[];
      for (final cached in cachedSessions) {
        final session = await _applyPending(
          tenantSlug,
          StockOpnameSession.fromJson(cached),
        );
        sessions.add(
          StockOpnameSessionSummary(
            id: session.id,
            sessionCode: session.sessionCode,
            status: session.status,
            warehouseName: session.warehouse,
            warehouseCode: '',
            locationId: session.locationId,
            locationLabel: session.locationLabel.isNotEmpty
                ? session.locationLabel
                : 'Semua lokasi',
            auditorName: '',
            createdAt: '',
            totalItems: session.items.length,
            countedItems: session.countedItems,
          ),
        );
      }
      return StockOpnameSessionPage(
        sessions: sessions,
        currentPage: 1,
        lastPage: 1,
        total: sessions.length,
      );
    }
  }

  @override
  Future<StockOpnameSession> getSessionDetail(
    String tenantSlug, {
    required int sessionId,
    String? sessionCode,
  }) async {
    try {
      final session = await api.getSessionDetail(
        tenantSlug,
        sessionId: sessionId,
        sessionCode: sessionCode,
      );
      await _cacheSession(tenantSlug, session);
      return await _applyPending(tenantSlug, session);
    } on NetworkException {
      final cached = await _getCachedSession(
        tenantSlug,
        sessionCode: sessionCode,
      );
      if (cached == null || cached.id != sessionId) rethrow;
      return await _applyPending(tenantSlug, cached);
    }
  }

  @override
  Future<StockOpnameSession?> getActiveSession(
    String tenantSlug, {
    int? sessionId,
  }) async {
    try {
      final remote = await api.getActiveSession(
        tenantSlug,
        sessionId: sessionId,
      );
      if (remote != null) {
        await _cacheSession(tenantSlug, remote);
        return await _applyPending(tenantSlug, remote);
      }
      return null;
    } on NetworkException {
      final cached = await _getCachedSession(tenantSlug);
      if (cached == null) rethrow;
      if (sessionId != null && cached.id != sessionId) rethrow;
      return await _applyPending(tenantSlug, cached);
    }
  }

  @override
  Future<OpnameSyncOutcome> recordCount(
    String tenantSlug, {
    required int itemId,
    required num physicalQty,
    int? sessionId,
    String? sessionCode,
    int? locationId,
    String? targetRack,
  }) async {
    if (physicalQty < 0 || physicalQty % 1 != 0) {
      throw const ServerException('Jumlah fisik harus bilangan bulat >= 0.');
    }
    final session = await _sessionForWrite(
      tenantSlug,
      sessionId: sessionId,
      sessionCode: sessionCode,
    );
    _requireWritable(session);
    final index = session.items.indexWhere((item) => item.id == itemId);
    if (index < 0) {
      throw const ServerException('Item tidak ditemukan dalam sesi aktif.');
    }
    final item = session.items[index];
    final scopedItem = _scopedItem(
      session,
      item,
      locationId: locationId,
      targetRack: targetRack,
    );
    final updatedItems = [...session.items]
      ..[index] = item.copyWith(physicalQty: physicalQty);
    final updatedSession = session.copyWith(items: updatedItems);
    await _cacheSession(tenantSlug, updatedSession);

    late final OpnameSyncOutcome outcome;
    try {
      await _flushPendingOpname(tenantSlug, session);
      outcome = await api.recordCount(
        tenantSlug,
        itemId: scopedItem.id,
        physicalQty: physicalQty,
        sessionId: session.id > 0 ? session.id : null,
        sessionCode: session.sessionCode,
        locationId: scopedItem.locationId,
        targetRack: scopedItem.targetRack,
      );
    } on NetworkException catch (error) {
      outcome = await _enqueueOffline(
        tenantSlug,
        session: updatedSession,
        items: [_itemPayload(scopedItem, physicalQty)],
        errorMessage: error.message,
      );
    }
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
    int? sessionId,
    String? sessionCode,
  }) async {
    final session = await _sessionForWrite(
      tenantSlug,
      sessionId: sessionId,
      sessionCode: sessionCode,
    );
    if (sessionId != null && sessionId > 0 && session.id != sessionId) {
      throw const ServerException('ID sesi stock opname tidak valid.');
    }
    if (sessionCode != null &&
        sessionCode.isNotEmpty &&
        session.sessionCode != sessionCode) {
      throw const ServerException('Kode sesi stock opname tidak valid.');
    }
    if (session.id <= 0 && session.sessionCode.isEmpty) {
      throw const ServerException('Kode sesi stock opname tidak valid.');
    }
    if (session.isClosedOrAdjusted) {
      throw const ServerException(
        'Sesi stock opname yang sudah ditutup atau disesuaikan tidak dapat dikirim.',
      );
    }
    if (!session.allItemsCounted) {
      throw const ServerException('Hitung semua item sebelum submit review.');
    }
    if (session.isInReview) {
      return const OpnameSyncOutcome(synced: true);
    }

    late final OpnameSyncOutcome outcome;
    try {
      await _flushPendingOpname(tenantSlug, session);
      outcome = await api.submitReview(
        tenantSlug,
        sessionId: session.id > 0 ? session.id : null,
        sessionCode: session.sessionCode,
      );
    } on NetworkException catch (error) {
      outcome = await _enqueueOffline(
        tenantSlug,
        session: session,
        items: session.items
            .map(
              (item) =>
                  _itemPayload(_scopedItem(session, item), item.physicalQty!),
            )
            .toList(),
        shouldSubmitReview: true,
        errorMessage: error.message,
      );
    }
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

  Future<StockOpnameSession> _sessionForWrite(
    String tenantSlug, {
    int? sessionId,
    String? sessionCode,
  }) async {
    final cached = await _getCachedSession(
      tenantSlug,
      sessionCode: sessionCode,
    );
    try {
      final remote = sessionId != null && sessionId > 0
          ? await api.getSessionDetail(
              tenantSlug,
              sessionId: sessionId,
              sessionCode: sessionCode,
            )
          : await api.getActiveSession(tenantSlug);
      if (remote == null) {
        throw const ServerException('Sesi stock opname aktif tidak tersedia.');
      }
      if (sessionCode != null &&
          sessionCode.isNotEmpty &&
          remote.sessionCode != sessionCode) {
        throw const ServerException(
          'Sesi stock opname aktif berbeda dari sesi yang dipilih.',
        );
      }
      await _cacheSession(tenantSlug, remote);
      return await _applyPending(tenantSlug, remote);
    } on NetworkException {
      if (cached == null) rethrow;
      return _applyPending(tenantSlug, cached);
    }
  }

  void _requireWritable(StockOpnameSession session) {
    if (!session.canCount) {
      throw const ServerException(
        'Sesi stock opname sudah ditutup, disesuaikan, atau dikirim untuk review.',
      );
    }
    if (session.isReviewPending) {
      throw const ServerException(
        'Sesi sudah menunggu submit review. Kirim ulang review untuk melanjutkan.',
      );
    }
  }

  StockOpnameItem _scopedItem(
    StockOpnameSession session,
    StockOpnameItem item, {
    int? locationId,
    String? targetRack,
  }) {
    if (session.locationId != null &&
        ((locationId != null && locationId != session.locationId) ||
            (item.locationId != null &&
                item.locationId != session.locationId))) {
      throw const ServerException(
        'Lokasi item berada di luar lingkup rak sesi stock opname.',
      );
    }
    final scoped = item.copyWith(
      locationId: session.locationId ?? locationId ?? item.locationId,
      targetRack: targetRack ?? item.targetRack,
    );
    _requireCountLocation(session, scoped);
    return scoped;
  }

  void _requireCountLocation(StockOpnameSession session, StockOpnameItem item) {
    if (session.locationId != null && item.locationId != session.locationId) {
      throw const ServerException(
        'Hitungan harus menggunakan lokasi yang terikat pada sesi.',
      );
    }
    if (session.locationId == null &&
        (item.locationId == null || item.targetRack.trim().isEmpty)) {
      throw const ServerException(
        'Sesi Semua lokasi memerlukan lokasi dan rak untuk setiap hitungan.',
      );
    }
  }

  Future<void> _flushPendingOpname(
    String tenantSlug,
    StockOpnameSession session,
  ) async {
    final rows = await OfflineDb.getPendingOpnameForSession(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      sessionCode: session.sessionCode,
    );
    for (final row in rows) {
      final payload = decodeJsonMap(row['payload_json'] as String);
      if (payload['counts_synced'] != true) {
        for (final rawItem in payload['items'] as List? ?? const []) {
          final item = Map<String, dynamic>.from(rawItem as Map);
          final itemId = int.tryParse(item['item_id']?.toString() ?? '');
          final physicalQty = num.tryParse(
            item['physical_qty']?.toString() ?? '',
          );
          if (itemId == null || physicalQty == null) {
            throw const ServerException(
              'Hitungan lokal tidak valid dan tidak dapat dikirim.',
            );
          }
          await api.recordCount(
            tenantSlug,
            itemId: itemId,
            physicalQty: physicalQty,
            locationId: int.tryParse(item['location_id']?.toString() ?? ''),
            targetRack: item['target_rack']?.toString(),
          );
        }
      }
      if (payload['should_submit_review'] == true) {
        await api.submitReview(
          tenantSlug,
          sessionId: int.tryParse(payload['session_id']?.toString() ?? ''),
          sessionCode: payload['session_code']?.toString(),
        );
      }
      await OfflineDb.deleteOpnameQueueItem(
        localUuid: row['local_uuid'] as String,
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
      );
    }
  }

  Future<OpnameSyncOutcome> _enqueueOffline(
    String tenantSlug, {
    required StockOpnameSession session,
    required List<Map<String, dynamic>> items,
    bool shouldSubmitReview = false,
    required String errorMessage,
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
      'should_submit_review':
          shouldSubmitReview || existingPayload['should_submit_review'] == true,
      'counts_synced': existingPayload['counts_synced'] == true,
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

    return OpnameSyncOutcome(
      synced: false,
      errorMessage: errorMessage,
    );
  }

  String _itemKey(Map<String, dynamic> item) =>
      '${item['item_id'] ?? item['sku_id'] ?? item['barcode'] ?? ''}'
      '|${item['location_id'] ?? ''}|${item['target_rack'] ?? ''}';

  Map<String, dynamic> _itemPayload(StockOpnameItem item, num quantity) => {
    'item_id': item.id,
    if (item.locationId != null) 'location_id': item.locationId,
    if (item.targetRack.isNotEmpty) 'target_rack': item.targetRack,
    'physical_qty': quantity.toInt(),
  };

  Future<void> _cacheSession(String tenantSlug, StockOpnameSession session) =>
      OfflineDb.cacheOpnameSession(
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
        sessionCode: session.sessionCode,
        session: session.toJson(),
      );

  Future<StockOpnameSession?> _getCachedSession(
    String tenantSlug, {
    String? sessionCode,
  }) async {
    final cached = await OfflineDb.getCachedOpnameSession(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      sessionCode: sessionCode,
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
    api: ApiStockOpnameRepository(
      dio,
      ownerKey: offlineOwnerKey(userId: auth.userId, token: token),
    ),
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
  int _loadRequest = 0;

  Future<void> loadActiveSession({int? sessionId}) async {
    final request = ++_loadRequest;
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
      final session = await _repository.getActiveSession(
        slug,
        sessionId: sessionId,
      );
      if (request == _loadRequest) state = AsyncData(session);
    } catch (error, stackTrace) {
      if (request == _loadRequest) state = AsyncError(error, stackTrace);
    }
  }

  Future<void> loadSessionDetail({
    required int sessionId,
    String? sessionCode,
  }) async {
    final request = ++_loadRequest;
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
      final session = await _repository.getSessionDetail(
        slug,
        sessionId: sessionId,
        sessionCode: sessionCode,
      );
      if (request == _loadRequest) state = AsyncData(session);
    } catch (error, stackTrace) {
      if (request == _loadRequest) state = AsyncError(error, stackTrace);
    }
  }

  Future<void> recordCount({
    required int itemId,
    required num physicalQty,
    int? locationId,
    String? targetRack,
  }) async {
    final session = state.asData?.value;
    final slug = _tenantSlug;
    if (session == null || slug == null || slug.isEmpty) {
      throw const ServerException('Sesi stock opname aktif tidak tersedia.');
    }
    if (!session.canCount) {
      throw const ServerException(
        'Sesi stock opname sudah ditutup, disesuaikan, atau dikirim untuk review.',
      );
    }
    if (!session.items.any((item) => item.id == itemId)) {
      throw const ServerException('Item tidak ditemukan dalam sesi aktif.');
    }
    final outcome = await _repository.recordCount(
      slug,
      itemId: itemId,
      physicalQty: physicalQty,
      sessionId: session.id,
      sessionCode: session.sessionCode,
      locationId: locationId,
      targetRack: targetRack,
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
        'ID atau kode sesi stock opname tidak valid.',
      );
    }
    if (session.isClosedOrAdjusted) {
      throw const ServerException(
        'Sesi stock opname yang sudah ditutup atau disesuaikan tidak dapat dikirim.',
      );
    }
    final outcome = await _repository.submitReview(
      slug,
      sessionId: session.id > 0 ? session.id : null,
      sessionCode: session.sessionCode,
    );
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

class StockOpnameSessionListNotifier
    extends StateNotifier<AsyncValue<StockOpnameSessionPage>> {
  StockOpnameSessionListNotifier(this._repository, this._tenantSlug)
    : super(const AsyncLoading()) {
    loadFirstPage();
  }

  final StockOpnameRepository _repository;
  final String? _tenantSlug;
  bool isLoadingMore = false;
  String? loadMoreError;

  Future<void> loadFirstPage() async {
    final slug = _tenantSlug;
    if (slug == null || slug.isEmpty) {
      state = AsyncError(
        const ServerException('Tenant belum dipilih. Silakan login kembali.'),
        StackTrace.current,
      );
      return;
    }
    final previousPage = state.asData?.value;
    if (previousPage == null) state = const AsyncLoading();
    loadMoreError = null;
    try {
      state = AsyncData(await _repository.getSessions(slug));
    } catch (error, stackTrace) {
      if (previousPage == null) {
        state = AsyncError(error, stackTrace);
      } else {
        loadMoreError = error.toString();
        state = AsyncData(previousPage);
      }
    }
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    final slug = _tenantSlug;
    if (current == null || slug == null || isLoadingMore || !current.hasMore) {
      return;
    }
    isLoadingMore = true;
    loadMoreError = null;
    try {
      final next = await _repository.getSessions(
        slug,
        page: current.currentPage + 1,
      );
      final seenIds = current.sessions.map((session) => session.id).toSet();
      state = AsyncData(
        StockOpnameSessionPage(
          sessions: [
            ...current.sessions,
            ...next.sessions.where((session) => !seenIds.contains(session.id)),
          ],
          currentPage: next.currentPage,
          lastPage: next.lastPage,
          total: next.total,
        ),
      );
    } catch (error) {
      loadMoreError = error.toString();
    } finally {
      isLoadingMore = false;
    }
  }
}

final stockOpnameSessionListProvider =
    StateNotifierProvider<
      StockOpnameSessionListNotifier,
      AsyncValue<StockOpnameSessionPage>
    >((ref) {
      final repository = ref.watch(stockOpnameDataSourceProvider);
      final tenantSlug = ref.watch(authProvider).tenantSlug;
      return StockOpnameSessionListNotifier(repository, tenantSlug);
    });
