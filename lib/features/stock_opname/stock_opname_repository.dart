import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/auth_provider.dart';
import 'stock_opname_model.dart';

abstract class StockOpnameRepository {
  Future<StockOpnameSession?> getActiveSession(String tenantSlug);
  Future<void> recordCount(
    String tenantSlug, {
    required int itemId,
    required num physicalQty,
  });
  Future<void> submitReview(String tenantSlug, {required int sessionId});
}

class ApiStockOpnameRepository implements StockOpnameRepository {
  ApiStockOpnameRepository(this._dio);

  final Dio _dio;

  AppException _mapFailure(DioException error, String fallback) =>
      error.error is AppException
      ? error.error as AppException
      : ServerException(fallback);

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
      final sessionData = rawSession is Map
          ? Map<String, dynamic>.from(rawSession)
          : data;
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
  Future<void> recordCount(
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
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal menyimpan jumlah fisik.');
    }
  }

  @override
  Future<void> submitReview(String tenantSlug, {required int sessionId}) async {
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
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal mengirim sesi untuk review.');
    }
  }
}

final stockOpnameDataSourceProvider = Provider<StockOpnameRepository>((ref) {
  return ApiStockOpnameRepository(ref.watch(dioProvider));
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
    await _repository.recordCount(
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
      ),
    );
  }

  Future<void> submitReview() async {
    final session = state.asData?.value;
    final slug = _tenantSlug;
    if (session == null || slug == null || slug.isEmpty) {
      throw const ServerException('Sesi stock opname aktif tidak tersedia.');
    }
    if (session.id <= 0) {
      throw const ServerException('ID sesi stock opname tidak valid.');
    }
    await _repository.submitReview(slug, sessionId: session.id);
    state = AsyncData(session.copyWith(status: 'REVIEW'));
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
