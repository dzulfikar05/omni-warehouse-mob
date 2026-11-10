import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/core/auth/auth_provider.dart';
import 'package:omni_warehouse_mob/features/stock_transfer/transfer_transaction_form_screen.dart';
import 'package:omni_warehouse_mob/features/stock_transfer/transfer_transaction_model.dart';
import 'package:omni_warehouse_mob/features/stock_transfer/transfer_transaction_repository.dart';

void main() {
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
  }) =>
      throw UnimplementedError();

  @override
  Future<String?> createTransaction(
    String slug, {
    required List<Map<String, dynamic>> items,
    String? notes,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> updateTransaction(
    String slug,
    String code, {
    required List<Map<String, dynamic>> items,
    String? notes,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> cancelTransaction(String slug, String code) =>
      throw UnimplementedError();
}
