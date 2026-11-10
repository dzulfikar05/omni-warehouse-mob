import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_exception.dart';
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

  AppException _mapFailure(DioException error, String fallback) =>
      error.error is AppException
          ? error.error as AppException
          : ServerException(fallback);

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

final transferTransactionRepositoryProvider =
    Provider<TransferTransactionRepository>((ref) {
  return ApiTransferTransactionRepository(ref.watch(dioProvider));
});
