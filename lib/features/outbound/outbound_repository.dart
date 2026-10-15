import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'outbound_model.dart';

class OutboundNotifier extends StateNotifier<List<OutboundOrder>> {
  OutboundNotifier() : super(_initialOrders);

  static final List<OutboundOrder> _initialOrders = [
    OutboundOrder(
      code: 'DO-2026-8819',
      waveId: 'Wave Pick #W-104',
      customer: 'Toko Maju Bersama',
      destination: 'Jl. Ahmad Yani No. 88, Surabaya',
      expedition: 'SiCepat Cargo Express',
      stagingBay: 'Staging S-01',
      status: OutboundStatus.picking,
      startedAt: '10:15 WIB',
      trackingNumber: '003291882190',
      items: [
        OutboundItem(
          id: 'item-801',
          sku: 'SKU-ME-110',
          barcode: '8991234501101',
          name: 'Panel MCB 3 Phase 63A Sch-Electric',
          fromRack: 'RACK-B1-01',
          orderQty: 40,
          pickedQty: 25,
          packedQty: 20,
          unit: 'Box',
          category: 'Elektrikal',
        ),
        OutboundItem(
          id: 'item-802',
          sku: 'SKU-ME-115',
          barcode: '8991234501152',
          name: 'Kabel NYM 3x2.5mm Supreme 50m',
          fromRack: 'RACK-B1-02',
          orderQty: 50,
          pickedQty: 40,
          packedQty: 35,
          unit: 'Roll',
          category: 'Kabel & Kawat',
        ),
        OutboundItem(
          id: 'item-803',
          sku: 'SKU-EL-091',
          barcode: '8991234509101',
          name: 'Kabel Fiber Optic Drop Core 100m',
          fromRack: 'RACK-A1-01',
          orderQty: 30,
          pickedQty: 20,
          packedQty: 20,
          unit: 'Roll',
          category: 'Aksesoris Fiber',
        ),
      ],
    ),
    OutboundOrder(
      code: 'SO-2025-1102',
      customer: 'PT Berkah Retail Jaya',
      destination: 'Komplek Pergudangan Margomulyo Indah Blok C-12',
      expedition: 'Armada Truk Logistik Sendiri',
      stagingBay: 'Staging S-02',
      status: OutboundStatus.readyToPick,
      trackingNumber: 'SJ-2025-1102-OUT',
      items: [
        OutboundItem(
          id: 'item-901',
          sku: 'SKU-EL-092',
          barcode: '8991234509102',
          name: 'Optical Distribution Point (ODP) 16P',
          fromRack: 'RACK-A1-02',
          orderQty: 50,
          pickedQty: 0,
          packedQty: 0,
          unit: 'Unit',
          category: 'Perangkat Jaringan',
        ),
        OutboundItem(
          id: 'item-902',
          sku: 'SKU-NT-008',
          barcode: '8991234503011',
          name: 'Patch Cord SC/UPC-SC/APC 3M Simplex',
          fromRack: 'RACK-B-04',
          orderQty: 100,
          pickedQty: 0,
          packedQty: 0,
          unit: 'Koli',
          category: 'Aksesoris Fiber',
        ),
      ],
    ),
    OutboundOrder(
      code: 'DO-2026-8815',
      customer: 'CV Mandiri Abadi Perkasa',
      destination: 'Jl. Raya Singosari No. 45, Malang',
      expedition: 'J&T Cargo',
      stagingBay: 'Staging S-03',
      status: OutboundStatus.dispatched,
      startedAt: '08:30 WIB',
      dispatchedAt: '10:15 WIB',
      trackingNumber: 'JT9928190012',
      items: [
        OutboundItem(
          id: 'item-701',
          sku: 'SKU-EL-093',
          barcode: '8991234509103',
          name: 'Splicer Protective Sleeve 60mm',
          fromRack: 'RACK-A2-01',
          orderQty: 80,
          pickedQty: 80,
          packedQty: 80,
          unit: 'Pack',
          category: 'Konsumabel',
        ),
      ],
    ),
  ];

  OutboundOrder? getOrderByCode(String code) {
    try {
      return state.firstWhere((o) => o.code.toLowerCase() == code.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  void updateItemPickAndPack({
    required String orderCode,
    required String itemId,
    required int pickedQty,
    required int packedQty,
  }) {
    state = [
      for (final order in state)
        if (order.code == orderCode)
          OutboundOrder(
            code: order.code,
            waveId: order.waveId,
            customer: order.customer,
            destination: order.destination,
            expedition: order.expedition,
            stagingBay: order.stagingBay,
            status: OutboundStatus.picking,
            startedAt: order.startedAt ?? 'Hari ini',
            dispatchedAt: order.dispatchedAt,
            trackingNumber: order.trackingNumber,
            isAdhocExpress: order.isAdhocExpress,
            items: [
              for (final item in order.items)
                if (item.id == itemId)
                  item.copyWith(pickedQty: pickedQty, packedQty: packedQty)
                else
                  item,
            ],
          )
        else
          order,
    ];
  }

  void batchCheckAllItems(String orderCode) {
    state = [
      for (final order in state)
        if (order.code == orderCode)
          OutboundOrder(
            code: order.code,
            waveId: order.waveId,
            customer: order.customer,
            destination: order.destination,
            expedition: order.expedition,
            stagingBay: order.stagingBay,
            status: OutboundStatus.packing,
            startedAt: order.startedAt ?? 'Hari ini',
            dispatchedAt: order.dispatchedAt,
            trackingNumber: order.trackingNumber,
            isAdhocExpress: order.isAdhocExpress,
            items: [
              for (final item in order.items)
                item.copyWith(
                  pickedQty: item.orderQty,
                  packedQty: item.orderQty,
                ),
            ],
          )
        else
          order,
    ];
  }

  void commitDispatch(String orderCode) {
    state = [
      for (final order in state)
        if (order.code == orderCode)
          OutboundOrder(
            code: order.code,
            waveId: order.waveId,
            customer: order.customer,
            destination: order.destination,
            expedition: order.expedition,
            stagingBay: order.stagingBay,
            status: OutboundStatus.dispatched,
            startedAt: order.startedAt,
            dispatchedAt: 'Baru saja',
            trackingNumber: order.trackingNumber,
            isAdhocExpress: order.isAdhocExpress,
            items: order.items,
          )
        else
          order,
    ];
  }

  void addQuickStockOut(OutboundOrder quickOrder) {
    state = [quickOrder, ...state];
  }
}

final outboundRepositoryProvider =
    StateNotifierProvider<OutboundNotifier, List<OutboundOrder>>((ref) {
  return OutboundNotifier();
});

final outboundStatsProvider = Provider<OutboundStats>((ref) {
  final orders = ref.watch(outboundRepositoryProvider);
  final pickingCount = orders.where((o) => o.status == OutboundStatus.picking).length;
  final packingCount = orders.where((o) => o.status == OutboundStatus.packing).length;
  final readyCount = orders.where((o) => o.status == OutboundStatus.readyToPick).length;
  final dispatchedCount = orders.where((o) => o.status == OutboundStatus.dispatched).length;

  return OutboundStats(
    todayTotal: orders.length + 15, // Total harian 18
    picking: pickingCount + readyCount,
    readyToDispatch: packingCount + 5,
    dispatched: dispatchedCount,
  );
});
