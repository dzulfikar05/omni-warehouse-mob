import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/features/stock_transfer/transfer_transaction_repository.dart';

void main() {
  group('Stock transfer API contract', () {
    test('loads master options and parses transfer log list', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            final body = options.path.endsWith('/options')
                ? {
                    'success': true,
                    'data': {
                      'warehouses': [
                        {'id': 2, 'name': 'Gudang Utama'},
                      ],
                      'locations': [
                        {
                          'id': 8,
                          'rack_code': 'RACK-A1',
                          'warehouse_id': 2,
                          'warehouse_name': 'Gudang Utama',
                          'quantity': 12,
                        },
                      ],
                      'skus': [
                        {
                          'sku_id': 5,
                          'sku': 'SKU-5',
                          'name': 'Produk Lima',
                          'available_stock': 20,
                        },
                      ],
                    },
                  }
                : {
                    'success': true,
                    'data': {
                      'logs': {
                        'data': [
                          {
                            'transfer_code': 'TRF-1001',
                            'status': 'completed',
                            'created_at': '2026-11-03 08:06:07',
                            'created_by_name': 'Operator A',
                            'notes': 'Perpindahan rak',
                            'items': [
                              {
                                'sku_id': 5,
                                'sku_code': 'SKU-5',
                                'product_name': 'Produk Lima',
                                'from_location_id': 8,
                                'from_location': {'rack_code': 'RACK-A1'},
                                'to_location_id': 9,
                                'to_location': {'rack_code': 'RACK-B1'},
                                'quantity': 3,
                              },
                            ],
                          },
                        ],
                      },
                      'summary': {
                        'total': 1,
                        'in_progress': 0,
                        'completed': 1,
                        'total_units': 3,
                      },
                    },
                  };
            handler.resolve(
              Response<dynamic>(requestOptions: options, data: body),
            );
          },
        ),
      );
      final repository = ApiTransferTransactionRepository(dio);

      final options = await repository.getOptions('tenant-a');
      final result = await repository.getTransactions(
        'tenant-a',
        filters: const {'status': 'completed'},
      );

      expect(requests[0].path, '/tenant-a/stock-transfer/options');
      expect(requests[1].path, '/tenant-a/stock-transfer/');
      expect(requests[1].queryParameters['status'], 'completed');
      expect(options.warehouses.single.name, 'Gudang Utama');
      expect(options.locations.single.id, 8);
      expect(options.locations.single.stockQuantity, 12);
      expect(options.skus.single.availableStock, 20);
      expect(result.transactions.single.code, 'TRF-1001');
      expect(result.transactions.single.items.single.fromLocation, 'RACK-A1');
      expect(result.transactions.single.items.single.toLocationId, 9);
      expect(result.stats.totalUnits, 3);
    });

    test('posts create, update and cancel using the Laravel routes', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: {
                  'success': true,
                  'message': 'ok',
                  'data': {'transfer_code': 'TRF-1001'},
                },
              ),
            );
          },
        ),
      );
      final repository = ApiTransferTransactionRepository(dio);
      const items = [
        {
          'sku_id': 5,
          'from_location_id': 8,
          'to_location_id': 9,
          'quantity': 3,
        },
      ];

      final code = await repository.createTransaction(
        'tenant-a',
        items: items,
        notes: 'Pindah rak',
      );
      await repository.updateTransaction(
        'tenant-a',
        'TRF-1001',
        items: const [
          {
            'sku_id': 5,
            'from_location_id': 8,
            'to_location_id': 9,
            'quantity': 2,
            'batch_number': 'B-10',
            'expiry_date': '2027-01-01',
          },
        ],
        notes: 'Draft diperbarui',
      );
      await repository.cancelTransaction('tenant-a', 'TRF-1001');

      expect(code, 'TRF-1001');
      expect(requests.map((request) => request.path), [
        '/tenant-a/stock-transfer/store',
        '/tenant-a/stock-transfer/TRF-1001',
        '/tenant-a/stock-transfer/TRF-1001/cancel',
      ]);
      expect(requests[0].data, {'items': items, 'notes': 'Pindah rak'});
      expect(requests[1].data['items'].single['batch_number'], 'B-10');
      expect(requests[2].method, 'POST');
    });
  });
}
