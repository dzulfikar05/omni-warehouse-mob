import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/features/inbound/inbound_model.dart';
import 'package:omni_warehouse_mob/features/inbound/inbound_repository.dart';

void main() {
  group('Inbound API response contracts', () {
    test('parses the product and SKU IDs returned by the options endpoint', () {
      final product = InboundProductMaster.fromJson({
        'id': 5,
        'sku_id': 17,
        'sku': 'SKU-17',
        'barcode': '0017',
        'name': 'Product seventeen',
      });

      expect(product.productId, 5);
      expect(product.id, 17);
      expect(product.sku, 'SKU-17');
      expect(product.barcode, '0017');
    });

    test('loads option response from the tenant inbound endpoint', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
      RequestOptions? capturedRequest;
      final repository = ApiInboundRepository(
        _respondWith(
          dio,
          {
            'success': true,
            'data': {
              'suppliers': [
                {'id': 3, 'code': '3', 'name': 'Supplier A'},
              ],
              'products': [
                {
                  'id': 5,
                  'sku_id': 17,
                  'sku': 'SKU-17',
                  'barcode': '0017',
                  'name': 'Product seventeen',
                },
              ],
              'available_racks': ['RACK-A1-01'],
            },
          },
          onRequest: (request) => capturedRequest = request,
        ),
      );

      final options = await repository.getMasterOptions('tenant-a');

      expect(capturedRequest?.path, '/tenant-a/inbound/options');
      expect(options.suppliers.single.id, 3);
      expect(options.products.single.id, 17);
      expect(options.products.single.productId, 5);
      expect(options.availableRacks, ['RACK-A1-01']);
    });

    test('posts both product and SKU fields required by createManifest',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
      RequestOptions? capturedRequest;
      final repository = ApiInboundRepository(
        _respondWith(
          dio,
          {
            'success': true,
            'data': {'manifest_code': 'TX-INB-123'}
          },
          onRequest: (request) => capturedRequest = request,
        ),
      );

      await repository.createManifest(
        'tenant-a',
        supplierId: 3,
        items: [
          {
            'product_id': 5,
            'sku_id': 17,
            'expected_qty': 10,
            'po_qty': 10,
          },
        ],
        isAdhoc: false,
      );

      expect(capturedRequest?.method, 'POST');
      expect(capturedRequest?.path, '/tenant-a/inbound/store');
      expect(capturedRequest?.data, {
        'supplier_id': 3,
        'items': [
          {
            'product_id': 5,
            'sku_id': 17,
            'expected_qty': 10,
            'po_qty': 10,
          },
        ],
      });
    });

    test('posts ad-hoc manifests to the ad-hoc endpoint', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
      RequestOptions? capturedRequest;
      final repository = ApiInboundRepository(
        _respondWith(
          dio,
          {
            'success': true,
            'data': {'manifest_code': 'TX-INB-123'}
          },
          onRequest: (request) => capturedRequest = request,
        ),
      );

      await repository.createManifest(
        'tenant-a',
        supplierId: 3,
        items: const [
          {
            'product_id': 5,
            'sku_id': 17,
            'expected_qty': 2,
            'po_qty': 2,
          },
        ],
        isAdhoc: true,
      );

      expect(capturedRequest?.path, '/tenant-a/inbound/adhoc');
    });

    test('reads Laravel paginator and backend summary keys', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
      final repository = ApiInboundRepository(
        _respondWith(
          dio,
          {
            'success': true,
            'data': {
              'summary': {
                'total': 4,
                'pending': 2,
                'completed': 2,
                'total_units': 36,
              },
              'statuses': ['DRAFT', 'ON_HOLD', 'COMMITTED'],
              'manifests': {
                'current_page': 1,
                'data': [
                  {
                    'manifest_code': 'TX-INB-123',
                    'status': 'ON_HOLD',
                    'supplier_name': 'Supplier A',
                    'total_skus': 3,
                    'total_units': 12,
                  },
                ],
                'last_page': 1,
              },
            },
          },
        ),
      );

      final result = await repository.getManifests('tenant-a');

      expect(result.manifests, hasLength(1));
      expect(result.manifests.single.status.name, 'hold');
      expect(result.manifests.single.totalSkus, 3);
      expect(result.manifests.single.totalUnits, 12);
      expect(result.stats.todayTotal, 4);
      expect(result.stats.inProgress, 2);
      expect(result.stats.completed, 2);
    });

    test('parses transaction item field names returned by inbound detail',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
      final repository = ApiInboundRepository(
        _respondWith(
          dio,
          {
            'success': true,
            'data': {
              'manifest': {
                'manifest_code': 'TX-INB-123',
                'status': 'RECEIVING',
                'supplier_name': 'Supplier A',
              },
              'items': [
                {
                  'id': 42,
                  'sku_id': 9,
                  'sku': 'SKU-9',
                  'barcode': '0123456789',
                  'product_name': 'Product nine',
                  'po_qty': 10,
                  'good_qty': 2,
                  'damaged_qty': 1,
                  'target_rack': 'RACK-A1-01',
                  'damage_note': 'Box dented',
                },
              ],
              'available_locations': [
                {'id': 7, 'rack_code': 'RACK-A1-01', 'zone': 'A1'},
              ],
            },
          },
        ),
      );

      final result =
          await repository.getManifestDetail('tenant-a', 'TX-INB-123');
      final item = result.items.single;

      expect(result.manifest.code, 'TX-INB-123');
      expect(item.id, '42');
      expect(item.productId, 9);
      expect(item.name, 'Product nine');
      expect(item.expectedQty, 10);
      expect(item.goodQty, 2);
      expect(item.damagedQty, 1);
      expect(result.locations.single.rackCode, 'RACK-A1-01');
    });

    test('accepts successful barcode response with null data', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
      final repository = ApiInboundRepository(
        _respondWith(
          dio,
          {
            'success': true,
            'message': 'Barcode berhasil diverifikasi.',
            'data': null,
          },
        ),
      );

      await expectLater(
        repository.verifyBarcode(
          'tenant-a',
          manifestCode: 'TX-INB-123',
          barcode: '0123456789',
        ),
        completes,
      );
    });

    test('uses the controller route and payload for receiving operations',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
      final requests = <RequestOptions>[];
      final repository = ApiInboundRepository(
        _respondWith(
          dio,
          {'success': true, 'message': 'ok', 'data': null},
          onRequest: requests.add,
        ),
      );

      await repository.verifyBarcode(
        'tenant-a',
        manifestCode: 'TX-INB-123',
        barcode: '0123456789',
      );
      await repository.submitPutaway(
        'tenant-a',
        manifestCode: 'TX-INB-123',
        itemId: 42,
        goodQty: 8,
        damagedQty: 2,
        targetRack: 'RACK-A1-01',
        damageNote: 'Box dented',
      );
      await repository.commitManifest('tenant-a', 'TX-INB-123');
      await repository.holdManifest(
        'tenant-a',
        'TX-INB-123',
        reason: 'Menunggu pemeriksaan',
      );
      await repository.resumeManifest('tenant-a', 'TX-INB-123');

      expect(
        requests.map((request) => request.path),
        [
          '/tenant-a/inbound/scan-item',
          '/tenant-a/inbound/putaway',
          '/tenant-a/inbound/commit',
          '/tenant-a/inbound/hold',
          '/tenant-a/inbound/resume',
        ],
      );
      expect(requests[0].data, {
        'manifest_code': 'TX-INB-123',
        'barcode': '0123456789',
      });
      expect(requests[1].data, {
        'manifest_code': 'TX-INB-123',
        'item_id': 42,
        'good_qty': 8,
        'damaged_qty': 2,
        'target_rack': 'RACK-A1-01',
        'damage_note': 'Box dented',
      });
      expect(requests[2].data, {'manifest_code': 'TX-INB-123'});
      expect(requests[3].data, {
        'manifest_code': 'TX-INB-123',
        'reason': 'Menunggu pemeriksaan',
      });
      expect(requests[4].data, {'manifest_code': 'TX-INB-123'});
    });
  });
}

Dio _respondWith(
  Dio dio,
  Map<String, dynamic> body, {
  void Function(RequestOptions request)? onRequest,
}) {
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        onRequest?.call(options);
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            data: body,
          ),
        );
      },
    ),
  );
  return dio;
}
