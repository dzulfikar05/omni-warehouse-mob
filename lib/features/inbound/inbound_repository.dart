import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'inbound_model.dart';

class InboundNotifier extends StateNotifier<List<InboundManifest>> {
  InboundNotifier() : super(_initialManifests);

  static final List<InboundManifest> _initialManifests = [
    InboundManifest(
      code: 'PO-2026-1042',
      supplier: 'PT. Triputra Fiber',
      warehouse: 'Gudang Utama Malang',
      dockBay: 'Dock Bay 04',
      totalUnits: 450,
      status: InboundStatus.receiving,
      startedAt: '09:15 WIB',
      truckPlate: 'N 8841 AB',
      driverName: 'Slamet Raharjo',
      items: [
        InboundItem(
          id: 'item-101',
          sku: 'SKU-EL-091',
          barcode: '8991234509101',
          name: 'Kabel Fiber Optic Drop Core 100m',
          expectedQty: 250,
          goodQty: 200,
          damagedQty: 0,
          targetRack: 'RACK-A1-01',
          unit: 'Roll',
          category: 'Kabel & Aksesoris',
        ),
        InboundItem(
          id: 'item-102',
          sku: 'SKU-EL-092',
          barcode: '8991234509102',
          name: 'Optical Distribution Point (ODP) 16P',
          expectedQty: 100,
          goodQty: 75,
          damagedQty: 2,
          targetRack: 'RACK-A1-02',
          unit: 'Unit',
          category: 'Perangkat Distribusi',
        ),
        InboundItem(
          id: 'item-103',
          sku: 'SKU-EL-093',
          barcode: '8991234509103',
          name: 'Splicer Protective Sleeve 60mm',
          expectedQty: 100,
          goodQty: 38,
          damagedQty: 0,
          targetRack: 'RACK-A2-01',
          unit: 'Pack',
          category: 'Konsumabel',
        ),
      ],
    ),
    InboundManifest(
      code: 'PO-2026-1040',
      supplier: 'CV. Megah Elektrik',
      warehouse: 'Gudang Utama Malang',
      dockBay: 'Dock Bay 02',
      totalUnits: 120,
      status: InboundStatus.draft,
      truckPlate: 'W 9012 UZ',
      driverName: 'Bambang Irawan',
      items: [
        InboundItem(
          id: 'item-201',
          sku: 'SKU-ME-110',
          barcode: '8991234501101',
          name: 'Panel MCB 3 Phase 63A Sch-Electric',
          expectedQty: 40,
          goodQty: 0,
          damagedQty: 0,
          targetRack: 'RACK-B1-01',
          unit: 'Box',
          category: 'Panel Elektrik',
        ),
        InboundItem(
          id: 'item-202',
          sku: 'SKU-ME-115',
          barcode: '8991234501152',
          name: 'Kabel NYM 3x2.5mm Supreme 50m',
          expectedQty: 80,
          goodQty: 0,
          damagedQty: 0,
          targetRack: 'RACK-B1-02',
          unit: 'Roll',
          category: 'Kabel & Aksesoris',
        ),
      ],
    ),
    InboundManifest(
      code: 'PO-2026-1038',
      supplier: 'PT. Nartel Nusantara',
      warehouse: 'Gudang Utama Malang',
      dockBay: 'Dock Bay 01',
      totalUnits: 80,
      status: InboundStatus.closed,
      startedAt: '07:30 WIB',
      completedAt: '08:45 WIB',
      truckPlate: 'L 7421 OP',
      driverName: 'Agus Subekti',
      items: [
        InboundItem(
          id: 'item-301',
          sku: 'SKU-NT-008',
          barcode: '8991234503011',
          name: 'Patch Cord SC/UPC-SC/APC 3M Simplex',
          expectedQty: 80,
          goodQty: 80,
          damagedQty: 0,
          targetRack: 'RACK-B-04 s/d B-08',
          unit: 'Koli',
          category: 'Aksesoris Fiber',
        ),
      ],
    ),
  ];

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
  }

  void commitManifest(String manifestCode) {
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
  }

  void addAdhocManifest(InboundManifest newManifest) {
    state = [newManifest, ...state];
  }
}

final inboundRepositoryProvider =
    StateNotifierProvider<InboundNotifier, List<InboundManifest>>((ref) {
  return InboundNotifier();
});

final inboundStatsProvider = Provider<InboundStats>((ref) {
  final manifests = ref.watch(inboundRepositoryProvider);
  final receivingCount = manifests.where((m) => m.status == InboundStatus.receiving).length;
  final closedCount = manifests.where((m) => m.status == InboundStatus.closed).length;
  final draftCount = manifests.where((m) => m.status == InboundStatus.draft).length;
  final holdCount = manifests.where((m) => m.status == InboundStatus.hold).length;

  return InboundStats(
    todayTotal: manifests.length + 9, // Total 12 harian
    inProgress: receivingCount + draftCount,
    completed: closedCount,
    hold: holdCount,
  );
});
