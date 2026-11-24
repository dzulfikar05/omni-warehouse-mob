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
  ApiOutboundRepository(this._dio, {this.ownerKey});

  final Dio _dio;
  final String? ownerKey;

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
      final rawLocations = data['locations'] ??
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
      final result = _parseManifestList(response.data);
      if (ownerKey != null) {
        await OfflineDb.cacheListSnapshot(
          tenantSlug: slug,
          ownerKey: ownerKey!,
          feature: 'outbound',
          filters: filters,
          payload: response.data,
        );
      }
      return result;
    } on DioException catch (error) {
      final failure =
          _mapFailure(error, 'Gagal memuat daftar manifes outbound.');
      if (failure is NetworkException && ownerKey != null) {
        final cached = await OfflineDb.getCachedListSnapshot(
          tenantSlug: slug,
          ownerKey: ownerKey!,
          feature: 'outbound',
          filters: filters,
        );
        if (cached != null) return _parseManifestList(cached);
      }
      throw failure;
    }
  }

  OutboundListResult _parseManifestList(dynamic responseData) {
    final envelope = _asMap(
      responseData,
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
    final summaryValue =
        data is Map ? (data['summary'] ?? data['stats']) : null;
    final summary = summaryValue is Map
        ? Map<String, dynamic>.from(summaryValue)
        : const <String, dynamic>{};
    return OutboundListResult(
      manifests: manifests,
      stats: OutboundStats.fromJson(summary, manifests: manifests),
    );
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
      final locations = _asList(
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
  final auth = ref.watch(authProvider);
  return ApiOutboundRepository(
    ref.watch(dioProvider),
    ownerKey: offlineOwnerKey(
      userId: auth.userId,
      token: auth.token ?? 'unauthenticated',
    ),
  );
});

class OutboundNotifier extends StateNotifier<List<OutboundOrder>> {
  OutboundNotifier({
    required OutboundRepository repository,
    required String tenantSlug,
    this.ownerKey = 'user:offline',
    this.dio,
    this.authToken = '',
    List<OutboundOrder> initialOrders = const [],
  })  : _repository = repository,
        _tenantSlug = tenantSlug,
        stats = OutboundStats.fromManifests(initialOrders),
        super(initialOrders);

  final OutboundRepository _repository;
  final String _tenantSlug;
  final String ownerKey;
  final Dio? dio;
  final String authToken;
  OutboundStats stats;

  OutboundOrder? getOrderByCode(String code) {
    for (final order in state) {
      if (order.code.toLowerCase() == code.toLowerCase()) return order;
    }
    return null;
  }

  Future<OutboundMasterOptions> loadMasterOptions() async {
    try {
      final options = await _repository.getMasterOptions(_tenantSlug);
      await OfflineDb.cacheOutboundOptions(
        tenantSlug: _tenantSlug,
        ownerKey: ownerKey,
        options: _masterOptionsJson(options),
      );
      return options;
    } on NetworkException {
      final cached = await OfflineDb.getCachedOutboundOptions(
        tenantSlug: _tenantSlug,
        ownerKey: ownerKey,
      );
      if (cached == null) rethrow;
      return _masterOptionsFromJson(cached);
    }
  }

  Future<void> loadManifests({Map<String, dynamic> filters = const {}}) async {
    final localOrders = await _loadPendingOrders();
    try {
      final result = await _repository.getManifests(
        _tenantSlug,
        filters: filters,
      );
      stats = result.stats;
      state = [
        ...localOrders,
        ...result.manifests.where(
          (remote) => !localOrders.any(
            (local) =>
                local.code == remote.code || local.localId == remote.code,
          ),
        ),
      ];
    } on NetworkException {
      if (localOrders.isEmpty) rethrow;
      stats = OutboundStats.fromManifests(localOrders);
      state = localOrders;
    }
  }

  Future<OutboundManifestDetail> loadManifestDetail(String code) async {
    final localRow = await _queueItemForCode(code);
    if (localRow != null) {
      final status = localRow['status'] as String;
      if (status != 'success') {
        final detail = await _localManifestDetail(localRow);
        _replaceOrder(detail.manifest);
        return detail;
      }
      final serverCode =
          localRow['server_manifest_code']?.toString().trim().isNotEmpty == true
              ? localRow['server_manifest_code']!.toString()
              : code;
      try {
        final detail = await _repository.getManifestDetail(
          _tenantSlug,
          serverCode,
        );
        _replaceOrder(detail.manifest.copyWithItems(detail.items));
        return detail;
      } on NetworkException {
        return _localManifestDetail(localRow);
      }
    }
    final detail = await _repository.getManifestDetail(_tenantSlug, code);
    _replaceOrder(detail.manifest.copyWithItems(detail.items));
    await _cacheLocations(detail.locations);
    return detail;
  }

  Future<void> queueOfflineManifest({
    required String localUuid,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> metadata,
  }) async {
    await OfflineDb.enqueueOutbound(
      localUuid: localUuid,
      tenantSlug: _tenantSlug,
      ownerKey: ownerKey,
      payload: payload,
      metadata: metadata,
    );
    final row = await OfflineDb.getOutboundQueueItem(
      localUuid: localUuid,
      tenantSlug: _tenantSlug,
      ownerKey: ownerKey,
    );
    if (row == null) {
      throw StateError('Manifes outbound lokal gagal dibaca setelah disimpan.');
    }
    final detail = await _localManifestDetail(row);
    _replaceOrder(detail.manifest);
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
  }

  Future<void> verifyBarcode(String code, String barcode) async {
    final row = await OfflineDb.getOutboundQueueItem(
      localUuid: code,
      tenantSlug: _tenantSlug,
      ownerKey: ownerKey,
    );
    if (row != null && row['status'] != 'success') {
      final metadata = decodeJsonMap(row['metadata_json'] as String);
      final items = metadata['items'] as List? ?? const [];
      final normalized = barcode.trim().toLowerCase();
      final exists = items.whereType<Map>().any((item) {
        final value = Map<String, dynamic>.from(item);
        return value['barcode']?.toString().toLowerCase() == normalized ||
            value['sku']?.toString().toLowerCase() == normalized;
      });
      if (!exists) {
        throw const ServerException(
          'Barcode atau SKU tidak ditemukan pada manifes outbound lokal.',
        );
      }
      return;
    }
    final manifestCode =
        row == null ? code : (row['server_manifest_code']?.toString() ?? code);
    await _repository.verifyBarcode(
      _tenantSlug,
      manifestCode: manifestCode,
      barcode: barcode,
    );
  }

  Future<void> savePicking({
    required String manifestCode,
    required String itemId,
    required int goodQty,
    required int damagedQty,
    int? sourceRackId,
    String? sourceRack,
    String? damageNote,
    OutboundManifestDetail? snapshot,
  }) async {
    final row = await _queueItemForCode(manifestCode);
    if (row != null && row['status'] != 'success') {
      final localUuid = row['local_uuid'] as String;
      await _saveQueuedPicking(
        localUuid: localUuid,
        manifestCode:
            decodeJsonMap(row['payload_json'] as String)['manifest_code']
                    ?.toString() ??
                manifestCode,
        itemId: itemId,
        goodQty: goodQty,
        damagedQty: damagedQty,
        sourceRackId: sourceRackId,
        sourceRack: sourceRack,
        damageNote: damageNote,
        snapshot: snapshot,
        existingRow: row,
      );
      if (await _trySync(localUuid)) {
        await loadManifestDetail(manifestCode);
      }
      return;
    }
    final serverCode = row == null
        ? manifestCode
        : row['server_manifest_code']?.toString() ?? manifestCode;
    try {
      await _repository.updatePicking(
        slug: _tenantSlug,
        manifestCode: serverCode,
        itemId: int.parse(itemId),
        goodQty: goodQty,
        damagedQty: damagedQty,
        sourceRackId: sourceRackId,
        damageNote: damageNote,
      );
      await loadManifestDetail(serverCode);
    } on NetworkException {
      if (snapshot == null) rethrow;
      final localUuid = _offlineManifestId(serverCode);
      await _saveQueuedPicking(
        localUuid: localUuid,
        manifestCode: serverCode,
        itemId: itemId,
        goodQty: goodQty,
        damagedQty: damagedQty,
        sourceRackId: sourceRackId,
        sourceRack: sourceRack,
        damageNote: damageNote,
        snapshot: snapshot,
        existingRow: row != null && row['local_uuid'] == localUuid ? row : null,
      );
      if (await _trySync(localUuid)) {
        await loadManifestDetail(manifestCode);
      }
    }
  }

  Future<bool> commitOutboundApi(
    String manifestCode, {
    OutboundManifestDetail? snapshot,
  }) async {
    final row = await _queueItemForCode(manifestCode);
    if (row != null && row['status'] != 'success') {
      final localUuid = row['local_uuid'] as String;
      final payload = decodeJsonMap(row['payload_json'] as String)
        ..['should_commit'] = true;
      await OfflineDb.saveOutboundProgress(
        localUuid: localUuid,
        tenantSlug: _tenantSlug,
        ownerKey: ownerKey,
        payload: payload,
        metadata: decodeJsonMap(row['metadata_json'] as String),
      );
      final synced = await _trySync(localUuid);
      await loadManifests();
      return synced;
    }

    final serverCode = row?['server_manifest_code']?.toString() ??
        (manifestCode.startsWith('LOCAL-') ? null : manifestCode);
    if (serverCode == null) {
      throw const NetworkException(
        'Manifes outbound lokal harus disinkronkan sebelum commit.',
      );
    }
    try {
      await _repository.commitOutbound(_tenantSlug, serverCode);
      await loadManifests();
      return true;
    } on NetworkException {
      if (snapshot == null || snapshot.items.isEmpty) rethrow;
      final localUuid = _offlineManifestId(serverCode);
      final item = snapshot.items.first;
      await _saveQueuedPicking(
        localUuid: localUuid,
        manifestCode: serverCode,
        itemId: item.id,
        goodQty: item.pickedQty,
        damagedQty: item.damagedQty,
        sourceRackId: item.sourceRackId,
        sourceRack: item.fromRack,
        damageNote: item.notes,
        snapshot: snapshot,
        shouldCommit: true,
        existingRow: row != null && row['local_uuid'] == localUuid ? row : null,
      );
      final synced = await _trySync(localUuid);
      await loadManifests();
      return synced;
    }
  }

  Future<Map<String, Object?>?> _queueItemForCode(String code) async {
    final direct = await OfflineDb.getOutboundQueueItem(
      localUuid: code,
      tenantSlug: _tenantSlug,
      ownerKey: ownerKey,
    );
    if (direct != null) return direct;
    return OfflineDb.getOutboundQueueItem(
      localUuid: _offlineManifestId(code),
      tenantSlug: _tenantSlug,
      ownerKey: ownerKey,
    );
  }

  String _offlineManifestId(String manifestCode) =>
      'OUTBOUND-MANIFEST-$manifestCode';

  Future<void> _saveQueuedPicking({
    required String localUuid,
    required String manifestCode,
    required String itemId,
    required int goodQty,
    required int damagedQty,
    required int? sourceRackId,
    required String? sourceRack,
    required String? damageNote,
    required OutboundManifestDetail? snapshot,
    Map<String, Object?>? existingRow,
    bool shouldCommit = false,
  }) async {
    if (existingRow == null && snapshot == null) {
      throw const NetworkException(
        'Detail manifes outbound belum tersedia untuk disimpan offline.',
      );
    }
    final oldPayload = existingRow == null
        ? <String, dynamic>{}
        : decodeJsonMap(existingRow['payload_json'] as String);
    final oldMetadata = existingRow == null
        ? <String, dynamic>{}
        : decodeJsonMap(existingRow['metadata_json'] as String);
    final metadataItems = (oldMetadata['items'] as List? ??
            snapshot?.items.map(_outboundMetadataItem).toList() ??
            const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final payloadItems = (oldPayload['items'] as List? ??
            snapshot?.items.map(_outboundPayloadItem).toList() ??
            const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    var index = metadataItems.indexWhere(
      (item) => item['id']?.toString() == itemId,
    );
    if (index < 0 && itemId.startsWith('local:')) {
      index = int.tryParse(itemId.replaceFirst('local:', '')) ?? -1;
    }
    if (index < 0 && snapshot != null) {
      index = snapshot.items.indexWhere((item) => item.id == itemId);
    }
    if (index < 0 || index >= payloadItems.length) {
      throw const ServerException('Item manifes outbound tidak ditemukan.');
    }
    var rack = sourceRack;
    if (rack == null && sourceRackId != null) {
      for (final location in snapshot?.locations ?? await _cachedLocations()) {
        if (location.id == sourceRackId) {
          rack = location.rackCode;
          break;
        }
      }
    }
    payloadItems[index] = {
      ...payloadItems[index],
      'good_qty': goodQty,
      'damaged_qty': damagedQty,
      'source_rack_id': sourceRackId == 0 ? null : sourceRackId,
      'source_rack': rack,
      'damage_note': damageNote,
    };
    metadataItems[index] = {
      ...metadataItems[index],
      'good_qty': goodQty,
      'damaged_qty': damagedQty,
      'source_rack_id': sourceRackId == 0 ? null : sourceRackId,
      'source_rack': rack,
      'damage_note': damageNote,
    };
    final manifest = snapshot?.manifest;
    final payload = <String, dynamic>{
      ...oldPayload,
      'manifest_code': manifestCode,
      'local_uuid': localUuid,
      'transaction_uuid': oldPayload['transaction_uuid'] ?? localUuid,
      'should_commit': shouldCommit || oldPayload['should_commit'] == true,
      if (manifest != null && manifest.customerId > 0)
        'customer_id': manifest.customerId,
      'items': payloadItems,
    };
    final metadata = <String, dynamic>{
      ...oldMetadata,
      if (manifest != null) 'customer_name': manifest.customer,
      if (manifest != null) 'status': manifest.status.label,
      if (manifest != null) 'total_units': manifest.totalOrderUnits,
      if (manifest != null) 'vehicle_no': manifest.vehicleNo,
      if (manifest != null) 'driver_name': manifest.driverName,
      if (manifest != null) 'notes': manifest.notes,
      if (snapshot != null)
        'locations':
            snapshot.locations.map((location) => location.toJson()).toList(),
      'items': metadataItems,
    };
    if (existingRow == null) {
      await OfflineDb.enqueueOutbound(
        localUuid: localUuid,
        tenantSlug: _tenantSlug,
        ownerKey: ownerKey,
        payload: payload,
        metadata: metadata,
      );
    } else {
      await OfflineDb.saveOutboundProgress(
        localUuid: localUuid,
        tenantSlug: _tenantSlug,
        ownerKey: ownerKey,
        payload: payload,
        metadata: metadata,
      );
    }
    final savedRow = await OfflineDb.getOutboundQueueItem(
      localUuid: localUuid,
      tenantSlug: _tenantSlug,
      ownerKey: ownerKey,
    );
    if (savedRow != null) {
      _replaceOrder((await _localManifestDetail(savedRow)).manifest);
    }
  }

  Map<String, dynamic> _outboundPayloadItem(OutboundItem item) => {
        'sku_id': item.skuId,
        'so_qty': item.orderQty,
        'good_qty': item.pickedQty,
        'damaged_qty': item.damagedQty,
        if (item.sourceRackId != null) 'source_rack_id': item.sourceRackId,
        if (item.fromRack.isNotEmpty) 'source_rack': item.fromRack,
        if (item.notes != null) 'damage_note': item.notes,
      };

  Map<String, dynamic> _outboundMetadataItem(OutboundItem item) => {
        'id': item.id,
        'sku_id': item.skuId,
        'sku': item.sku,
        'barcode': item.barcode,
        'product_name': item.name,
        'so_qty': item.orderQty,
        'good_qty': item.pickedQty,
        'damaged_qty': item.damagedQty,
        if (item.sourceRackId != null) 'source_rack_id': item.sourceRackId,
        if (item.fromRack.isNotEmpty) 'source_rack': item.fromRack,
        if (item.notes != null) 'damage_note': item.notes,
      };

  Future<bool> _trySync(String localUuid) async {
    final syncDio = dio;
    if (syncDio == null ||
        authToken.isEmpty ||
        !await ConnectivityChecker.instance.isOnline()) {
      return false;
    }
    final result = await SyncManager.instance.syncOutboundQueue(
      dio: syncDio,
      tenantSlug: _tenantSlug,
      ownerKey: ownerKey,
      authToken: authToken,
      localUuid: localUuid,
    );
    return result.syncedCount == 1 && result.failures.isEmpty;
  }

  Future<void> holdManifest(String code, {String? reason}) async {
    final serverCode = await _serverManifestCode(code);
    await _repository.hold(_tenantSlug, serverCode, reason: reason);
    await loadManifests();
  }

  Future<void> resumeManifest(String code) async {
    final serverCode = await _serverManifestCode(code);
    await _repository.resume(_tenantSlug, serverCode);
    await loadManifests();
  }

  Future<String> _serverManifestCode(String localUuid) async {
    final row = await OfflineDb.getOutboundQueueItem(
      localUuid: localUuid,
      tenantSlug: _tenantSlug,
      ownerKey: ownerKey,
    );
    if (row == null) return localUuid;
    if (row['status'] != 'success') {
      throw const NetworkException(
        'Manifes outbound lokal harus disinkronkan sebelum operasi ini.',
      );
    }
    return row['server_manifest_code']?.toString() ?? localUuid;
  }

  Future<List<OutboundOrder>> _loadPendingOrders() async {
    final rows = await OfflineDb.getOutboundManifests(
      tenantSlug: _tenantSlug,
      ownerKey: ownerKey,
    );
    final orders = <OutboundOrder>[];
    for (final row in rows) {
      final detail = await _localManifestDetail(row);
      orders.add(detail.manifest);
    }
    return orders;
  }

  Future<OutboundManifestDetail> _localManifestDetail(
    Map<String, Object?> row,
  ) async {
    final payload = decodeJsonMap(row['payload_json'] as String);
    final metadata = decodeJsonMap(row['metadata_json'] as String);
    final rawPayloadItems = payload['items'] as List? ?? const [];
    final rawMetadataItems = metadata['items'] as List? ?? const [];
    final items = <OutboundItem>[];
    for (var index = 0; index < rawPayloadItems.length; index++) {
      final payloadItem = Map<String, dynamic>.from(
        rawPayloadItems[index] as Map,
      );
      final metadataItem = index < rawMetadataItems.length
          ? Map<String, dynamic>.from(rawMetadataItems[index] as Map)
          : <String, dynamic>{};
      items.add(
        OutboundItem.fromJson({
          ...metadataItem,
          ...payloadItem,
          'id': metadataItem['id']?.toString() ?? 'local:$index',
        }),
      );
    }
    final metadataLocations = metadata['locations'] as List? ?? const [];
    final locationMaps = metadataLocations
        .whereType<Map>()
        .map((item) =>
            OutboundLocation.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final locations =
        locationMaps.isEmpty ? await _cachedLocations() : locationMaps;
    final localUuid = row['local_uuid'] as String;
    final customerName = metadata['customer_name']?.toString() ?? 'Customer';
    final manifestCode = payload['manifest_code']?.toString() ?? localUuid;
    final order = OutboundOrder(
      code: manifestCode,
      customer: customerName,
      customerId: int.tryParse(payload['customer_id'].toString()) ?? 0,
      vehicleNo: (payload['vehicle_no'] ?? metadata['vehicle_no'])?.toString(),
      driverName:
          (payload['driver_name'] ?? metadata['driver_name'])?.toString(),
      notes: (payload['notes'] ?? metadata['notes'])?.toString(),
      totalUnits: items.fold<int>(0, (total, item) => total + item.orderQty),
      totalSkus: items.length,
      destination: '',
      expedition: payload['vehicle_no']?.toString() ?? '',
      stagingBay: '-',
      status: OutboundStatus.fromString(metadata['status']?.toString()),
      items: items,
      startedAt: row['created_at']?.toString(),
      isOfflinePending: row['status'] != 'success',
      localId: localUuid,
      syncError: row['error_message']?.toString(),
    );
    return OutboundManifestDetail(
      manifest: order,
      items: items,
      locations: locations,
    );
  }

  Future<void> _cacheLocations(List<OutboundLocation> locations) async {
    final cached = await OfflineDb.getCachedOutboundOptions(
          tenantSlug: _tenantSlug,
          ownerKey: ownerKey,
        ) ??
        <String, dynamic>{};
    cached['locations'] =
        locations.map((location) => location.toJson()).toList();
    await OfflineDb.cacheOutboundOptions(
      tenantSlug: _tenantSlug,
      ownerKey: ownerKey,
      options: cached,
    );
  }

  Future<List<OutboundLocation>> _cachedLocations() async {
    final cached = await OfflineDb.getCachedOutboundOptions(
      tenantSlug: _tenantSlug,
      ownerKey: ownerKey,
    );
    if (cached == null) return const [];
    final rawLocations = cached['locations'] as List? ?? const [];
    final parsed = rawLocations
        .whereType<Map>()
        .map(
          (item) => OutboundLocation.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    if (parsed.isNotEmpty) return parsed;
    final racks = cached['available_racks'] as List? ?? const [];
    return racks
        .map((rack) => OutboundLocation(id: 0, rackCode: rack.toString()))
        .where((location) => location.rackCode.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _masterOptionsJson(OutboundMasterOptions options) => {
        'customers': options.customers
            .map(
                (item) => {'id': item.id, 'name': item.name, 'code': item.code})
            .toList(),
        'products': options.products
            .map(
              (item) => {
                'sku_id': item.skuId,
                'product_id': item.productId,
                'sku': item.sku,
                'barcode': item.barcode,
                'name': item.name,
                'available_stock': item.availableStock,
                'unit': item.unit,
              },
            )
            .toList(),
        'locations': options.locations.map((item) => item.toJson()).toList(),
        'available_racks': options.availableRacks,
      };

  OutboundMasterOptions _masterOptionsFromJson(Map<String, dynamic> json) {
    final customers = (json['customers'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => OutboundCustomer.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    final products = (json['products'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              OutboundProductMaster.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    final locations = (json['locations'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => OutboundLocation.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    final availableRacks = (json['available_racks'] as List? ?? const [])
        .map((item) => item.toString())
        .toList();
    return OutboundMasterOptions(
      customers: customers,
      products: products,
      locations: locations,
      availableRacks: availableRacks,
    );
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
    tenantSlug: authState.tenantSlug ?? authState.tenantName ?? 'demo-tenant',
    ownerKey: offlineOwnerKey(
      userId: authState.userId,
      token: authState.token ?? 'unauthenticated',
    ),
    dio: ref.watch(dioProvider),
    authToken: authState.token ?? '',
  );
});

final outboundStatsProvider = Provider<OutboundStats>((ref) {
  ref.watch(outboundRepositoryProvider);
  return ref.read(outboundRepositoryProvider.notifier).stats;
});
