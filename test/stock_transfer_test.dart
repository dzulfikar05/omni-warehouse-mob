import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/core/theme/app_theme.dart';
import 'package:omni_warehouse_mob/features/stock_transfer/transfer_form_screen.dart';
import 'package:omni_warehouse_mob/features/stock_transfer/transfer_list_screen.dart';
import 'package:omni_warehouse_mob/features/stock_transfer/transfer_model.dart';
import 'package:omni_warehouse_mob/features/stock_transfer/transfer_repository.dart';

void main() {
  group('TransferNotifier & State Management', () {
    test('initial state has default mock transfers and correct stats', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final items = container.read(transferRepositoryProvider);
      final stats = container.read(transferStatsProvider);

      expect(items.isNotEmpty, true);
      expect(stats.todayTotal, items.length);
      expect(stats.completed, items.where((t) => t.status == TransferStatus.completed).length);
      expect(stats.inTransit, items.where((t) => t.status == TransferStatus.inTransit).length);
    });

    test('addTransfer adds item to top and updates stats', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialLength = container.read(transferRepositoryProvider).length;

      final newItem = StockTransferItem(
        id: 'test-trf-999',
        referenceNumber: 'TRF-TEST-001',
        type: TransferType.binToBin,
        sku: 'SKU-TEST-01',
        barcode: '1234567890',
        productName: 'Barang Uji Coba',
        fromLocation: 'RACK-A1-01',
        toLocation: 'RACK-B1-02',
        quantity: 5,
        unit: 'Pcs',
        status: TransferStatus.completed,
        createdAt: '12:00 WIB',
      );

      container.read(transferRepositoryProvider.notifier).addTransfer(newItem);

      final items = container.read(transferRepositoryProvider);
      expect(items.length, initialLength + 1);
      expect(items.first.referenceNumber, 'TRF-TEST-001');

      final stats = container.read(transferStatsProvider);
      expect(stats.todayTotal, initialLength + 1);
    });

    test('updateTransferStatus changes status correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(transferRepositoryProvider.notifier);
      final inTransitItem = container
          .read(transferRepositoryProvider)
          .firstWhere((t) => t.status == TransferStatus.inTransit);

      notifier.updateTransferStatus(inTransitItem.id, TransferStatus.completed);

      final updatedItem = container
          .read(transferRepositoryProvider)
          .firstWhere((t) => t.id == inTransitItem.id);

      expect(updatedItem.status, TransferStatus.completed);
    });
  });

  group('TransferListScreen Widget Tests', () {
    testWidgets('renders white header, stats summary, and transfer cards in primary blue theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransferListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header & stats
      expect(find.text('Mutasi & Transfer Stok'), findsOneWidget);
      expect(find.text('Total Mutasi'), findsOneWidget);
      expect(find.text('Dalam Proses'), findsOneWidget);
      expect(find.text('Selesai'), findsWidgets);

      // Check action buttons
      expect(find.text('Scan Pindah Rak'), findsOneWidget);
      expect(find.text('+ Buat Mutasi'), findsOneWidget);

      // Check chips
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Pindah Rak'), findsOneWidget);
      expect(find.text('Antar Gudang'), findsOneWidget);
      expect(find.text('Display Toko'), findsOneWidget);

      // Check cards
      expect(find.text('TRF-2026-0412'), findsOneWidget);
      expect(find.text('Kabel Fiber Optic Drop Core 100m'), findsOneWidget);
    });

    testWidgets('filtering by type updates visible list', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransferListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'Pindah Rak' chip
      await tester.tap(find.text('Pindah Rak'));
      await tester.pumpAndSettle();

      // Pindah Rak should be visible (TRF-2026-0412)
      expect(find.text('TRF-2026-0412'), findsOneWidget);
      // Other type items should be hidden
      expect(find.text('REP-2026-0104'), findsNothing);
    });
  });

  group('TransferFormScreen Widget Tests', () {
    testWidgets('renders form fields with zero layout overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const TransferFormScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Buat Mutasi Stok'), findsOneWidget);
      expect(find.text('Pindah Rak'), findsOneWidget);
      expect(find.text('Kirim Cabang'), findsOneWidget);
      expect(find.text('Display Toko'), findsOneWidget);
      expect(find.text('JUMLAH MUTASI'), findsOneWidget);
    });
  });
}
