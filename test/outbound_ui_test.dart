import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/core/auth/auth_provider.dart';
import 'package:omni_warehouse_mob/features/outbound/outbound_list_screen.dart';
import 'package:omni_warehouse_mob/features/outbound/outbound_model.dart';
import 'package:omni_warehouse_mob/features/outbound/outbound_repository.dart';
import 'package:omni_warehouse_mob/features/outbound/outbound_scanner_screen.dart';
import 'package:omni_warehouse_mob/features/outbound/widgets/create_manifest_modal.dart';

void main() {
  testWidgets('outbound manifest form fits mobile with keyboard visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(() {
      tester.view.resetViewInsets();
      tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: CreateOutboundManifestModal(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Pilih Customer / Pelanggan'), findsOneWidget);
    expect(find.text('No. Kendaraan (Opsional)'), findsOneWidget);
    expect(find.text('Nama Driver (Opsional)'), findsOneWidget);
  });

  testWidgets('outbound list opens SO manifest form with customer and SKU', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(const OutboundListScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Buat Manifes SO'), findsOneWidget);

    await tester.tap(find.text('Buat Manifes SO').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Buat Manifes SO Outbound'), findsOneWidget);
    expect(find.text('Pilih Customer / Pelanggan'), findsOneWidget);
    expect(find.text('No. Kendaraan (Opsional)'), findsOneWidget);
    expect(find.text('Nama Driver (Opsional)'), findsOneWidget);
    expect(find.text('SKU-34'), findsOneWidget);
    expect(find.text('Jumlah SO'), findsOneWidget);
  });

  testWidgets('outbound picking workspace matches inbound mobile layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(const OutboundScannerScreen(code: 'TX-OUT-123')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Workspace Picking'), findsOneWidget);
    expect(find.text('Verifikasi Barcode / SKU'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Buka Kamera Scanner'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Detail Item Picking & Source Rack'), findsOneWidget);
    expect(find.textContaining('SKU-34'), findsOneWidget);
  });
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
      OutboundLocation(id: 5, rackCode: 'RACK-B2-01', zone: 'B2'),
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
