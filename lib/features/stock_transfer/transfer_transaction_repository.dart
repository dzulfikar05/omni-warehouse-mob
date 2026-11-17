import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/offline/offline_db.dart';
import '../../core/offline/offline_identity.dart';
import '../../core/offline/sync_manager.dart';
import 'transfer_local_id.dart';
import 'transfer_transaction_model.dart';

class TransferTransactionListResult {
  const TransferTransactionListResult({
    required this.transactions,
    required this.stats,
  });

  final List<TransferTransaction> transactions;
  final TransferTransactionStats stats;
}

abstract class TransferTransactionRepository {
  Future<TransferMasterOptions> getOptions(String slug);
  Future<TransferTransactionListResult> getTransactions(
    String slug, {
    Map<String, dynamic> filters = const {},
  });
  Future<String?> createTransaction(
    String slug, {
    required List<Map<String, dynamic>> items,
    String? notes,
  });
  Future<void> updateTransaction(
    String slug,
    String code, {
    required List<Map<String, dynamic>> items,
    String? notes,
  });
  Future<void> cancelTransaction(String slug, String code);
}

class ApiTransferTransactionRepository
    implements TransferTransactionRepository {
  ApiTransferTransactionRepository(this._dio);

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

  List<dynamic> _asList(dynamic value, String field) {
    if (value is List) return value;
    if (value is Map && value['data'] is List) return value['data'] as List;
    if (value == null) return const [];
    throw ServerException('Format daftar $field dari server tidak valid.');
  }

  void _requireSuccess(Map<String, dynamic> envelope, String fallback) {
    if (envelope['success'] == false) {
      throw ServerException(envelope['message']?.toString() ?? fallback);
    }
  }

  @override
  Future<TransferMasterOptions> getOptions(String slug) async {
    try {
      final response = await _dio.get(ApiEndpoints.transferOptions(slug));
      final envelope = _asMap(response.data, 'Format opsi mutasi tidak valid.');
      _requireSuccess(envelope, 'Gagal memuat opsi mutasi stok.');
      final data = _asMap(envelope['data'], 'Master data mutasi tidak valid.');

      return TransferMasterOptions(
        warehouses: _asList(data['warehouses'], 'gudang')
            .whereType<Map>()
            .map(
              (item) =>
                  TransferWarehouse.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((warehouse) => warehouse.id > 0 && warehouse.name.isNotEmpty)
            .toList(),
        locations: _asList(data['locations'], 'lokasi')
            .whereType<Map>()
            .map(
              (item) =>
                  TransferLocation.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((location) => location.id > 0 && location.name.isNotEmpty)
            .toList(),
        skus: _asList(data['skus'], 'SKU')
            .whereType<Map>()
            .map(
              (item) => TransferSku.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((sku) => sku.id > 0 && sku.name.isNotEmpty)
            .toList(),
      );
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal memuat opsi gudang, lokasi, dan SKU.');
    }
  }

  @override
  Future<TransferTransactionListResult> getTransactions(
    String slug, {
    Map<String, dynamic> filters = const {},
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.transferList(slug),
        queryParameters: filters,
      );
      final envelope = _asMap(
        response.data,
        'Format daftar mutasi stok tidak valid.',
      );
      _requireSuccess(envelope, 'Gagal memuat daftar mutasi stok.');
      final rawData = envelope['data'];
      final data = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{};
      final rawTransactions = rawData is List
          ? rawData
          : data['transfers'] ??
              data['transactions'] ??
              data['transfer_logs'] ??
              data['logs'] ??
              data['stock_transfers'] ??
              data['data'];
      final transactions = _asList(
        rawTransactions,
        'transaksi mutasi stok',
      ).whereType<Map>().map((item) {
        return TransferTransaction.fromJson(Map<String, dynamic>.from(item));
      }).toList();
      final rawStats = data['summary'] ?? data['stats'];
      final summary = rawStats is Map
          ? Map<String, dynamic>.from(rawStats)
          : const <String, dynamic>{};

      return TransferTransactionListResult(
        transactions: transactions,
        stats: TransferTransactionStats.fromJson(
          summary,
          transactions: transactions,
        ),
      );
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal memuat daftar mutasi stok.');
    }
  }

  @override
  Future<String?> createTransaction(
    String slug, {
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.transferCreate(slug),
        data: {
          'items': items,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      final envelope = _asMap(
        response.data,
        'Format respons pembuatan mutasi tidak valid.',
      );
      _requireSuccess(envelope, 'Gagal membuat mutasi stok.');
      final data = envelope['data'] is Map
          ? Map<String, dynamic>.from(envelope['data'] as Map)
          : const <String, dynamic>{};
      return (data['transfer_code'] ?? data['code'])?.toString();
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal membuat mutasi stok.');
    }
  }

  @override
  Future<void> updateTransaction(
    String slug,
    String code, {
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      final payload = <String, dynamic>{'items': items};
      if (notes != null) payload['notes'] = notes;
      final response = await _dio.put(
        ApiEndpoints.transferUpdate(slug, Uri.encodeComponent(code)),
        data: payload,
      );
      final envelope = _asMap(
        response.data,
        'Format respons perubahan mutasi tidak valid.',
      );
      _requireSuccess(envelope, 'Gagal memperbarui mutasi stok.');
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal memperbarui mutasi stok.');
    }
  }

  @override
  Future<void> cancelTransaction(String slug, String code) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.transferCancel(slug, Uri.encodeComponent(code)),
      );
      final envelope = _asMap(
        response.data,
        'Format respons pembatalan mutasi tidak valid.',
      );
      _requireSuccess(envelope, 'Gagal membatalkan mutasi stok.');
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal membatalkan mutasi stok.');
    }
  }
}

class OfflineTransferTransactionRepository
    implements TransferTransactionRepository {
  OfflineTransferTransactionRepository({
    required this.api,
    required this.dio,
    required this.ownerKey,
    required this.authToken,
    required this.operatorName,
  });

  final ApiTransferTransactionRepository api;
  final Dio dio;
  final String ownerKey;
  final String authToken;
  final String operatorName;

  @override
  Future<TransferMasterOptions> getOptions(String slug) async {
    try {
      final options = await api.getOptions(slug);
      await OfflineDb.cacheTransferOptions(
        tenantSlug: slug,
        ownerKey: ownerKey,
        options: _optionsToJson(options),
      );
      return options;
    } on NetworkException {
      final cached = await OfflineDb.getCachedTransferOptions(
        tenantSlug: slug,
        ownerKey: ownerKey,
      );
      if (cached == null) rethrow;
      return _optionsFromJson(cached);
    }
  }

  @override
  Future<TransferTransactionListResult> getTransactions(
    String slug, {
    Map<String, dynamic> filters = const {},
  }) async {
    try {
      final result = await api.getTransactions(slug, filters: filters);
      final local = _filterLocal(await _localTransactions(slug), filters);
      final serverCodes = result.transactions.map((item) => item.code).toSet();
      final transactions = [
        ...result.transactions,
        ...local.where((item) => !serverCodes.contains(item.code)),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return TransferTransactionListResult(
        transactions: transactions,
        stats: TransferTransactionStats.fromJson(
          const {},
          transactions: transactions,
        ),
      );
    } on NetworkException {
      final local = _filterLocal(await _localTransactions(slug), filters);
      if (local.isEmpty) rethrow;
      return TransferTransactionListResult(
        transactions: local,
        stats: TransferTransactionStats.fromJson(
          const {},
          transactions: local,
        ),
      );
    }
  }

  @override
  Future<String?> createTransaction(
    String slug, {
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final localId = generateTransferLocalId();
    final payload = <String, dynamic>{
      'transfer_code': localId,
      'local_uuid': localId,
      'transaction_uuid': localId,
      'items': items,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    await OfflineDb.enqueueTransfer(
      localUuid: localId,
      tenantSlug: slug,
      ownerKey: ownerKey,
      payload: payload,
      metadata: await _metadataForPayload(slug, payload),
    );
    await _trySync(slug, localId);
    return localId;
  }

  @override
  Future<void> updateTransaction(
    String slug,
    String code, {
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final row = await OfflineDb.getTransferQueueItem(
      localUuid: code,
      tenantSlug: slug,
      ownerKey: ownerKey,
    );
    if (row == null) {
      await api.updateTransaction(
        slug,
        code,
        items: items,
        notes: notes,
      );
      return;
    }
    final status = row['status'] as String;
    if (status == 'success') {
      await api.updateTransaction(
        slug,
        row['server_transfer_code']?.toString() ?? code,
        items: items,
        notes: notes,
      );
      return;
    }
    if (status == 'cancelled') {
      throw StateError(
        'Transaksi transfer lokal yang dibatalkan tidak dapat diubah.',
      );
    }
    final payload = decodeJsonMap(row['payload_json'] as String)
      ..['items'] = items;
    if (notes == null || notes.isEmpty) {
      payload.remove('notes');
    } else {
      payload['notes'] = notes;
    }
    await OfflineDb.saveTransferProgress(
      localUuid: code,
      tenantSlug: slug,
      ownerKey: ownerKey,
      payload: payload,
      metadata: await _metadataForPayload(slug, payload),
    );
    await _trySync(slug, code);
  }

  @override
  Future<void> cancelTransaction(String slug, String code) async {
    final row = await OfflineDb.getTransferQueueItem(
      localUuid: code,
      tenantSlug: slug,
      ownerKey: ownerKey,
    );
    if (row == null) {
      await api.cancelTransaction(slug, code);
      return;
    }
    final status = row['status'] as String;
    if (status == 'cancelled') return;
    if (status == 'success') {
      await api.cancelTransaction(
        slug,
        row['server_transfer_code']?.toString() ?? code,
      );
      return;
    }
    await OfflineDb.cancelTransferQueueItem(
      localUuid: code,
      tenantSlug: slug,
      ownerKey: ownerKey,
    );
  }

  Future<void> _trySync(String slug, String localId) async {
    if (authToken.isEmpty) return;
    await SyncManager.instance.syncTransferQueue(
      dio: dio,
      tenantSlug: slug,
      ownerKey: ownerKey,
      authToken: authToken,
      localUuid: localId,
    );
  }

  Future<List<TransferTransaction>> _localTransactions(String slug) async {
    final rows = await OfflineDb.getTransferManifests(
      tenantSlug: slug,
      ownerKey: ownerKey,
    );
    return rows.map(_localTransaction).toList();
  }

  TransferTransaction _localTransaction(Map<String, Object?> row) {
    final payload = decodeJsonMap(row['payload_json'] as String);
    final metadata = decodeJsonMap(row['metadata_json'] as String);
    final rawPayloadItems = payload['items'] as List? ?? const [];
    final rawMetadataItems = metadata['items'] as List? ?? const [];
    final items = <Map<String, dynamic>>[];
    for (var index = 0; index < rawPayloadItems.length; index++) {
      final payloadItem = Map<String, dynamic>.from(
        rawPayloadItems[index] as Map,
      );
      final metadataItem = index < rawMetadataItems.length
          ? Map<String, dynamic>.from(rawMetadataItems[index] as Map)
          : <String, dynamic>{};
      items.add({...metadataItem, ...payloadItem});
    }
    final status = row['status'] as String;
    return TransferTransaction.fromJson({
      'transfer_code': row['local_uuid'],
      'status': status == 'error' ? 'error' : status,
      'created_at': row['created_at'],
      'created_by_name': operatorName,
      'notes': payload['notes'],
      'items': items,
      'is_offline_pending':
          status == 'pending' || status == 'error' || status == 'syncing',
      'sync_error': row['error_message'],
    });
  }

  List<TransferTransaction> _filterLocal(
    List<TransferTransaction> transactions,
    Map<String, dynamic> filters,
  ) {
    final search = filters['search']?.toString().toLowerCase();
    final status = filters['status']?.toString().toLowerCase();
    final dateFrom = filters['date_from']?.toString();
    final dateTo = filters['date_to']?.toString();
    return transactions.where((transaction) {
      if (status != null && transaction.status.toLowerCase() != status) {
        return false;
      }
      if (dateFrom != null && transaction.createdAt.compareTo(dateFrom) < 0) {
        return false;
      }
      if (dateTo != null &&
          (transaction.createdAt.length < 10
                      ? transaction.createdAt
                      : transaction.createdAt.substring(0, 10))
                  .compareTo(dateTo) >
              0) {
        return false;
      }
      if (search == null || search.isEmpty) return true;
      return transaction.code.toLowerCase().contains(search) ||
          (transaction.notes?.toLowerCase().contains(search) ?? false) ||
          transaction.items.any(
            (item) =>
                item.sku.toLowerCase().contains(search) ||
                item.productName.toLowerCase().contains(search),
          );
    }).toList();
  }

  Future<Map<String, dynamic>> _metadataForPayload(
    String slug,
    Map<String, dynamic> payload,
  ) async {
    final cached = await OfflineDb.getCachedTransferOptions(
      tenantSlug: slug,
      ownerKey: ownerKey,
    );
    final skuById = {
      for (final item in _asList(cached?['skus']))
        int.tryParse(item['id']?.toString() ?? '') ?? -1: item,
    };
    final locationById = {
      for (final item in _asList(cached?['locations']))
        int.tryParse(item['id']?.toString() ?? '') ?? -1: item,
    };
    final items = (payload['items'] as List? ?? const []).map((rawItem) {
      final item = Map<String, dynamic>.from(rawItem as Map);
      final sku = skuById[int.tryParse(item['sku_id'].toString()) ?? -1];
      final from =
          locationById[int.tryParse(item['from_location_id'].toString()) ?? -1];
      final to =
          locationById[int.tryParse(item['to_location_id'].toString()) ?? -1];
      return {
        ...item,
        if (sku != null) ...{
          'sku_code': sku['sku'],
          'product_name': sku['name'],
          'unit': sku['unit'] ?? 'pcs',
        },
        if (from != null) 'from_location_name': from['rack_code'],
        if (to != null) 'to_location_name': to['rack_code'],
      };
    }).toList();
    return <String, dynamic>{
      'operator_name': operatorName,
      'items': items,
    };
  }

  Map<String, dynamic> _optionsToJson(TransferMasterOptions options) => {
        'warehouses': options.warehouses
            .map((item) => {'id': item.id, 'name': item.name})
            .toList(),
        'locations': options.locations
            .map(
              (item) => {
                'id': item.id,
                'rack_code': item.name,
                'warehouse_id': item.warehouseId,
                'warehouse_name': item.warehouseName,
                'stock_quantity': item.stockQuantity,
              },
            )
            .toList(),
        'skus': options.skus
            .map(
              (item) => {
                'id': item.id,
                'sku': item.code,
                'name': item.name,
                'barcode': item.barcode,
                'available_stock': item.availableStock,
                'unit': item.unit,
              },
            )
            .toList(),
      };

  TransferMasterOptions _optionsFromJson(Map<String, dynamic> cached) =>
      TransferMasterOptions(
        warehouses: _asList(cached['warehouses'])
            .map((item) => TransferWarehouse.fromJson(item))
            .toList(),
        locations: _asList(cached['locations'])
            .map((item) => TransferLocation.fromJson(item))
            .toList(),
        skus: _asList(cached['skus'])
            .map((item) => TransferSku.fromJson(item))
            .toList(),
      );

  List<Map<String, dynamic>> _asList(dynamic value) => value is List
      ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
      : const [];
}

final transferTransactionRepositoryProvider =
    Provider<TransferTransactionRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final auth = ref.watch(authProvider);
  final token = auth.token ?? '';
  return OfflineTransferTransactionRepository(
    api: ApiTransferTransactionRepository(dio),
    dio: dio,
    ownerKey: offlineOwnerKey(userId: auth.userId, token: token),
    authToken: token,
    operatorName: auth.userName ?? '',
  );
});
