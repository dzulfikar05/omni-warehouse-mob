import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/offline/sync_manager.dart';
import 'opname_model.dart';

class OpnameNotifier extends StateNotifier<List<OpnameSession>> {
  OpnameNotifier() : super(_initialSessions);

  static final List<OpnameSession> _initialSessions = [
    OpnameSession(
      sessionCode: 'SOP-2026-1001',
      title: 'Cycle Count Rak A1 & A2 (Elektrik & Fiber)',
      warehouseName: 'Gudang Utama Malang',
      zone: 'Zona A - Fiber & Network',
      status: OpnameSessionStatus.active,
      assignedOperator: 'Budi Santoso',
      createdAt: '16 Okt 2026, 08:00 WIB',
      isBlindCount: true,
      items: [
        OpnameItem(
          id: 'opn-item-01',
          sku: 'SKU-EL-091',
          barcode: '8991234509101',
          name: 'Kabel Fiber Optic Drop Core 100m',
          category: 'Kabel & Aksesoris',
          rack: 'RACK-A1-01',
          systemQty: 200,
          physicalQty: 200,
          unit: 'Roll',
          scannedAt: '08:45 WIB',
        ),
        OpnameItem(
          id: 'opn-item-02',
          sku: 'SKU-EL-092',
          barcode: '8991234509102',
          name: 'Optical Distribution Point (ODP) 16P',
          category: 'Perangkat Distribusi',
          rack: 'RACK-A1-02',
          systemQty: 75,
          physicalQty: 73,
          unit: 'Unit',
          notes: '2 unit pecah fisik di sudut bawah rak',
          scannedAt: '09:12 WIB',
        ),
        OpnameItem(
          id: 'opn-item-03',
          sku: 'SKU-EL-093',
          barcode: '8991234509103',
          name: 'Splicer Protective Sleeve 60mm',
          category: 'Konsumabel',
          rack: 'RACK-A2-01',
          systemQty: 38,
          physicalQty: null, // belum dihitung
          unit: 'Pack',
        ),
      ],
    ),
    OpnameSession(
      sessionCode: 'SOP-2026-1002',
      title: 'Cek Stok Harian Etalase Kasir (UMKM Fast)',
      warehouseName: 'Toko Cabang Dinoyo',
      zone: 'Etalase Depan',
      status: OpnameSessionStatus.active,
      assignedOperator: 'Siti Aminah',
      createdAt: '16 Okt 2026, 17:30 WIB',
      isBlindCount: false,
      isAdhoc: true,
      items: [
        OpnameItem(
          id: 'opn-item-11',
          sku: 'SKU-NT-008',
          barcode: '8991234503011',
          name: 'Patch Cord SC/UPC-SC/APC 3M Simplex',
          category: 'Aksesoris Fiber',
          rack: 'Display Etalase Depan',
          systemQty: 20,
          physicalQty: 20,
          unit: 'Koli',
          scannedAt: '17:40 WIB',
        ),
        OpnameItem(
          id: 'opn-item-12',
          sku: 'SKU-ME-110',
          barcode: '8991234501101',
          name: 'Panel MCB 3 Phase 63A Sch-Electric',
          category: 'Panel Elektrik',
          rack: 'Rak Kasir Utama',
          systemQty: 5,
          physicalQty: null,
          unit: 'Box',
        ),
      ],
    ),
    OpnameSession(
      sessionCode: 'SOP-2026-0925',
      title: 'Full Audit Akhir Bulan September 2026',
      warehouseName: 'Gudang Utama Malang',
      zone: 'Seluruh Gudang',
      status: OpnameSessionStatus.completed,
      assignedOperator: 'Tim Audit Internal',
      createdAt: '30 Sep 2026',
      items: [
        OpnameItem(
          id: 'opn-item-91',
          sku: 'SKU-ME-115',
          barcode: '8991234501152',
          name: 'Kabel NYM 3x2.5mm Supreme 50m',
          category: 'Kabel & Aksesoris',
          rack: 'RACK-B1-02',
          systemQty: 80,
          physicalQty: 80,
          unit: 'Roll',
          scannedAt: '30 Sep 2026',
        ),
      ],
    ),
  ];

  OpnameSession? getSessionByCode(String code) {
    try {
      return state.firstWhere((s) => s.sessionCode.toLowerCase() == code.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  void updateItemPhysicalCount({
    required String sessionCode,
    required String itemId,
    required int physicalQty,
    String? notes,
  }) {
    state = [
      for (final session in state)
        if (session.sessionCode.toLowerCase() == sessionCode.toLowerCase())
          session.copyWith(
            items: [
              for (final item in session.items)
                if (item.id == itemId)
                  item.copyWith(
                    physicalQty: physicalQty,
                    notes: notes ?? item.notes,
                    scannedAt: 'Baru saja',
                  )
                else
                  item,
            ],
          )
        else
          session,
    ];

    // Enqueue to offline sync manager
    try {
      final syncItem = SyncQueueItem(
        id: 'sync-opname-$sessionCode-$itemId-${DateTime.now().millisecondsSinceEpoch}',
        type: SyncTransactionType.opnameCount,
        payload: {
          'session_code': sessionCode,
          'item_id': itemId,
          'physical_qty': physicalQty,
          'notes': notes ?? '',
          'operator': 'Budi Santoso',
          'timestamp': DateTime.now().toIso8601String(),
        },
        createdAt: DateTime.now(),
      );
      SyncManager.instance.enqueue(syncItem).catchError((_) {});
    } catch (_) {
      // Ignore offline queue failures in tests/sandboxes
    }
  }

  void submitSessionForReconciliation(String sessionCode) {
    state = [
      for (final session in state)
        if (session.sessionCode.toLowerCase() == sessionCode.toLowerCase())
          session.copyWith(status: OpnameSessionStatus.reconciling)
        else
          session,
    ];
  }

  void addQuickSession(OpnameSession session) {
    state = [session, ...state];
  }
}

final opnameRepositoryProvider =
    StateNotifierProvider<OpnameNotifier, List<OpnameSession>>((ref) {
  return OpnameNotifier();
});

final opnameStatsProvider = Provider<OpnameStats>((ref) {
  final sessions = ref.watch(opnameRepositoryProvider);
  final activeSessions = sessions.where((s) => s.status == OpnameSessionStatus.active).length;

  int counted = 0;
  int discrepancies = 0;

  for (final s in sessions) {
    counted += s.countedItems;
    discrepancies += s.discrepancyCount;
  }

  return OpnameStats(
    activeSessions: activeSessions,
    totalItemsCounted: counted,
    discrepancyCount: discrepancies,
  );
});
