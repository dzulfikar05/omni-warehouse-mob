import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/features/outbound/outbound_model.dart';
import 'package:omni_warehouse_mob/features/outbound/outbound_repository.dart';

void main() {
  group('Outbound API response contracts', () {
    test('parses Laravel customer and SKU master options', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
      RequestOptions? request;
      final repository = ApiOutboundRepository(
        _respondWith(dio, {
          'success': true,
          'data': {
            'customers': [
              {'id': 12, 'code': 'C-12', 'name': 'Customer A'},
            ],
            'products': [
              {
                'id': 9,
                'sku_id': 34,
                'sku': 'SKU-34',
                'barcode': '0034',
                'name': 'Product 34',
              },
            ],
            'available_racks': ['RACK-B2-01'],
          },
        }, onRequest: (value) => request = value),
      );

      final result = await repository.getMasterOptions('tenant-a');

      expect(request?.path, '/tenant-a/outbound/options');
      expect(result.customers.single.id, 12);
      expect(result.customers.single.name, 'Customer A');
      expect(result.products.single.skuId, 34);
      expect(result.availableRacks, ['RACK-B2-01']);
    });

    test('parses Laravel paginator and outbound status/item fields', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
      RequestOptions? request;
      final repository = ApiOutboundRepository(
        _respondWith(dio, {
          'success': true,
          'data': {
            'manifests': {
              'data': [
                {
                  'manifest_code': 'TX-OUT-123',
                  'customer_id': 12,
                  'customer': {'id': 12, 'name': 'Customer A'},
                  'status': 'PICKING',
                  'items': [
                    {
                      'id': 22,
                      'sku_id': 34,
                      'sku_code': 'SKU-34',
                      'product_name': 'Product 34',
                      'so_qty': 8,
                      'good_qty': 3,
                      'source_rack_id': 5,
                      'source_rack': 'RACK-B2-01',
                    },
                  ],
                },
              ],
            },
            'summary': {'total': 4, 'picking': 2, 'dispatched': 1},
          },
        }, onRequest: (value) => request = value),
      );

      final result = await repository.getManifests(
        'tenant-a',
        filters: const {'status': 'PICKING'},
      );
      final order = result.manifests.single;
      final item = order.items.single;

      expect(request?.path, '/tenant-a/outbound/');
      expect(request?.queryParameters['status'], 'PICKING');
      expect(order.code, 'TX-OUT-123');
      expect(order.customerId, 12);
      expect(order.status, OutboundStatus.picking);
      expect(item.orderQty, 8);
      expect(item.pickedQty, 3);
      expect(item.sourceRackId, 5);
      expect(result.stats.todayTotal, 4);
    });

    test(
      'parses detail locations from the OutboundController response',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
        RequestOptions? request;
        final repository = ApiOutboundRepository(
          _respondWith(dio, {
            'success': true,
            'data': {
              'manifest': {
                'manifest_code': 'TX-OUT-123',
                'customer': {'id': 12, 'name': 'Customer A'},
                'status': 'READY_TO_PICK',
              },
              'items': [
                {
                  'id': 22,
                  'sku': {'sku': 'SKU-34', 'barcode': '0034'},
                  'product_name': 'Product 34',
                  'so_qty': 8,
                  'good_qty': 1,
                  'damaged_qty': 2,
                  'location': {'id': 5, 'rack_code': 'RACK-B2-01'},
                },
              ],
              'locations': [
                {
                  'id': 5,
                  'rack_code': 'RACK-B2-01',
                  'zone': 'B2',
                  'available_quantity': 15,
                },
              ],
            },
          }, onRequest: (value) => request = value),
        );

        final result = await repository.getManifestDetail(
          'tenant-a',
          'TX-OUT-123',
        );

        expect(request?.path, '/tenant-a/outbound/manifests/TX-OUT-123');
        expect(result.manifest.code, 'TX-OUT-123');
        expect(result.items.single.sku, 'SKU-34');
        expect(result.items.single.sourceRackId, 5);
        expect(result.items.single.damagedQty, 2);
        expect(result.manifest.totalPickedUnits, 1);
        expect(result.manifest.totalProcessedUnits, 3);
        expect(result.locations.single.zone, 'B2');
        expect(result.locations.single.stockQuantity, 15);
      },
    );

    test(
      'posts create, scan, picking, commit, hold and resume contracts',
      () async {
        final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
        final requests = <RequestOptions>[];
        final repository = ApiOutboundRepository(
          _respondWith(dio, {
            'success': true,
            'message': 'ok',
            'data': null,
          }, onRequest: requests.add),
        );

        await repository.createManifest(
          'tenant-a',
          customerId: 12,
          items: const [
            {'sku_id': 34, 'so_qty': 8},
          ],
          vehicleNo: 'B 1234 CD',
          driverName: 'Driver A',
          notes: 'Fragile',
        );
        await repository.verifyBarcode(
          'tenant-a',
          manifestCode: 'TX-OUT-123',
          barcode: '0034',
        );
        await repository.updatePicking(
          slug: 'tenant-a',
          manifestCode: 'TX-OUT-123',
          itemId: 22,
          goodQty: 7,
          damagedQty: 1,
          sourceRackId: 5,
          damageNote: 'Outer box dented',
        );
        await repository.commitOutbound('tenant-a', 'TX-OUT-123');
        await repository.hold(
          'tenant-a',
          'TX-OUT-123',
          reason: 'Menunggu pemeriksaan',
        );
        await repository.resume('tenant-a', 'TX-OUT-123');

        expect(requests.map((request) => request.path), [
          '/tenant-a/outbound/store',
          '/tenant-a/outbound/verify-barcode',
          '/tenant-a/outbound/picking',
          '/tenant-a/outbound/commit',
          '/tenant-a/outbound/hold',
          '/tenant-a/outbound/resume',
        ]);
        expect(requests[0].data, {
          'customer_id': 12,
          'items': [
            {'sku_id': 34, 'so_qty': 8},
          ],
          'vehicle_no': 'B 1234 CD',
          'driver_name': 'Driver A',
          'notes': 'Fragile',
        });
        expect(requests[1].data, {
          'manifest_code': 'TX-OUT-123',
          'barcode': '0034',
        });
        expect(requests[2].data, {
          'manifest_code': 'TX-OUT-123',
          'item_id': 22,
          'good_qty': 7,
          'damaged_qty': 1,
          'source_rack_id': 5,
          'damage_note': 'Outer box dented',
        });
        expect(requests[3].data, {'manifest_code': 'TX-OUT-123'});
        expect(requests[4].data, {
          'manifest_code': 'TX-OUT-123',
          'reason': 'Menunggu pemeriksaan',
        });
        expect(requests[5].data, {'manifest_code': 'TX-OUT-123'});
      },
    );
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
        handler.resolve(Response<dynamic>(requestOptions: options, data: body));
      },
    ),
  );
  return dio;
}
