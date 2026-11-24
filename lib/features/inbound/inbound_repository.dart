import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/offline/offline_db.dart';
import '../../core/offline/offline_identity.dart';
import '../../core/offline/sync_manager.dart';
import '../../shared/utils/connectivity_checker.dart';
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
    required List<Map<String, dynamic>> items,
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
  ApiInboundRepository(this._dio, {this.ownerKey});

  final Dio _dio;
  final String? ownerKey;

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
      final result = _parseManifestList(response.data);
      if (ownerKey != null) {
        await OfflineDb.cacheListSnapshot(
          tenantSlug: slug,
          ownerKey: ownerKey!,
          feature: 'inbound',
          filters: filters,
          payload: response.data,
        );
      }
      return result;
    } on DioException catch (error) {
      final failure = _mapFailure(error, 'Gagal mengambil daftar manifes.');
      if (failure is NetworkException && ownerKey != null) {
        final cached = await OfflineDb.getCachedListSnapshot(
          tenantSlug: slug,
          ownerKey: ownerKey!,
          feature: 'inbound',
          filters: filters,
        );
        if (cached != null) return _parseManifestList(cached);
      }
      throw failure;
    }
  }

  InboundListResult _parseManifestList(dynamic responseData) {
    final envelope = _asMap(responseData, 'Format daftar inbound tidak valid.');
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
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.inboundCreate(slug),
        data: {
          'local_uuid': localUuid,
          'supplier_id': supplierId,
          'items': items,
        },
      );
      if (response.data is Map && response.data['success'] == false) {
        throw ServerException(
          response.data['message']?.toString() ??
              'Gagal membuat manifes baru.',
        );
      }
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
  final auth = ref.watch(authProvider);
  return ApiInboundRepository(
    ref.watch(dioProvider),
    ownerKey: offlineOwnerKey(
      userId: auth.userId,
      token: auth.token ?? 'unauthenticated',
    ),
  );
});

class InboundNotifier extends StateNotifier<List<InboundManifest>> {
  InboundNotifier(
    this._repository,
    this._tenantSlug,
    this._ownerKey, {
    this.dio,
    this.authToken = '',
  })  : stats = const InboundStats(
          todayTotal: 0,
          inProgress: 0,
          completed: 0,
          hold: 0,
        ),
        super(const []);

  final InboundRepository _repository;
  final String _tenantSlug;
  final String _ownerKey;
  final Dio? dio;
  final String authToken;
  InboundStats stats;

  Future<void> loadManifests() async {
    final pending = await _localManifests();
    try {
      final result = await _repository.getManifests(_tenantSlug);
      final localDrafts = pending
          .where((manifest) => manifest.code.startsWith('LOCAL-'))
          .length;
      stats = InboundStats(
        todayTotal: result.stats.todayTotal + localDrafts,
        inProgress: result.stats.inProgress + localDrafts,
        completed: result.stats.completed,
        hold: result.stats.hold,
      );
      state = [
        ...pending,
        ...result.manifests.where(
          (remote) => !pending.any((local) => local.code == remote.code),
        ),
      ];
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

  Future<void> createManifest({
    required String localUuid,
    required int supplierId,
    required List<Map<String, dynamic>> items,
  }) async {
    await _repository.createManifest(
      _tenantSlug,
      localUuid: localUuid,
      supplierId: supplierId,
      items: items,
    );
  }

  Future<List<InboundManifest>> _localManifests() async {
    final rows = await OfflineDb.getInboundManifests(
      tenantSlug: _tenantSlug,
      ownerKey: _ownerKey,
    );
    return rows.map((row) {
      final payload = decodeJsonMap(row['payload_json'] as String);
      final metadata = decodeJsonMap(row['metadata_json'] as String);
      final rawItems =
          metadata['items'] as List? ?? payload['items'] as List? ?? const [];
      final items = rawItems.map((rawItem) {
        final item = Map<String, dynamic>.from(rawItem as Map);
        return InboundItem(
          id: (item['id'] ?? item['sku_id']).toString(),
          productId: int.tryParse((item['sku_id'] ?? '').toString()) ?? 0,
          sku: item['sku']?.toString() ?? '',
          barcode: item['barcode']?.toString() ?? '',
          name: item['name']?.toString() ?? 'Barang Inbound',
          expectedQty: int.tryParse(
                  (item['po_qty'] ?? item['expected_qty']).toString()) ??
              0,
          goodQty: int.tryParse((item['good_qty'] ?? 0).toString()) ?? 0,
          damagedQty: int.tryParse((item['damaged_qty'] ?? 0).toString()) ?? 0,
          targetRack: item['target_rack']?.toString(),
          notes: item['damage_note']?.toString(),
        );
      }).toList();
      final localUuid = row['local_uuid'] as String;
      final manifestCode = payload['manifest_code']?.toString();
      return InboundManifest(
        code: manifestCode ?? 'LOCAL-$localUuid',
        supplierId: int.tryParse(
                (metadata['supplier_id'] ?? payload['supplier_id'] ?? 0)
                    .toString()) ??
            0,
        supplierName: metadata['supplier_name']?.toString() ?? 'Supplier',
        totalUnits: int.tryParse((metadata['total_units'] ?? '').toString()) ??
            items.fold(0, (total, item) => total + item.expectedQty),
        status: InboundStatus.fromString(metadata['status']?.toString()),
        items: items,
        totalSkus: items.length,
        isOfflinePending: true,
        localUuid: localUuid,
        syncError: row['error_message']?.toString(),
      );
    }).toList();
  }

  Future<InboundManifestDetail> loadManifestDetail(String code) async {
    final localUuid = code.startsWith('LOCAL-')
        ? code.substring('LOCAL-'.length)
        : _offlineManifestId(code);
    final row = await OfflineDb.getInboundQueueItem(
      localUuid: localUuid,
      tenantSlug: _tenantSlug,
      ownerKey: _ownerKey,
    );
    if (row != null) {
      if (row['status'] != 'success') {
        return _queuedManifestDetail(row);
      }
      if (code.startsWith('LOCAL-')) {
        final serverCode = row['server_manifest_code']?.toString();
        if (serverCode != null) {
          return _repository.getManifestDetail(_tenantSlug, serverCode);
        }
      }
    }
    if (!code.startsWith('LOCAL-')) {
      try {
        return await _repository.getManifestDetail(_tenantSlug, code);
      } on NetworkException {
        if (row != null) return _queuedManifestDetail(row);
        rethrow;
      }
    }
    if (row == null) {
      throw const ServerException('Manifes lokal tidak ditemukan.');
    }

    final serverCode = row['server_manifest_code']?.toString();
    if (row['status'] == 'success' && serverCode != null) {
      return _repository.getManifestDetail(_tenantSlug, serverCode);
    }

    return _queuedManifestDetail(row);
  }

  Future<InboundManifestDetail> _queuedManifestDetail(
    Map<String, Object?> row,
  ) async {
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
      return InboundItem(
        id: (metadataItem['id'] ?? 'local:$index').toString(),
        productId: int.tryParse(
              (payloadItem['sku_id'] ?? metadataItem['sku_id'] ?? '')
                  .toString(),
            ) ??
            0,
        sku: metadataItem['sku']?.toString() ?? '',
        barcode: metadataItem['barcode']?.toString() ?? '',
        name: metadataItem['name']?.toString() ?? 'Barang Inbound',
        expectedQty: int.tryParse(
              (payloadItem['po_qty'] ?? metadataItem['po_qty'] ?? '')
                  .toString(),
            ) ??
            0,
        goodQty: int.tryParse((payloadItem['good_qty'] ?? 0).toString()) ?? 0,
        damagedQty:
            int.tryParse((payloadItem['damaged_qty'] ?? 0).toString()) ?? 0,
        targetRack: payloadItem['target_rack']?.toString(),
        notes: payloadItem['damage_note']?.toString(),
      );
    });
    var rawLocations = metadata['locations'] as List? ?? const [];
    if (rawLocations.isEmpty) {
      final cachedOptions = await OfflineDb.getCachedInboundOptions(
        tenantSlug: _tenantSlug,
        ownerKey: _ownerKey,
      );
      rawLocations = cachedOptions?['available_racks'] as List? ?? const [];
    }
    final locations = rawLocations
        .whereType<Map>()
        .map(
            (item) => InboundLocation.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    if (locations.isEmpty) {
      locations.addAll(
        rawLocations.asMap().entries.map(
              (entry) => InboundLocation(
                id: entry.key,
                rackCode: entry.value.toString(),
              ),
            ),
      );
    }
    final localUuid = row['local_uuid'] as String;
    final code = payload['manifest_code']?.toString() ?? localUuid;
    final manifest = InboundManifest(
      code: code,
      supplierId: int.tryParse(
            (metadata['supplier_id'] ?? payload['supplier_id'] ?? 0).toString(),
          ) ??
          0,
      supplierName: metadata['supplier_name']?.toString() ?? 'Supplier',
      totalUnits: int.tryParse((metadata['total_units'] ?? '').toString()) ??
          items.fold(0, (total, item) => total + item.expectedQty),
      status: InboundStatus.fromString(metadata['status']?.toString()),
      items: items,
      totalSkus: items.length,
      isOfflinePending: true,
      localUuid: localUuid,
      syncError: row['error_message']?.toString(),
    );
    return InboundManifestDetail(
      manifest: manifest,
      items: items,
      locations: locations,
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
    InboundManifestDetail? snapshot,
  }) async {
    if (!manifestCode.startsWith('LOCAL-')) {
      final serverItemId = int.tryParse(itemId);
      if (serverItemId == null) {
        throw const ServerException('ID item manifes tidak valid.');
      }
      final localUuid = _offlineManifestId(manifestCode);
      final row = await OfflineDb.getInboundQueueItem(
        localUuid: localUuid,
        tenantSlug: _tenantSlug,
        ownerKey: _ownerKey,
      );
      if (row != null && row['status'] != 'success') {
        await _saveQueuedManifestProgress(
          manifestCode: manifestCode,
          localUuid: localUuid,
          itemId: itemId,
          goodQty: goodQty,
          damagedQty: damagedQty,
          targetRack: targetRack,
          damageNote: damageNote,
          snapshot: snapshot,
          existingRow: row,
        );
        await _trySync(localUuid);
        return;
      }
      try {
        await _repository.submitPutaway(
          _tenantSlug,
          manifestCode: manifestCode,
          itemId: serverItemId,
          goodQty: goodQty,
          damagedQty: damagedQty,
          targetRack: targetRack,
          damageNote: damageNote,
        );
      } on NetworkException {
        if (snapshot == null) rethrow;
        await _saveQueuedManifestProgress(
          manifestCode: manifestCode,
          localUuid: localUuid,
          itemId: itemId,
          goodQty: goodQty,
          damagedQty: damagedQty,
          targetRack: targetRack,
          damageNote: damageNote,
          snapshot: snapshot,
          existingRow: row,
        );
        await _trySync(localUuid);
      }
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

  Future<bool> commitManifestApi(
    String manifestCode, {
    InboundManifestDetail? snapshot,
  }) async {
    final localManifest = manifestCode.startsWith('LOCAL-');
    final localUuid = localManifest
        ? manifestCode.substring('LOCAL-'.length)
        : _offlineManifestId(manifestCode);
    final row = await OfflineDb.getInboundQueueItem(
      localUuid: localUuid,
      tenantSlug: _tenantSlug,
      ownerKey: _ownerKey,
    );
    if (row != null && row['status'] != 'success') {
      final payload = decodeJsonMap(row['payload_json'] as String)
        ..['should_commit'] = true;
      await OfflineDb.saveInboundProgress(
        localUuid: localUuid,
        tenantSlug: _tenantSlug,
        ownerKey: _ownerKey,
        payload: payload,
        metadata: decodeJsonMap(row['metadata_json'] as String),
      );
      final synced = await _trySync(localUuid);
      await loadManifests();
      return synced;
    }

    final serverCode = row?['server_manifest_code']?.toString() ??
        (localManifest ? null : manifestCode);
    if (serverCode == null) {
      throw const NetworkException(
        'Manifes inbound lokal harus disinkronkan sebelum commit.',
      );
    }
    try {
      await _repository.commitManifest(_tenantSlug, serverCode);
      await loadManifests();
      return true;
    } on NetworkException {
      if (snapshot == null) rethrow;
      final item = snapshot.items.firstOrNull;
      if (item == null) rethrow;
      await _saveQueuedManifestProgress(
        manifestCode: serverCode,
        localUuid: _offlineManifestId(serverCode),
        itemId: item.id,
        goodQty: item.goodQty,
        damagedQty: item.damagedQty,
        targetRack: item.targetRack ?? '',
        damageNote: item.notes,
        snapshot: snapshot,
        shouldCommit: true,
        existingRow:
            row != null && row['local_uuid'] == _offlineManifestId(serverCode)
                ? row
                : null,
      );
      final synced = await _trySync(_offlineManifestId(serverCode));
      await loadManifests();
      return synced;
    }
  }

  Future<void> _saveQueuedManifestProgress({
    required String manifestCode,
    required String localUuid,
    required String itemId,
    required int goodQty,
    required int damagedQty,
    required String targetRack,
    required InboundManifestDetail? snapshot,
    required String? damageNote,
    Map<String, Object?>? existingRow,
    bool shouldCommit = false,
  }) async {
    if (existingRow == null && snapshot == null) {
      throw const NetworkException(
        'Detail manifes inbound belum tersedia untuk disimpan offline.',
      );
    }
    final oldPayload = existingRow == null
        ? <String, dynamic>{}
        : decodeJsonMap(existingRow['payload_json'] as String);
    final oldMetadata = existingRow == null
        ? <String, dynamic>{}
        : decodeJsonMap(existingRow['metadata_json'] as String);
    final metadataItems = (oldMetadata['items'] as List? ??
            snapshot?.items.map(_inboundMetadataItem).toList() ??
            const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final payloadItems = (oldPayload['items'] as List? ??
            snapshot?.items.map(_inboundPayloadItem).toList() ??
            const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    var index = metadataItems.indexWhere(
      (item) => item['id']?.toString() == itemId,
    );
    if (index < 0 && snapshot != null) {
      index = snapshot.items.indexWhere((item) => item.id == itemId);
    }
    if (index < 0 || index >= payloadItems.length) {
      throw const ServerException('Item manifes inbound tidak ditemukan.');
    }
    payloadItems[index] = {
      ...payloadItems[index],
      'good_qty': goodQty,
      'damaged_qty': damagedQty,
      'target_rack': targetRack,
      'damage_note': damageNote,
    };
    metadataItems[index] = {
      ...metadataItems[index],
      'good_qty': goodQty,
      'damaged_qty': damagedQty,
      'target_rack': targetRack,
      'damage_note': damageNote,
    };
    final source = snapshot?.manifest;
    final payload = <String, dynamic>{
      ...oldPayload,
      'manifest_code': manifestCode,
      'local_uuid': localUuid,
      'should_commit': shouldCommit || oldPayload['should_commit'] == true,
      if (source != null) 'supplier_id': source.supplierId,
      'items': payloadItems,
    };
    final metadata = <String, dynamic>{
      ...oldMetadata,
      if (source != null) 'supplier_id': source.supplierId,
      if (source != null) 'supplier_name': source.supplierName,
      if (source != null) 'status': source.status.label,
      if (source != null) 'total_units': source.totalUnits,
      if (snapshot != null)
        'locations': snapshot.locations
            .map((location) => {
                  'id': location.id,
                  'rack_code': location.rackCode,
                  'zone': location.zone,
                  'stock_quantity': location.stockQuantity,
                })
            .toList(),
      'items': metadataItems,
    };
    if (existingRow == null) {
      await OfflineDb.enqueueInbound(
        localUuid: localUuid,
        tenantSlug: _tenantSlug,
        ownerKey: _ownerKey,
        payload: payload,
        metadata: metadata,
      );
    } else {
      await OfflineDb.saveInboundProgress(
        localUuid: localUuid,
        tenantSlug: _tenantSlug,
        ownerKey: _ownerKey,
        payload: payload,
        metadata: metadata,
      );
    }
  }

  Map<String, dynamic> _inboundPayloadItem(InboundItem item) => {
        'sku_id': item.productId,
        'po_qty': item.expectedQty,
        'good_qty': item.goodQty,
        'damaged_qty': item.damagedQty,
        if (item.targetRack != null) 'target_rack': item.targetRack,
        if (item.notes != null) 'damage_note': item.notes,
      };

  Map<String, dynamic> _inboundMetadataItem(InboundItem item) => {
        'id': item.id,
        'sku_id': item.productId,
        'sku': item.sku,
        'barcode': item.barcode,
        'name': item.name,
        'po_qty': item.expectedQty,
        'good_qty': item.goodQty,
        'damaged_qty': item.damagedQty,
        if (item.targetRack != null) 'target_rack': item.targetRack,
        if (item.notes != null) 'damage_note': item.notes,
      };

  String _offlineManifestId(String manifestCode) =>
      'INBOUND-MANIFEST-$manifestCode';

  Future<bool> _trySync(String localUuid) async {
    final syncDio = dio;
    if (syncDio == null ||
        authToken.isEmpty ||
        !await ConnectivityChecker.instance.isOnline()) {
      return false;
    }
    final result = await SyncManager.instance.syncInboundQueue(
      dio: syncDio,
      tenantSlug: _tenantSlug,
      ownerKey: _ownerKey,
      authToken: authToken,
      localUuid: localUuid,
    );
    return result.syncedCount == 1 && result.failures.isEmpty;
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
  return InboundNotifier(
    repository,
    slug,
    ownerKey,
    dio: ref.watch(dioProvider),
    authToken: authState.token ?? '',
  );
});

final inboundStatsProvider = Provider<InboundStats>((ref) {
  ref.watch(inboundRepositoryProvider);
  return ref.read(inboundRepositoryProvider.notifier).stats;
});
