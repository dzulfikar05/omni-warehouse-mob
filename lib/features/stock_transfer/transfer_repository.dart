import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/offline/sync_manager.dart';
import 'transfer_model.dart';

class TransferNotifier extends StateNotifier<List<StockTransferItem>> {
  TransferNotifier() : super(_initialTransfers);

  static final List<StockTransferItem> _initialTransfers = [
    StockTransferItem(
      id: 'trf-101',
      referenceNumber: 'TRF-2026-0412',
      type: TransferType.binToBin,
      sku: 'SKU-EL-091',
      barcode: '8991234509101',
      productName: 'Kabel Fiber Optic Drop Core 100m',
      fromLocation: 'RACK-A1-01',
      toLocation: 'RACK-B1-02',
      quantity: 50,
      unit: 'Roll',
      status: TransferStatus.completed,
      createdAt: '10:45 WIB',
      operatorName: 'Budi Santoso',
      notes: 'Penataan stok ulang untuk kemudahan picking harian',
      availableStock: 200,
    ),
    StockTransferItem(
      id: 'trf-102',
      referenceNumber: 'TRF-2026-0415',
      type: TransferType.interWarehouse,
      sku: 'SKU-ME-110',
      barcode: '8991234501101',
      productName: 'Panel MCB 3 Phase 63A Sch-Electric',
      fromLocation: 'Gudang Utama Malang',
      toLocation: 'Cabang Surabaya Rungkut',
      quantity: 15,
      unit: 'Box',
      status: TransferStatus.inTransit,
      createdAt: '09:20 WIB',
      operatorName: 'Ahmad Dahlan',
      notes: 'Surat Jalan SJ-TRF-094 via Ekspedisi Lalamove',
      availableStock: 40,
    ),
    StockTransferItem(
      id: 'trf-103',
      referenceNumber: 'REP-2026-0104',
      type: TransferType.replenishment,
      sku: 'SKU-NT-008',
      barcode: '8991234503011',
      productName: 'Patch Cord SC/UPC-SC/APC 3M Simplex',
      fromLocation: 'Gudang Belakang',
      toLocation: 'Display Etalase Depan',
      quantity: 20,
      unit: 'Koli',
      status: TransferStatus.completed,
      createdAt: '08:10 WIB',
      operatorName: 'Siti Aminah',
      notes: 'Restock etalase pajangan kasir UMKM',
      availableStock: 80,
    ),
    StockTransferItem(
      id: 'trf-104',
      referenceNumber: 'TRF-2026-0418',
      type: TransferType.binToBin,
      sku: 'SKU-EL-092',
      barcode: '8991234509102',
      productName: 'Optical Distribution Point (ODP) 16P',
      fromLocation: 'RACK-A1-02',
      toLocation: 'RACK-A2-01',
      quantity: 10,
      unit: 'Unit',
      status: TransferStatus.draft,
      createdAt: 'Kemarin',
      operatorName: 'Budi Santoso',
      notes: 'Siap verifikasi scan rak tujuan',
      availableStock: 75,
    ),
  ];

  StockTransferItem? getTransferById(String id) {
    try {
      return state.firstWhere((t) => t.id == id || t.referenceNumber == id);
    } catch (_) {
      return null;
    }
  }

  void addTransfer(StockTransferItem item) {
    state = [item, ...state];

    // Enqueue to offline sync manager
    try {
      final syncItem = SyncQueueItem(
        id: 'sync-${item.referenceNumber}-${DateTime.now().millisecondsSinceEpoch}',
        type: SyncTransactionType.stockTransfer,
        payload: {
          'local_uuid': item.referenceNumber,
          'transaction_type': 'TRANSFER',
          'transfer_type': item.type.name,
          'sku': item.sku,
          'barcode': item.barcode,
          'from_location': item.fromLocation,
          'to_location': item.toLocation,
          'quantity': item.quantity,
          'operator': item.operatorName,
          'status': item.status.name,
          'notes': item.notes ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        },
        createdAt: DateTime.now(),
      );
      SyncManager.instance.enqueue(syncItem).catchError((_) {});
    } catch (_) {
      // Ignore offline queue failures in sandbox/test environments
    }
  }

  void updateTransferStatus(String id, TransferStatus newStatus) {
    state = [
      for (final item in state)
        if (item.id == id || item.referenceNumber == id)
          item.copyWith(status: newStatus)
        else
          item,
    ];
  }
}

final transferRepositoryProvider =
    StateNotifierProvider<TransferNotifier, List<StockTransferItem>>((ref) {
  return TransferNotifier();
});

final transferStatsProvider = Provider<TransferStats>((ref) {
  final items = ref.watch(transferRepositoryProvider);
  final completed = items.where((t) => t.status == TransferStatus.completed).length;
  final inTransit = items.where((t) => t.status == TransferStatus.inTransit).length;

  return TransferStats(
    todayTotal: items.length,
    completed: completed,
    inTransit: inTransit,
  );
});
