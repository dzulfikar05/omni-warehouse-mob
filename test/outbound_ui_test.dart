import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/core/auth/auth_provider.dart';
import 'package:omni_warehouse_mob/core/offline/offline_db.dart';
import 'package:omni_warehouse_mob/features/outbound/outbound_list_screen.dart';
import 'package:omni_warehouse_mob/features/outbound/outbound_model.dart';
import 'package:omni_warehouse_mob/features/outbound/outbound_repository.dart';
import 'package:omni_warehouse_mob/features/outbound/outbound_scanner_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    await OfflineDb.init(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      initializeHive: false,
    );
  });

  testWidgets('outbound list does not create manifests on mobile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(const OutboundListScreen()));
    await tester.pump();
    await _flushOfflineIo(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.takeException(), isNull);
    expect(find.text('Buat Manifes SO'), findsNothing);
  });

  testWidgets('outbound picking workspace matches inbound mobile layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(const OutboundScannerScreen(code: 'TX-OUT-123')),
    );
    await tester.pump();
    await _flushOfflineIo(tester);
    await tester.pump();
    await _flushOfflineIo(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('Workspace Picking'), findsOneWidget);
    expect(find.text('Scan Barcode / Cari SKU Picking'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Buka Kamera Scanner'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Detail Item Picking & Source Rack'), findsOneWidget);
    expect(find.textContaining('SKU-34'), findsOneWidget);
    expect(find.text('RACK-B2-01 · 15 unit'), findsNothing);

    await tester.tap(find.text('SKU-34').last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Pilih Gudang'), findsOneWidget);
    expect(find.text('Pilih Rak Sumber'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gudang Utama').last);
    await tester.pumpAndSettle();
    expect(find.text('Pilih Rak Sumber'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<OutboundLocation>));
    await tester.pumpAndSettle();
    expect(find.text('RACK-B2-01 · 9 unit'), findsOneWidget);
  });
}

Future<void> _flushOfflineIo(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
}

Widget _app(Widget home) => ProviderScope(
  overrides: [
    outboundDataSourceProvider.overrideWithValue(_repository),
    outboundRepositoryProvider.overrideWith(
      (ref) =>
          OutboundNotifier(repository: _repository, tenantSlug: 'tenant-a'),
    ),
    authProvider.overrideWith((ref) => _TestAuthNotifier()),
  ],
  child: MaterialApp(home: home),
);

class _TestAuthNotifier extends AuthNotifier {
  @override
  Future<void> initialize() async {}
}

const _repository = _FakeOutboundRepository();

class _FakeOutboundRepository implements OutboundRepository {
  const _FakeOutboundRepository();

  @override
  Future<OutboundMasterOptions> getMasterOptions(String slug) async =>
      const OutboundMasterOptions(
        customers: [OutboundCustomer(id: 12, code: 'C-12', name: 'Customer A')],
        products: [
          OutboundProductMaster(
            skuId: 34,
            sku: 'SKU-34',
            barcode: '0034',
            name: 'Product 34',
          ),
        ],
        locations: [],
      );

  @override
  Future<OutboundListResult> getManifests(
    String slug, {
    Map<String, dynamic> filters = const {},
  }) async => OutboundListResult(
    manifests: const [],
    stats: OutboundStats.fromManifests(const []),
  );

  @override
  Future<OutboundManifestDetail> getManifestDetail(
    String slug,
    String code,
  ) async => OutboundManifestDetail(
    manifest: OutboundOrder(
      code: 'TX-OUT-123',
      customer: 'Customer A',
      customerId: 12,
      destination: '',
      expedition: '',
      stagingBay: '-',
      status: OutboundStatus.readyToPick,
      items: [
        OutboundItem(
          id: '22',
          sku: 'SKU-34',
          barcode: '0034',
          name: 'Product 34',
          fromRack: 'RACK-B2-01',
          orderQty: 8,
          skuId: 34,
          sourceRackId: 5,
        ),
      ],
    ),
    items: [
      OutboundItem(
        id: '22',
        sku: 'SKU-34',
        barcode: '0034',
        name: 'Product 34',
        fromRack: 'RACK-B2-01',
        orderQty: 8,
        skuId: 34,
        sourceRackId: 5,
      ),
    ],
    locations: const [
      OutboundLocation(
        id: 5,
        rackCode: 'RACK-B2-01',
        zone: 'B2',
        warehouseId: 3,
        warehouseName: 'Gudang Utama',
        stockQuantity: 15,
        stockBySku: {34: 9},
      ),
    ],
  );

  @override
  Future<void> createManifest(
    String slug, {
    required int customerId,
    required List<Map<String, int>> items,
    String? vehicleNo,
    String? driverName,
    String? notes,
  }) async {}

  @override
  Future<void> verifyBarcode(
    String slug, {
    required String manifestCode,
    required String barcode,
  }) async {}

  @override
  Future<void> updatePicking({
    required String slug,
    required String manifestCode,
    required int itemId,
    required int goodQty,
    required int damagedQty,
    int? sourceRackId,
    String? damageNote,
  }) async {}

  @override
  Future<void> commitOutbound(String slug, String manifestCode) async {}

  @override
  Future<void> hold(String slug, String manifestCode, {String? reason}) async {}

  @override
  Future<void> resume(String slug, String manifestCode) async {}
}
