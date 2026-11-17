import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/core/auth/auth_provider.dart';
import 'package:omni_warehouse_mob/features/stock_transfer/transfer_transaction_form_screen.dart';
import 'package:omni_warehouse_mob/features/stock_transfer/transfer_transaction_model.dart';
import 'package:omni_warehouse_mob/features/stock_transfer/transfer_transaction_repository.dart';

void main() {
  testWidgets('shows selected SKU and rack stock details in the form', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _TestAuthNotifier()),
          transferTransactionRepositoryProvider.overrideWithValue(
            _FakeTransferRepository(
              Future.value(
                const TransferMasterOptions(
                  warehouses: [],
                  locations: [
                    TransferLocation(
                      id: 8,
                      name: 'RACK-A1',
                      warehouseName: 'Gudang Utama',
                      stockQuantity: 12,
                    ),
                    TransferLocation(id: 9, name: 'RACK-B1'),
                  ],
                  skus: [
                    TransferSku(
                      id: 5,
                      code: 'SKU-5',
                      name: 'Produk Lima',
                      barcode: '001005',
                      availableStock: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: TransferTransactionFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih SKU / produk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Produk Lima (SKU-5)'));
    await tester.pumpAndSettle();
    expect(find.text('Barcode: 001005'), findsOneWidget);
    expect(find.text('Total stok tersedia: 20 pcs'), findsOneWidget);

    await tester.tap(find.text('Rak asal (Origin)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RACK-A1 · Gudang Utama'));
    await tester.pumpAndSettle();
    expect(find.text('Stok saat ini di rak: 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the transaction form while master options are loading', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final optionsCompleter = Completer<TransferMasterOptions>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _TestAuthNotifier()),
          transferTransactionRepositoryProvider.overrideWithValue(
            _FakeTransferRepository(optionsCompleter.future),
          ),
        ],
        child: const MaterialApp(home: TransferTransactionFormScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Buat Mutasi Stok'), findsOneWidget);
    expect(find.text('Memuat data SKU dan lokasi...'), findsOneWidget);
    expect(find.text('Tambah baris item mutasi'), findsOneWidget);
    expect(find.text('Catatan mutasi (opsional)'), findsOneWidget);
    expect(tester.takeException(), isNull);

    optionsCompleter.completeError(Exception('Server tidak tersedia'));
    await tester.pump();

    expect(find.text('Coba muat ulang'), findsOneWidget);
    expect(find.text('Tambah baris item mutasi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier() {
    setTenant(tenantSlug: 'tenant-a', tenantName: 'Tenant A');
  }

  @override
  Future<void> initialize() async {}
}

class _FakeTransferRepository implements TransferTransactionRepository {
  const _FakeTransferRepository(this.options);

  final Future<TransferMasterOptions> options;

  @override
  Future<TransferMasterOptions> getOptions(String slug) => options;

  @override
  Future<TransferTransactionListResult> getTransactions(
    String slug, {
    Map<String, dynamic> filters = const {},
  }) => throw UnimplementedError();

  @override
  Future<String?> createTransaction(
    String slug, {
    required List<Map<String, dynamic>> items,
    String? notes,
  }) => throw UnimplementedError();

  @override
  Future<void> updateTransaction(
    String slug,
    String code, {
    required List<Map<String, dynamic>> items,
    String? notes,
  }) => throw UnimplementedError();

  @override
  Future<void> cancelTransaction(String slug, String code) =>
      throw UnimplementedError();
}
