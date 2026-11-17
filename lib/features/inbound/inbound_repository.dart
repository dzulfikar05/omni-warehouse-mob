import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/offline/offline_db.dart';
import '../../core/offline/offline_identity.dart';
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
    required String localUuid,
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
    required String localUuid,
    required int supplierId,
    required List<Map<String, int>> items,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.inboundCreate(slug),
        data: {
          'local_uuid': localUuid,
          'supplier_id': supplierId,
          'items': items,
        },
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
  InboundNotifier(this._repository, this._tenantSlug, this._ownerKey)
      : stats = const InboundStats(
          todayTotal: 0,
          inProgress: 0,
          completed: 0,
          hold: 0,
        ),
        super(const []);

  final InboundRepository _repository;
  final String _tenantSlug;
  final String _ownerKey;
  InboundStats stats;

  Future<void> loadManifests() async {
    final pending = await _localManifests();
    try {
      final result = await _repository.getManifests(_tenantSlug);
      stats = InboundStats(
        todayTotal: result.stats.todayTotal + pending.length,
        inProgress: result.stats.inProgress + pending.length,
        completed: result.stats.completed,
        hold: result.stats.hold,
      );
      state = [...pending, ...result.manifests];
    } on NetworkException {
      stats = InboundStats(
        todayTotal: pending.length,
        inProgress: pending.length,
        completed: 0,
        hold: 0,
      );
      state = pending;
    }
  }

  Future<void> cacheMasterOptions() async {
    final options = await _repository.getMasterOptions(_tenantSlug);
    await OfflineDb.cacheInboundOptions(
      tenantSlug: _tenantSlug,
      ownerKey: _ownerKey,
      options: {
        'suppliers': options.suppliers
            .map((supplier) => {
                  'id': supplier.id,
                  'code': supplier.code,
                  'name': supplier.name,
                })
            .toList(),
        'products': options.products
            .map((product) => {
                  'id': product.productId,
                  'sku_id': product.id,
                  'sku': product.sku,
                  'barcode': product.barcode,
                  'name': product.name,
                  'unit': product.unit,
                  'available_stock': product.availableStock,
                })
            .toList(),
        'available_racks': options.availableRacks,
      },
    );
  }

  Future<List<InboundManifest>> _localManifests() async {
    final rows = await OfflineDb.getInboundManifests(
      tenantSlug: _tenantSlug,
      ownerKey: _ownerKey,
    );
    return rows.map((row) {
      final metadata = decodeJsonMap(row['metadata_json'] as String);
      final rawItems = metadata['items'] as List? ?? const [];
      final items = rawItems.map((rawItem) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        return InboundItem(
          id: item['sku_id'].toString(),
          productId: int.tryParse(item['sku_id'].toString()) ?? 0,
          sku: item['sku']?.toString() ?? '',
          barcode: item['barcode']?.toString() ?? '',
          name: item['name']?.toString() ?? 'Barang Inbound',
          expectedQty: int.tryParse(item['po_qty'].toString()) ?? 0,
          goodQty: int.tryParse(item['good_qty'].toString()) ?? 0,
          damagedQty: int.tryParse(item['damaged_qty'].toString()) ?? 0,
          targetRack: item['target_rack']?.toString(),
          notes: item['damage_note']?.toString(),
        );
      }).toList();
      final localUuid = row['local_uuid'] as String;
      return InboundManifest(
        code: localUuid,
        supplierId: int.tryParse(metadata['supplier_id'].toString()) ?? 0,
        supplierName: metadata['supplier_name']?.toString() ?? 'Supplier',
        totalUnits: items.fold(0, (total, item) => total + item.expectedQty),
        status: InboundStatus.draft,
        items: items,
        totalSkus: items.length,
        isOfflinePending: true,
        localUuid: localUuid,
        syncError: row['error_message']?.toString(),
      );
    }).toList();
  }

  Future<InboundManifestDetail> loadManifestDetail(String code) async {
    if (!code.startsWith('LOCAL-')) {
      return _repository.getManifestDetail(_tenantSlug, code);
    }

    final localUuid = code.substring('LOCAL-'.length);
    final row = await OfflineDb.getInboundQueueItem(
      localUuid: localUuid,
      tenantSlug: _tenantSlug,
      ownerKey: _ownerKey,
    );
    if (row == null) {
      throw const ServerException('Manifes lokal tidak ditemukan.');
    }

    final serverCode = row['server_manifest_code']?.toString();
    if (row['status'] == 'success' && serverCode != null) {
      return _repository.getManifestDetail(_tenantSlug, serverCode);
    }

    final payload = decodeJsonMap(row['payload_json'] as String);
    final metadata = decodeJsonMap(row['metadata_json'] as String);
    final payloadItems = payload['items'] as List? ?? const [];
    final metadataItems = metadata['items'] as List? ?? const [];
    final items = List<InboundItem>.generate(metadataItems.length, (index) {
      final metadataItem =
          Map<String, dynamic>.from(metadataItems[index] as Map);
      final payloadItem = index < payloadItems.length
          ? Map<String, dynamic>.from(payloadItems[index] as Map)
          : metadataItem;
      final skuId = payloadItem['sku_id'] ?? metadataItem['sku_id'];
      return InboundItem(
        id: 'local:$index',
        productId: int.tryParse(skuId.toString()) ?? 0,
        sku: metadataItem['sku']?.toString() ?? '',
        barcode: metadataItem['barcode']?.toString() ?? '',
        name: metadataItem['name']?.toString() ?? 'Barang Inbound',
        expectedQty: int.tryParse(payloadItem['po_qty']?.toString() ?? '') ?? 0,
        goodQty: int.tryParse(payloadItem['good_qty']?.toString() ?? '') ?? 0,
        damagedQty:
            int.tryParse(payloadItem['damaged_qty']?.toString() ?? '') ?? 0,
        targetRack: payloadItem['target_rack']?.toString(),
        notes: payloadItem['damage_note']?.toString(),
      );
    });
    final cachedOptions = await OfflineDb.getCachedInboundOptions(
      tenantSlug: _tenantSlug,
      ownerKey: _ownerKey,
    );
    final racks = (cachedOptions?['available_racks'] as List? ?? const [])
        .map((rack) => rack.toString())
        .toList();

    return InboundManifestDetail(
      manifest: InboundManifest(
        code: localUuid,
        supplierId: int.tryParse(payload['supplier_id'].toString()) ?? 0,
        supplierName: metadata['supplier_name']?.toString() ?? 'Supplier',
        totalUnits: items.fold(0, (total, item) => total + item.expectedQty),
        status: InboundStatus.draft,
        items: items,
        totalSkus: items.length,
        isOfflinePending: true,
        localUuid: localUuid,
        syncError: row['error_message']?.toString(),
      ),
      items: items,
      locations: racks
          .asMap()
          .entries
          .map((entry) => InboundLocation(
                id: entry.key,
                rackCode: entry.value,
              ))
          .toList(),
    );
  }

  Future<void> verifyBarcode(String code, String barcode) => _repository
      .verifyBarcode(_tenantSlug, manifestCode: code, barcode: barcode);

  Future<void> queueOfflineManifest({
    required String localUuid,
    required Map<String, dynamic> offlinePayload,
    required Map<String, dynamic> metadata,
  }) =>
      OfflineDb.enqueueInbound(
        localUuid: localUuid,
        tenantSlug: _tenantSlug,
        ownerKey: _ownerKey,
        payload: offlinePayload,
        metadata: metadata,
      );

  Future<void> updateItemTally({
    required String manifestCode,
    required String itemId,
    required int goodQty,
    required int damagedQty,
    required String targetRack,
    String? damageNote,
  }) async {
    if (!manifestCode.startsWith('LOCAL-')) {
      final serverItemId = int.tryParse(itemId);
      if (serverItemId == null) {
        throw const ServerException('ID item manifes tidak valid.');
      }
      await _repository.submitPutaway(
        _tenantSlug,
        manifestCode: manifestCode,
        itemId: serverItemId,
        goodQty: goodQty,
        damagedQty: damagedQty,
        targetRack: targetRack,
        damageNote: damageNote,
      );
      return;
    }

    final localUuid = manifestCode.substring('LOCAL-'.length);
    final row = await OfflineDb.getInboundQueueItem(
      localUuid: localUuid,
      tenantSlug: _tenantSlug,
      ownerKey: _ownerKey,
    );
    if (row == null) {
      throw const ServerException('Manifes lokal tidak ditemukan.');
    }
    if (row['status'] == 'success') {
      final serverCode = row['server_manifest_code']?.toString();
      final serverItemId = int.tryParse(itemId);
      if (serverCode == null || serverItemId == null) {
        throw const ServerException(
            'Data manifes tersinkronisasi tidak valid.');
      }
      await _repository.submitPutaway(
        _tenantSlug,
        manifestCode: serverCode,
        itemId: serverItemId,
        goodQty: goodQty,
        damagedQty: damagedQty,
        targetRack: targetRack,
        damageNote: damageNote,
      );
      return;
    }

    final itemIndex = int.tryParse(itemId.replaceFirst('local:', ''));
    if (itemIndex == null) {
      throw const ServerException('ID item lokal tidak valid.');
    }
    final payload = decodeJsonMap(row['payload_json'] as String);
    final metadata = decodeJsonMap(row['metadata_json'] as String);
    final payloadItems = (payload['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final metadataItems = (metadata['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    if (itemIndex >= payloadItems.length || itemIndex >= metadataItems.length) {
      throw const ServerException('Item manifes lokal tidak ditemukan.');
    }
    payloadItems[itemIndex] = {
      ...payloadItems[itemIndex],
      'good_qty': goodQty,
      'damaged_qty': damagedQty,
      'target_rack': targetRack,
      'damage_note': damageNote,
    };
    metadataItems[itemIndex] = {
      ...metadataItems[itemIndex],
      'good_qty': goodQty,
      'damaged_qty': damagedQty,
      'target_rack': targetRack,
      'damage_note': damageNote,
    };
    payload['items'] = payloadItems;
    metadata['items'] = metadataItems;
    await OfflineDb.saveInboundProgress(
      localUuid: localUuid,
      tenantSlug: _tenantSlug,
      ownerKey: _ownerKey,
      payload: payload,
      metadata: metadata,
    );
  }

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
  final slug = authState.tenantSlug ?? authState.tenantName ?? 'demo-tenant';
  final ownerKey = offlineOwnerKey(
    userId: authState.userId,
    token: authState.token ?? 'unauthenticated',
  );
  return InboundNotifier(repository, slug, ownerKey);
});

final inboundStatsProvider = Provider<InboundStats>((ref) {
  ref.watch(inboundRepositoryProvider);
  return ref.read(inboundRepositoryProvider.notifier).stats;
});
