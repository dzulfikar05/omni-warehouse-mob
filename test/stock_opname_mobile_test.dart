import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_warehouse_mob/core/api/api_exception.dart';
import 'package:omni_warehouse_mob/core/auth/auth_provider.dart';
import 'package:omni_warehouse_mob/features/stock_opname/stock_opname_model.dart';
import 'package:omni_warehouse_mob/features/stock_opname/stock_opname_repository.dart';
import 'package:omni_warehouse_mob/features/stock_opname/stock_opname_scanner_screen.dart';
import 'package:omni_warehouse_mob/features/stock_opname/stock_opname_screen.dart';

void main() {
  testWidgets('session list shows progress, status, warehouse, and location', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const StockOpnameScreen(), repository: _FakeStockOpnameRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('SOP-2026-0042'), findsOneWidget);
    expect(find.text('4/10 item dihitung'), findsOneWidget);
    expect(find.text('Gudang Utama (WH-01)'), findsOneWidget);
    expect(find.text('Rak A1'), findsOneWidget);
    expect(find.text('COUNTING'), findsOneWidget);
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
    expect(find.text('Status: REVIEW'), findsOneWidget);
    expect(find.text('Selesaikan Opname / Submit Review'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows count validation errors to the operator', (tester) async {
    final repository = _FakeStockOpnameRepository()
      ..recordError = const ValidationException(
        'Jumlah fisik tidak valid.',
        errors: {
          'physical_qty': ['Jumlah harus lebih besar atau sama dengan 0.'],
        },
      );
    await tester.pumpWidget(
      _app(
        const StockOpnameScannerScreen(sessionCode: 'SOP-2026-0042'),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SKU-101'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '7');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Jumlah fisik tidak valid.'), findsOneWidget);
  });

  testWidgets('selecting a session loads detail by session ID', (tester) async {
    final repository = _FakeStockOpnameRepository();
    final router = GoRouter(
      initialLocation: '/more/opname',
      routes: [
        GoRoute(
          path: '/more/opname',
          builder: (context, state) => const StockOpnameScreen(),
          routes: [
            GoRoute(
              path: ':session_code',
              builder: (context, state) => StockOpnameScannerScreen(
                sessionCode: state.pathParameters['session_code'],
                sessionId: int.tryParse(
                  state.uri.queryParameters['session_id'] ?? '',
                ),
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(_routerApp(router, repository));
    await tester.pumpAndSettle();

    expect(find.text('4/10 item dihitung'), findsOneWidget);
    await tester.tap(find.text('SOP-2026-0042'));
    await tester.pumpAndSettle();

    expect(repository.detailSessionIds, [42]);
    expect(find.text('SKU-101'), findsOneWidget);
    expect(find.text('Status: ACTIVE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loads the next session page using API pagination metadata', (
    tester,
  ) async {
    final repository = _FakeStockOpnameRepository();
    await tester.pumpWidget(
      _app(const StockOpnameScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Muat lainnya'));
    await tester.pumpAndSettle();

    expect(repository.requestedPages, [1, 2]);
    expect(find.text('SOP-2026-0042'), findsOneWidget);
    expect(find.text('SOP-2026-0043'), findsOneWidget);
  });

  testWidgets('adjusted session detail is read-only', (tester) async {
    final repository = _FakeStockOpnameRepository()
      ..detailSession = _session.copyWith(status: 'ADJUSTED');
    await tester.pumpWidget(
      _app(
        const StockOpnameScannerScreen(
          sessionCode: 'SOP-2026-0042',
          sessionId: 42,
        ),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Detail Stock Opname'), findsOneWidget);
    expect(find.textContaining('sudah disesuaikan'), findsOneWidget);
    expect(find.text('Buka kamera'), findsNothing);
    expect(find.text('Selesaikan Opname / Submit Review'), findsNothing);
    await tester.tap(find.text('SKU-101'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.recordedCounts, isEmpty);
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

Widget _routerApp(GoRouter router, StockOpnameRepository repository) =>
    ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _TestAuthNotifier()),
        stockOpnameDataSourceProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(routerConfig: router),
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
  final detailSessionIds = <int>[];
  final requestedPages = <int>[];
  Object? recordError;
  StockOpnameSession detailSession = _session;

  @override
  Future<StockOpnameSessionPage> getSessions(
    String tenantSlug, {
    int page = 1,
  }) async {
    requestedPages.add(page);
    return StockOpnameSessionPage(
      sessions: [
        StockOpnameSessionSummary(
          id: page == 1 ? 42 : 43,
          sessionCode: page == 1 ? 'SOP-2026-0042' : 'SOP-2026-0043',
          status: 'COUNTING',
          warehouseName: 'Gudang Utama',
          warehouseCode: 'WH-01',
          locationId: 8,
          locationLabel: 'Rak A1',
          auditorName: 'Operator A',
          createdAt: '2026-11-18T08:30:00Z',
          totalItems: 10,
          countedItems: 4,
        ),
      ],
      currentPage: page,
      lastPage: 2,
      total: 2,
    );
  }

  @override
  Future<StockOpnameSession> getSessionDetail(
    String tenantSlug, {
    required int sessionId,
    String? sessionCode,
  }) async {
    detailSessionIds.add(sessionId);
    return detailSession;
  }

  @override
  Future<StockOpnameSession?> getActiveSession(
    String tenantSlug, {
    int? sessionId,
  }) async => sessionId == null || sessionId == _session.id ? _session : null;

  @override
  Future<OpnameSyncOutcome> recordCount(
    String tenantSlug, {
    required int itemId,
    required num physicalQty,
    int? sessionId,
    String? sessionCode,
    int? locationId,
    String? targetRack,
  }) async {
    if (recordError != null) throw recordError!;
    recordedCounts.add((itemId, physicalQty));
    return const OpnameSyncOutcome(synced: true);
  }

  @override
  Future<OpnameSyncOutcome> submitReview(
    String tenantSlug, {
    int? sessionId,
    String? sessionCode,
  }) async {
    submittedSessionIds.add(sessionId ?? 0);
    return const OpnameSyncOutcome(synced: true);
  }
}

const _session = StockOpnameSession(
  id: 42,
  sessionCode: 'SOP-2026-0042',
  warehouse: 'Gudang Utama',
  zone: 'Zona A1',
  status: 'ACTIVE',
  locationId: 8,
  locationLabel: 'Rak A1',
  items: [
    StockOpnameItem(
      id: 101,
      sku: 'SKU-101',
      barcode: '00101',
      name: 'Produk 101',
      targetRack: 'RACK-A1-01',
      locationId: 8,
      locationLabel: 'Rak A1',
      physicalQty: null,
      unit: 'pcs',
    ),
  ],
);
