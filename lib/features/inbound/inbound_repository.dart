import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_endpoints.dart';
import 'inbound_model.dart';

/// Contract repository abstrak untuk operasi Inbound
abstract class InboundRepository {
  List<InboundManifest> getInitialManifests() => const [];
  Future<List<InboundManifest>> getManifests();
  Future<InboundManifest?> getManifestByCode(String code);
  Future<void> submitPutaway(PutawayRequest req);
  Future<void> commitManifest(String code);
  Future<void> addAdhocManifest(InboundManifest manifest);
}

/// Implementasi Mock dinamis untuk development dan offline testing
class MockInboundRepository implements InboundRepository {
  final List<InboundManifest> _mockManifests = [];

  @override
  List<InboundManifest> getInitialManifests() => List.from(_mockManifests);

  @override
  Future<List<InboundManifest>> getManifests() async {
    await Future.delayed(const Duration(milliseconds: 250));
    return List.from(_mockManifests);
  }

  @override
  Future<InboundManifest?> getManifestByCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      return _mockManifests.firstWhere(
        (m) => m.code.toLowerCase() == code.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> submitPutaway(PutawayRequest req) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final manifestIdx = _mockManifests.indexWhere(
      (m) => m.code.toLowerCase() == req.manifestCode.toLowerCase(),
    );
    if (manifestIdx != -1) {
      final manifest = _mockManifests[manifestIdx];
      final updatedItems = manifest.items.map((it) {
        if (it.id == req.itemId) {
          return it.copyWith(
            goodQty: req.goodQty,
            damagedQty: req.damagedQty,
            targetRack: req.targetRack ?? it.targetRack,
            notes: req.notes ?? it.notes,
          );
        }
        return it;
      }).toList();

      _mockManifests[manifestIdx] = InboundManifest(
        code: manifest.code,
        supplier: manifest.supplier,
        warehouse: manifest.warehouse,
        dockBay: manifest.dockBay,
        totalUnits: manifest.totalUnits,
        status: InboundStatus.receiving,
        startedAt: manifest.startedAt ?? 'Hari ini',
        truckPlate: manifest.truckPlate,
        driverName: manifest.driverName,
        isAdhoc: manifest.isAdhoc,
        items: updatedItems,
      );
    }
  }

  @override
  Future<void> commitManifest(String code) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final manifestIdx = _mockManifests.indexWhere(
      (m) => m.code.toLowerCase() == code.toLowerCase(),
    );
    if (manifestIdx != -1) {
      final manifest = _mockManifests[manifestIdx];
      _mockManifests[manifestIdx] = InboundManifest(
        code: manifest.code,
        supplier: manifest.supplier,
        warehouse: manifest.warehouse,
        dockBay: manifest.dockBay,
        totalUnits: manifest.totalUnits,
        status: InboundStatus.closed,
        startedAt: manifest.startedAt,
        completedAt: 'Baru saja',
        truckPlate: manifest.truckPlate,
        driverName: manifest.driverName,
        isAdhoc: manifest.isAdhoc,
        items: manifest.items,
      );
    }
  }

  @override
  Future<void> addAdhocManifest(InboundManifest manifest) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _mockManifests.insert(0, manifest);
  }
}

/// Implementasi Real API Laravel (terhubung via Dio dan ApiEndpoints)
class ApiInboundRepository implements InboundRepository {
  final Dio _dio;

  ApiInboundRepository(this._dio);

  @override
  List<InboundManifest> getInitialManifests() => const [];

  @override
  Future<List<InboundManifest>> getManifests() async {
    final response = await _dio.get(ApiEndpoints.inboundList);
    final data = response.data;
    final List list = (data is Map && data['data'] is List)
        ? data['data'] as List
        : (data is List ? data : []);
    return list.map((e) => InboundManifest.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  @override
  Future<InboundManifest?> getManifestByCode(String code) async {
    final response = await _dio.get(ApiEndpoints.inboundDetail(code));
    final data = response.data;
    final itemMap = (data is Map && data['data'] is Map)
        ? data['data'] as Map
        : (data is Map ? data : null);
    if (itemMap == null) return null;
    return InboundManifest.fromJson(Map<String, dynamic>.from(itemMap));
  }

  @override
  Future<void> submitPutaway(PutawayRequest req) async {
    await _dio.post(ApiEndpoints.inboundPutaway, data: req.toJson());
  }

  @override
  Future<void> commitManifest(String code) async {
    await _dio.post(ApiEndpoints.inboundCommit, data: {'manifest_code': code});
  }

  @override
  Future<void> addAdhocManifest(InboundManifest manifest) async {
    await _dio.post(ApiEndpoints.inboundList, data: manifest.toJson());
  }
}

/// Switcher Provider Repository (cukup ganti ke ApiInboundRepository saat backend live)
final inboundDataSourceProvider = Provider<InboundRepository>((ref) {
  // Gunakan MockInboundRepository untuk development dinamis:
  return MockInboundRepository();
  // Untuk real backend Laravel:
  // return ApiInboundRepository(ref.watch(dioProvider));
});

/// Notifier State untuk Inbound List yang sinkron dengan Repository
class InboundNotifier extends StateNotifier<List<InboundManifest>> {
  final InboundRepository _repository;

  InboundNotifier(this._repository) : super(_repository.getInitialManifests());

  Future<void> loadManifests() async {
    final manifests = await _repository.getManifests();
    state = manifests;
  }

  InboundManifest? getManifestByCode(String code) {
    try {
      return state.firstWhere((m) => m.code.toLowerCase() == code.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  void updateItemTally({
    required String manifestCode,
    required String itemId,
    required int goodQty,
    required int damagedQty,
    String? targetRack,
  }) {
    // 1. Optimistic UI update
    state = [
      for (final manifest in state)
        if (manifest.code == manifestCode)
          InboundManifest(
            code: manifest.code,
            supplier: manifest.supplier,
            warehouse: manifest.warehouse,
            dockBay: manifest.dockBay,
            totalUnits: manifest.totalUnits,
            status: InboundStatus.receiving,
            startedAt: manifest.startedAt ?? 'Hari ini',
            truckPlate: manifest.truckPlate,
            driverName: manifest.driverName,
            isAdhoc: manifest.isAdhoc,
            items: [
              for (final item in manifest.items)
                if (item.id == itemId)
                  item.copyWith(
                    goodQty: goodQty,
                    damagedQty: damagedQty,
                    targetRack: targetRack ?? item.targetRack,
                  )
                else
                  item,
            ],
          )
        else
          manifest,
    ];

    // 2. Persist to repository
    _repository.submitPutaway(
      PutawayRequest(
        manifestCode: manifestCode,
        itemId: itemId,
        goodQty: goodQty,
        damagedQty: damagedQty,
        targetRack: targetRack,
      ),
    );
  }

  void commitManifest(String manifestCode) {
    // 1. Optimistic UI update
    state = [
      for (final manifest in state)
        if (manifest.code == manifestCode)
          InboundManifest(
            code: manifest.code,
            supplier: manifest.supplier,
            warehouse: manifest.warehouse,
            dockBay: manifest.dockBay,
            totalUnits: manifest.totalUnits,
            status: InboundStatus.closed,
            startedAt: manifest.startedAt,
            completedAt: 'Baru saja',
            truckPlate: manifest.truckPlate,
            driverName: manifest.driverName,
            isAdhoc: manifest.isAdhoc,
            items: manifest.items,
          )
        else
          manifest,
    ];

    // 2. Persist to repository
    _repository.commitManifest(manifestCode);
  }

  void addAdhocManifest(InboundManifest newManifest) {
    state = [newManifest, ...state];
    _repository.addAdhocManifest(newManifest);
  }
}

/// Provider state notifier untuk Inbound (digunakan di InboundListScreen & InboundScannerScreen)
final inboundRepositoryProvider =
    StateNotifierProvider<InboundNotifier, List<InboundManifest>>((ref) {
  final repo = ref.watch(inboundDataSourceProvider);
  return InboundNotifier(repo);
});

/// Alias provider
final inboundNotifierProvider = inboundRepositoryProvider;

final inboundStatsProvider = Provider<InboundStats>((ref) {
  final manifests = ref.watch(inboundNotifierProvider);
  final receivingCount = manifests.where((m) => m.status == InboundStatus.receiving).length;
  final closedCount = manifests.where((m) => m.status == InboundStatus.closed).length;
  final draftCount = manifests.where((m) => m.status == InboundStatus.draft).length;
  final holdCount = manifests.where((m) => m.status == InboundStatus.hold).length;

  return InboundStats(
    todayTotal: manifests.length,
    inProgress: receivingCount + draftCount,
    completed: closedCount,
    hold: holdCount,
  );
});
