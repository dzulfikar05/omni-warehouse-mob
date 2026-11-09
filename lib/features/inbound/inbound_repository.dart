import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/auth_provider.dart';
import 'inbound_model.dart';

class InboundMasterOptions {
  const InboundMasterOptions({
    required this.suppliers,
    required this.products,
    required this.availableRacks,
  });

  final List<InboundSupplier> suppliers;
  final List<InboundProductMaster> products;
  final List<String> availableRacks;
}

class InboundListResult {
  const InboundListResult({required this.manifests, required this.stats});

  final List<InboundManifest> manifests;
  final InboundStats stats;
}

abstract class InboundRepository {
  Future<InboundMasterOptions> getMasterOptions(String slug);
  Future<InboundListResult> getManifests(
    String slug, {
    Map<String, dynamic> filters = const {},
  });
  Future<InboundManifestDetail> getManifestDetail(String slug, String code);
  Future<void> createManifest(
    String slug, {
    required int supplierId,
    required List<Map<String, int>> items,
  });
  Future<void> verifyBarcode(
    String slug, {
    required String manifestCode,
    required String barcode,
  });
  Future<void> submitPutaway(
    String slug, {
    required String manifestCode,
    required int itemId,
    required int goodQty,
    required int damagedQty,
    required String targetRack,
    String? damageNote,
  });
  Future<void> commitManifest(String slug, String manifestCode);
  Future<void> holdManifest(String slug, String manifestCode, {String? reason});
  Future<void> resumeManifest(String slug, String manifestCode);
}

class ApiInboundRepository implements InboundRepository {
  ApiInboundRepository(this._dio);

  final Dio _dio;

  AppException _mapFailure(DioException error, String fallback) {
    return error.error is AppException
        ? error.error as AppException
        : ServerException(fallback);
  }

  Map<String, dynamic> _asMap(dynamic value, String errorMessage) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw ServerException(errorMessage);
  }

  @override
  Future<InboundMasterOptions> getMasterOptions(String slug) async {
    try {
      final response = await _dio.get(ApiEndpoints.inboundOptions(slug));
      final data = _asMap(
        response.data is Map ? response.data['data'] : null,
        'Format master data inbound tidak valid.',
      );
      final suppliers = (data['suppliers'] as List? ?? [])
          .map(
            (item) => InboundSupplier.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
      final products = (data['products'] as List? ?? [])
          .map(
            (item) => InboundProductMaster.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();

      return InboundMasterOptions(
        suppliers: suppliers,
        products: products,
        availableRacks: (data['available_racks'] as List? ?? [])
            .map((item) => item.toString())
            .toList(),
      );
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal memuat master data supplier/item.');
    }
  }

  @override
  Future<InboundListResult> getManifests(
    String slug, {
    Map<String, dynamic> filters = const {},
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.inboundList(slug),
        queryParameters: filters,
      );
      final envelope = _asMap(
        response.data,
        'Format daftar inbound tidak valid.',
      );
      final data = _asMap(envelope['data'], 'Data daftar inbound tidak valid.');
      final rawManifestPage = data['manifests'];
      final rawManifests = rawManifestPage is List
          ? rawManifestPage
          : rawManifestPage is Map
          ? rawManifestPage['data']
          : null;

      if (rawManifests is! List) {
        throw const ServerException(
          'Format halaman daftar manifes dari server tidak valid.',
        );
      }

      final manifests = rawManifests
          .map(
            (item) => InboundManifest.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
      final rawSummary = data['summary'];
      final summary = rawSummary is Map
          ? Map<String, dynamic>.from(rawSummary)
          : const <String, dynamic>{};

      return InboundListResult(
        manifests: manifests,
        stats: InboundStats.fromJson(summary, manifests: manifests),
      );
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal mengambil daftar manifes.');
    }
  }

  @override
  Future<InboundManifestDetail> getManifestDetail(
    String slug,
    String code,
  ) async {
    try {
      final response = await _dio.get(ApiEndpoints.inboundDetail(slug, code));
      final envelope = _asMap(
        response.data,
        'Format detail inbound tidak valid.',
      );
      final data = _asMap(envelope['data'], 'Detail manifes tidak tersedia.');
      final manifestData = _asMap(
        data['manifest'],
        'Data manifes tidak valid.',
      );
      final itemData = data['items'];
      final locationData = data['available_locations'];
      final items = (itemData is List ? itemData : const [])
          .map(
            (item) =>
                InboundItem.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
      final locations = (locationData is List ? locationData : const [])
          .map(
            (item) => InboundLocation.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where((location) => location.rackCode.isNotEmpty)
          .toList();

      manifestData['items'] = itemData;
      return InboundManifestDetail(
        manifest: InboundManifest.fromJson(manifestData),
        items: items,
        locations: locations,
      );
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal memuat detail manifes.');
    }
  }

  @override
  Future<void> createManifest(
    String slug, {
    required int supplierId,
    required List<Map<String, int>> items,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.inboundCreate(slug),
        data: {'supplier_id': supplierId, 'items': items},
      );
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal membuat manifes baru.');
    }
  }

  @override
  Future<void> verifyBarcode(
    String slug, {
    required String manifestCode,
    required String barcode,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.inboundVerifyBarcode(slug),
        data: {'manifest_code': manifestCode, 'barcode': barcode},
      );
      final envelope = _asMap(
        response.data,
        'Format verifikasi barcode tidak valid.',
      );
      if (envelope['success'] != true) {
        throw ServerException(
          envelope['message']?.toString() ??
              'Barcode tidak cocok dengan item manifes.',
        );
      }
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal memverifikasi barcode item.');
    }
  }

  @override
  Future<void> submitPutaway(
    String slug, {
    required String manifestCode,
    required int itemId,
    required int goodQty,
    required int damagedQty,
    required String targetRack,
    String? damageNote,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.inboundPutaway(slug),
        data: {
          'manifest_code': manifestCode,
          'item_id': itemId,
          'good_qty': goodQty,
          'damaged_qty': damagedQty,
          'target_rack': targetRack,
          'damage_note': damageNote,
        },
      );
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal memperbarui kuantitas putaway.');
    }
  }

  @override
  Future<void> commitManifest(String slug, String manifestCode) async {
    try {
      await _dio.post(
        ApiEndpoints.inboundCommit(slug),
        data: {'manifest_code': manifestCode},
      );
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal melakukan commit manifes.');
    }
  }

  @override
  Future<void> holdManifest(
    String slug,
    String manifestCode, {
    String? reason,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.inboundHold(slug),
        data: {'manifest_code': manifestCode, 'reason': reason},
      );
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal menahan transaksi inbound.');
    }
  }

  @override
  Future<void> resumeManifest(String slug, String manifestCode) async {
    try {
      await _dio.post(
        ApiEndpoints.inboundResume(slug),
        data: {'manifest_code': manifestCode},
      );
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal melanjutkan transaksi inbound.');
    }
  }
}

final inboundDataSourceProvider = Provider<InboundRepository>((ref) {
  return ApiInboundRepository(ref.watch(dioProvider));
});

class InboundNotifier extends StateNotifier<List<InboundManifest>> {
  InboundNotifier(this._repository, this._tenantSlug)
    : stats = const InboundStats(
        todayTotal: 0,
        inProgress: 0,
        completed: 0,
        hold: 0,
      ),
      super(const []);

  final InboundRepository _repository;
  final String _tenantSlug;
  InboundStats stats;

  Future<void> loadManifests() async {
    final result = await _repository.getManifests(_tenantSlug);
    stats = result.stats;
    state = result.manifests;
  }

  Future<InboundManifestDetail> loadManifestDetail(String code) =>
      _repository.getManifestDetail(_tenantSlug, code);

  Future<void> verifyBarcode(String code, String barcode) => _repository
      .verifyBarcode(_tenantSlug, manifestCode: code, barcode: barcode);

  Future<void> createManifest({
    required int supplierId,
    required List<Map<String, int>> items,
  }) async {
    await _repository.createManifest(
      _tenantSlug,
      supplierId: supplierId,
      items: items,
    );
    await loadManifests();
  }

  Future<void> updateItemTally({
    required String manifestCode,
    required int itemId,
    required int goodQty,
    required int damagedQty,
    required String targetRack,
    String? damageNote,
  }) => _repository.submitPutaway(
    _tenantSlug,
    manifestCode: manifestCode,
    itemId: itemId,
    goodQty: goodQty,
    damagedQty: damagedQty,
    targetRack: targetRack,
    damageNote: damageNote,
  );

  Future<void> commitManifestApi(String manifestCode) async {
    await _repository.commitManifest(_tenantSlug, manifestCode);
    await loadManifests();
  }

  Future<void> holdManifest(String manifestCode, {String? reason}) async {
    await _repository.holdManifest(_tenantSlug, manifestCode, reason: reason);
    await loadManifests();
  }

  Future<void> resumeManifest(String manifestCode) async {
    await _repository.resumeManifest(_tenantSlug, manifestCode);
    await loadManifests();
  }
}

final inboundRepositoryProvider =
    StateNotifierProvider<InboundNotifier, List<InboundManifest>>((ref) {
      final repository = ref.watch(inboundDataSourceProvider);
      final authState = ref.watch(authProvider);
      final slug =
          authState.tenantSlug ?? authState.tenantName ?? 'demo-tenant';
      return InboundNotifier(repository, slug);
    });

final inboundStatsProvider = Provider<InboundStats>((ref) {
  ref.watch(inboundRepositoryProvider);
  return ref.read(inboundRepositoryProvider.notifier).stats;
});
