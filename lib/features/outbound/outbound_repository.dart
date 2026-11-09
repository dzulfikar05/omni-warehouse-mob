import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/auth_provider.dart';
import 'outbound_model.dart';

class OutboundMasterOptions {
  const OutboundMasterOptions({
    required this.customers,
    required this.products,
    required this.locations,
    this.availableRacks = const [],
  });

  final List<OutboundCustomer> customers;
  final List<OutboundProductMaster> products;
  final List<OutboundLocation> locations;
  final List<String> availableRacks;
}

class OutboundListResult {
  const OutboundListResult({required this.manifests, required this.stats});

  final List<OutboundOrder> manifests;
  final OutboundStats stats;
}

abstract class OutboundRepository {
  Future<OutboundMasterOptions> getMasterOptions(String slug);
  Future<OutboundListResult> getManifests(
    String slug, {
    Map<String, dynamic> filters = const {},
  });
  Future<OutboundManifestDetail> getManifestDetail(String slug, String code);
  Future<void> createManifest(
    String slug, {
    required int customerId,
    required List<Map<String, int>> items,
    String? vehicleNo,
    String? driverName,
    String? notes,
  });
  Future<void> verifyBarcode(
    String slug, {
    required String manifestCode,
    required String barcode,
  });
  Future<void> updatePicking({
    required String slug,
    required String manifestCode,
    required int itemId,
    required int goodQty,
    required int damagedQty,
    int? sourceRackId,
    String? damageNote,
  });
  Future<void> commitOutbound(String slug, String manifestCode);
  Future<void> hold(String slug, String manifestCode, {String? reason});
  Future<void> resume(String slug, String manifestCode);
}

class ApiOutboundRepository implements OutboundRepository {
  ApiOutboundRepository(this._dio);

  final Dio _dio;

  AppException _mapFailure(DioException error, String fallback) =>
      error.error is AppException
      ? error.error as AppException
      : ServerException(fallback);

  Map<String, dynamic> _asMap(dynamic value, String message) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw ServerException(message);
  }

  List<dynamic> _asList(dynamic value, {required String field}) {
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
  Future<OutboundMasterOptions> getMasterOptions(String slug) async {
    try {
      final response = await _dio.get(ApiEndpoints.outboundOptions(slug));
      final envelope = _asMap(
        response.data,
        'Format opsi outbound tidak valid.',
      );
      _requireSuccess(envelope, 'Gagal memuat master data outbound.');
      final data = _asMap(
        envelope['data'],
        'Master data outbound tidak valid.',
      );
      final rawAvailableRacks = data['available_racks'];
      final rawLocations =
          data['locations'] ??
          data['available_locations'] ??
          (rawAvailableRacks is List &&
                  rawAvailableRacks.any((item) => item is Map)
              ? rawAvailableRacks
              : null);
      final locations = _asList(rawLocations, field: 'lokasi')
          .whereType<Map>()
          .map(
            (item) =>
                OutboundLocation.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((location) => location.id > 0)
          .toList();
      final availableRacks =
          _asList(rawAvailableRacks ?? rawLocations, field: 'rak')
              .map((item) {
                if (item is Map) {
                  final rack = item['rack_code'] ?? item['code'];
                  return rack?.toString() ?? '';
                }
                return item.toString();
              })
              .where((rack) => rack.isNotEmpty)
              .toList();
      return OutboundMasterOptions(
        customers: _asList(data['customers'], field: 'customer')
            .whereType<Map>()
            .map(
              (item) =>
                  OutboundCustomer.fromJson(Map<String, dynamic>.from(item)),
            )
            .where((customer) => customer.id > 0 && customer.name.isNotEmpty)
            .toList(),
        products: _asList(data['products'] ?? data['skus'], field: 'SKU')
            .whereType<Map>()
            .map(
              (item) => OutboundProductMaster.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .where((product) => product.skuId > 0)
            .toList(),
        locations: locations,
        availableRacks: availableRacks.isEmpty
            ? locations.map((location) => location.rackCode).toList()
            : availableRacks,
      );
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal memuat master data customer/item.');
    }
  }

  @override
  Future<OutboundListResult> getManifests(
    String slug, {
    Map<String, dynamic> filters = const {},
  }) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.outboundList(slug),
        queryParameters: filters,
      );
      final envelope = _asMap(
        response.data,
        'Format daftar outbound tidak valid.',
      );
      _requireSuccess(envelope, 'Gagal memuat daftar manifes outbound.');
      final data = envelope['data'];
      final manifestContainer = data is Map ? data['manifests'] : data;
      final manifests = _asList(manifestContainer, field: 'manifes outbound')
          .whereType<Map>()
          .map(
            (item) => OutboundOrder.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      final summaryValue = data is Map
          ? (data['summary'] ?? data['stats'])
          : null;
      final summary = summaryValue is Map
          ? Map<String, dynamic>.from(summaryValue)
          : const <String, dynamic>{};
      return OutboundListResult(
        manifests: manifests,
        stats: OutboundStats.fromJson(summary, manifests: manifests),
      );
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal memuat daftar manifes outbound.');
    }
  }

  @override
  Future<OutboundManifestDetail> getManifestDetail(
    String slug,
    String code,
  ) async {
    try {
      final response = await _dio.get(ApiEndpoints.outboundDetail(slug, code));
      final envelope = _asMap(
        response.data,
        'Format detail outbound tidak valid.',
      );
      _requireSuccess(envelope, 'Gagal memuat detail manifes outbound.');
      final data = _asMap(
        envelope['data'],
        'Detail manifes outbound tidak tersedia.',
      );
      final manifestJson = _asMap(
        data['manifest'],
        'Data manifes outbound tidak valid.',
      );
      final rawItems = data['items'];
      final items = _asList(rawItems, field: 'item outbound')
          .whereType<Map>()
          .map((item) => OutboundItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      final locations =
          _asList(
                data['locations'] ?? data['available_locations'],
                field: 'lokasi outbound',
              )
              .whereType<Map>()
              .map(
                (item) =>
                    OutboundLocation.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((location) => location.rackCode.isNotEmpty)
              .toList();
      manifestJson['items'] = rawItems;
      return OutboundManifestDetail(
        manifest: OutboundOrder.fromJson(manifestJson),
        items: items,
        locations: locations,
      );
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal memuat detail manifes outbound.');
    }
  }

  @override
  Future<void> createManifest(
    String slug, {
    required int customerId,
    required List<Map<String, int>> items,
    String? vehicleNo,
    String? driverName,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.outboundCreate(slug),
        data: {
          'customer_id': customerId,
          'items': items,
          if (vehicleNo?.trim().isNotEmpty ?? false)
            'vehicle_no': vehicleNo!.trim(),
          if (driverName?.trim().isNotEmpty ?? false)
            'driver_name': driverName!.trim(),
          if (notes?.trim().isNotEmpty ?? false) 'notes': notes!.trim(),
        },
      );
      final envelope = _asMap(
        response.data,
        'Format respons pembuatan outbound tidak valid.',
      );
      _requireSuccess(envelope, 'Gagal membuat manifes outbound.');
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal membuat manifes outbound.');
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
        ApiEndpoints.outboundVerifyBarcode(slug),
        data: {'manifest_code': manifestCode, 'barcode': barcode},
      );
      final envelope = _asMap(
        response.data,
        'Format verifikasi barcode tidak valid.',
      );
      _requireSuccess(envelope, 'Barcode tidak cocok dengan item manifes.');
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal memverifikasi barcode outbound.');
    }
  }

  @override
  Future<void> updatePicking({
    required String slug,
    required String manifestCode,
    required int itemId,
    required int goodQty,
    required int damagedQty,
    int? sourceRackId,
    String? damageNote,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.outboundPicking(slug),
        data: {
          'manifest_code': manifestCode,
          'item_id': itemId,
          'good_qty': goodQty,
          'damaged_qty': damagedQty,
          'source_rack_id': sourceRackId,
          'damage_note': damageNote,
        },
      );
      final envelope = _asMap(
        response.data,
        'Format alokasi picking tidak valid.',
      );
      _requireSuccess(envelope, 'Gagal menyimpan alokasi picking.');
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal memperbarui alokasi picking.');
    }
  }

  @override
  Future<void> commitOutbound(String slug, String manifestCode) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.outboundCommit(slug),
        data: {'manifest_code': manifestCode},
      );
      final envelope = _asMap(
        response.data,
        'Format commit outbound tidak valid.',
      );
      _requireSuccess(envelope, 'Gagal melakukan commit outbound.');
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal melakukan commit outbound.');
    }
  }

  @override
  Future<void> hold(String slug, String manifestCode, {String? reason}) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.outboundHold(slug),
        data: {
          'manifest_code': manifestCode,
          if (reason?.trim().isNotEmpty ?? false) 'reason': reason!.trim(),
        },
      );
      final envelope = _asMap(
        response.data,
        'Format hold outbound tidak valid.',
      );
      _requireSuccess(envelope, 'Gagal menahan sesi outbound.');
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal menahan sesi outbound.');
    }
  }

  @override
  Future<void> resume(String slug, String manifestCode) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.outboundResume(slug),
        data: {'manifest_code': manifestCode},
      );
      final envelope = _asMap(
        response.data,
        'Format resume outbound tidak valid.',
      );
      _requireSuccess(envelope, 'Gagal melanjutkan sesi outbound.');
    } on DioException catch (error) {
      throw _mapFailure(error, 'Gagal melanjutkan sesi outbound.');
    }
  }
}

final outboundDataSourceProvider = Provider<OutboundRepository>((ref) {
  return ApiOutboundRepository(ref.watch(dioProvider));
});

class OutboundNotifier extends StateNotifier<List<OutboundOrder>> {
  OutboundNotifier({
    required OutboundRepository repository,
    required String tenantSlug,
    List<OutboundOrder> initialOrders = const [],
  }) : _repository = repository,
       _tenantSlug = tenantSlug,
       stats = OutboundStats.fromManifests(initialOrders),
       super(initialOrders);

  final OutboundRepository _repository;
  final String _tenantSlug;
  OutboundStats stats;

  OutboundOrder? getOrderByCode(String code) {
    for (final order in state) {
      if (order.code.toLowerCase() == code.toLowerCase()) return order;
    }
    return null;
  }

  Future<OutboundMasterOptions> loadMasterOptions() =>
      _repository.getMasterOptions(_tenantSlug);

  Future<void> loadManifests({Map<String, dynamic> filters = const {}}) async {
    final result = await _repository.getManifests(
      _tenantSlug,
      filters: filters,
    );
    stats = result.stats;
    state = result.manifests;
  }

  Future<OutboundManifestDetail> loadManifestDetail(String code) async {
    final detail = await _repository.getManifestDetail(_tenantSlug, code);
    _replaceOrder(detail.manifest.copyWithItems(detail.items));
    return detail;
  }

  Future<void> createManifest({
    required int customerId,
    required List<Map<String, int>> items,
    String? vehicleNo,
    String? driverName,
    String? notes,
  }) async {
    await _repository.createManifest(
      _tenantSlug,
      customerId: customerId,
      items: items,
      vehicleNo: vehicleNo,
      driverName: driverName,
      notes: notes,
    );
    await loadManifests();
  }

  Future<void> verifyBarcode(String code, String barcode) => _repository
      .verifyBarcode(_tenantSlug, manifestCode: code, barcode: barcode);

  Future<void> savePicking({
    required String manifestCode,
    required int itemId,
    required int goodQty,
    required int damagedQty,
    int? sourceRackId,
    String? damageNote,
  }) async {
    await _repository.updatePicking(
      slug: _tenantSlug,
      manifestCode: manifestCode,
      itemId: itemId,
      goodQty: goodQty,
      damagedQty: damagedQty,
      sourceRackId: sourceRackId,
      damageNote: damageNote,
    );
    await loadManifestDetail(manifestCode);
  }

  Future<void> commitOutboundApi(String manifestCode) async {
    await _repository.commitOutbound(_tenantSlug, manifestCode);
    await loadManifests();
  }

  Future<void> holdManifest(String code, {String? reason}) async {
    await _repository.hold(_tenantSlug, code, reason: reason);
    await loadManifests();
  }

  Future<void> resumeManifest(String code) async {
    await _repository.resume(_tenantSlug, code);
    await loadManifests();
  }

  void _replaceOrder(OutboundOrder replacement) {
    final exists = state.any((order) => order.code == replacement.code);
    state = [
      for (final order in state)
        if (order.code == replacement.code) replacement else order,
      if (!exists) replacement,
    ];
    stats = OutboundStats.fromManifests(state);
  }
}

final outboundRepositoryProvider =
    StateNotifierProvider<OutboundNotifier, List<OutboundOrder>>((ref) {
      final authState = ref.watch(authProvider);
      return OutboundNotifier(
        repository: ref.watch(outboundDataSourceProvider),
        tenantSlug:
            authState.tenantSlug ?? authState.tenantName ?? 'demo-tenant',
      );
    });

final outboundStatsProvider = Provider<OutboundStats>((ref) {
  ref.watch(outboundRepositoryProvider);
  return ref.read(outboundRepositoryProvider.notifier).stats;
});
