import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/core/auth/auth_provider.dart';
import 'package:omni_warehouse_mob/core/theme/app_theme.dart';
import 'package:omni_warehouse_mob/features/inbound/inbound_list_screen.dart';
import 'package:omni_warehouse_mob/features/inbound/inbound_model.dart';
import 'package:omni_warehouse_mob/features/inbound/inbound_repository.dart';
import 'package:omni_warehouse_mob/features/inbound/inbound_scanner_screen.dart';
import 'package:omni_warehouse_mob/features/inbound/widgets/create_manifest_modal.dart';

void main() {
  testWidgets('inbound list fits a narrow mobile viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(const InboundListScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('TX-INB-2026-VERY-LONG-MANIFEST-CODE'), findsOneWidget);
    expect(find.text('ON HOLD'), findsOneWidget);
  });

  testWidgets('receiving workspace fits a narrow mobile viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        const InboundScannerScreen(code: 'TX-INB-2026-VERY-LONG-MANIFEST-CODE'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Verifikasi Barcode / SKU'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Buka Kamera Scanner'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Detail Item Receiving & Putaway'), findsOneWidget);
    expect(find.textContaining('Long-name monitor'), findsOneWidget);
    expect(find.text('RACK-A1-01 · 12 unit'), findsOneWidget);
  });

  testWidgets('create manifest modal remains scrollable above the keyboard', (
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
            child: CreateManifestModal(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Buat Manifes Inbound PO'), findsOneWidget);
    expect(find.text('Buat Manifes PO'), findsOneWidget);
    expect(find.textContaining('Barcode: 0123456789'), findsOneWidget);
  });
}

Widget _app(Widget home) => ProviderScope(
  overrides: [
    inboundDataSourceProvider.overrideWithValue(_repository),
    inboundRepositoryProvider.overrideWith(
      (ref) => InboundNotifier(_repository, 'tenant-a'),
    ),
    authProvider.overrideWith((ref) => _TestAuthNotifier()),
  ],
  child: MaterialApp(theme: buildAppTheme(), home: home),
);

const _repository = _FakeInboundRepository();

class _TestAuthNotifier extends AuthNotifier {
  @override
  Future<void> initialize() async {}
}

class _FakeInboundRepository implements InboundRepository {
  const _FakeInboundRepository();

  @override
  Future<InboundMasterOptions> getMasterOptions(
    String slug,
  ) async => InboundMasterOptions(
    suppliers: [InboundSupplier(id: 1, code: '1', name: 'Supplier WMS')],
    products: [
      InboundProductMaster(
        id: 9,
        productId: 3,
        sku: 'SKU-MONITOR-ULTRA-WIDE',
        barcode: '0123456789',
        name:
            'Long-name monitor with an extra-wide professional display and accessory bundle',
      ),
    ],
    availableRacks: const ['RACK-A1-01'],
  );

  @override
  Future<InboundListResult> getManifests(
    String slug, {
    Map<String, dynamic> filters = const {},
  }) async => InboundListResult(
    manifests: [_manifest],
    stats: const InboundStats(
      todayTotal: 1,
      inProgress: 0,
      completed: 0,
      hold: 1,
    ),
  );

  @override
  Future<InboundManifestDetail> getManifestDetail(
    String slug,
    String code,
  ) async => InboundManifestDetail(
    manifest: _manifest,
    items: [
      InboundItem(
        id: '42',
        productId: 9,
        sku: 'SKU-MONITOR-ULTRA-WIDE',
        barcode: '0123456789',
        name:
            'Long-name monitor with an extra-wide professional display and accessory bundle',
        expectedQty: 10,
      ),
    ],
    locations: const [
      InboundLocation(
        id: 1,
        rackCode: 'RACK-A1-01',
        zone: 'A1',
        stockQuantity: 12,
      ),
    ],
  );

  @override
  Future<void> createManifest(
    String slug, {
    required int supplierId,
    required List<Map<String, int>> items,
  }) async {}

  @override
  Future<void> verifyBarcode(
    String slug, {
    required String manifestCode,
    required String barcode,
  }) async {}

  @override
  Future<void> submitPutaway(
    String slug, {
    required String manifestCode,
    required int itemId,
    required int goodQty,
    required int damagedQty,
    required String targetRack,
    String? damageNote,
  }) async {}

  @override
  Future<void> commitManifest(String slug, String manifestCode) async {}

  @override
  Future<void> holdManifest(
    String slug,
    String manifestCode, {
    String? reason,
  }) async {}

  @override
  Future<void> resumeManifest(String slug, String manifestCode) async {}
}

final _manifest = InboundManifest(
  code: 'TX-INB-2026-VERY-LONG-MANIFEST-CODE',
  supplierId: 1,
  supplierName: 'Supplier with a long descriptive enterprise name',
  totalUnits: 10,
  totalSkus: 1,
  status: InboundStatus.hold,
  items: const [],
);
