import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'outbound_model.dart';

class OutboundNotifier extends StateNotifier<List<OutboundOrder>> {
  OutboundNotifier([List<OutboundOrder>? initialOrders])
      : super(initialOrders ?? const []);

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
    todayTotal: orders.length,
    picking: pickingCount + readyCount,
    readyToDispatch: packingCount,
    dispatched: dispatchedCount,
  );
});
