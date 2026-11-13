import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/core/auth/auth_provider.dart';
import 'package:omni_warehouse_mob/features/stock_opname/stock_opname_model.dart';
import 'package:omni_warehouse_mob/features/stock_opname/stock_opname_repository.dart';
import 'package:omni_warehouse_mob/features/stock_opname/stock_opname_scanner_screen.dart';
import 'package:omni_warehouse_mob/features/stock_opname/stock_opname_screen.dart';

void main() {
  testWidgets('active session keeps system quantity hidden', (tester) async {
    await tester.pumpWidget(_app(const StockOpnameScreen()));
    await tester.pumpAndSettle();

    expect(find.text('SOP-2026-0042'), findsOneWidget);
    expect(find.text('Gudang Utama'), findsOneWidget);
    expect(find.text('Zona A1'), findsOneWidget);
    expect(
      find.text(
        'Blind count aktif. Stok sistem disembunyikan saat penghitungan.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Stok Sistem'), findsNothing);
    expect(find.textContaining('500'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual count is saved before submit review', (tester) async {
    final repository = _FakeStockOpnameRepository();
    await tester.pumpWidget(
      _app(
        const StockOpnameScannerScreen(sessionCode: 'SOP-2026-0042'),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SOP-2026-0042'), findsOneWidget);
    expect(find.textContaining('Stok Sistem'), findsNothing);
    await tester.tap(find.text('SKU-101'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '7');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(repository.recordedCounts, [(101, 7)]);
    expect(find.text('7 pcs'), findsOneWidget);

    await tester.tap(find.text('Selesaikan Opname / Submit Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Review'));
    await tester.pumpAndSettle();

    expect(repository.submittedSessionIds, [42]);
    expect(find.text('Sudah dikirim untuk review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget home, {StockOpnameRepository? repository}) => ProviderScope(
  overrides: [
    authProvider.overrideWith((ref) => _TestAuthNotifier()),
    stockOpnameDataSourceProvider.overrideWithValue(
      repository ?? _FakeStockOpnameRepository(),
    ),
  ],
  child: MaterialApp(home: home),
);

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier() {
    setTenant(tenantSlug: 'tenant-a', tenantName: 'Tenant A');
  }

  @override
  Future<void> initialize() async {}
}

class _FakeStockOpnameRepository implements StockOpnameRepository {
  final recordedCounts = <(int, num)>[];
  final submittedSessionIds = <int>[];

  @override
  Future<StockOpnameSession?> getActiveSession(String tenantSlug) async =>
      _session;

  @override
  Future<void> recordCount(
    String tenantSlug, {
    required int itemId,
    required num physicalQty,
  }) async {
    recordedCounts.add((itemId, physicalQty));
  }

  @override
  Future<void> submitReview(String tenantSlug, {required int sessionId}) async {
    submittedSessionIds.add(sessionId);
  }
}

const _session = StockOpnameSession(
  id: 42,
  sessionCode: 'SOP-2026-0042',
  warehouse: 'Gudang Utama',
  zone: 'Zona A1',
  status: 'ACTIVE',
  items: [
    StockOpnameItem(
      id: 101,
      sku: 'SKU-101',
      barcode: '00101',
      name: 'Produk 101',
      targetRack: 'RACK-A1-01',
      physicalQty: null,
      unit: 'pcs',
    ),
  ],
);
