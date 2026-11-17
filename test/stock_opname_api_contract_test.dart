import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/features/stock_opname/stock_opname_repository.dart';

void main() {
  test('uses the Laravel blind-counting endpoints and payloads', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    final requests = <RequestOptions>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final data = options.path.endsWith('/active')
              ? {
                  'success': true,
                  'data': {
                    'session': {
                      'id': 42,
                      'session_code': 'SOP-2026-0042',
                      'warehouse': {'name': 'Gudang Utama'},
                      'zone': {'name': 'Zona A1'},
                    },
                    'items': [
                      {
                        'id': 101,
                        'sku': {'sku': 'SKU-101', 'barcode': '00101'},
                        'product_name': 'Produk 101',
                        'target_rack': 'RACK-A1-01',
                        'physical_qty': null,
                        'system_qty': 500,
                        'unit': 'pcs',
                      },
                    ],
                  },
                }
              : {'success': true, 'message': 'ok'};
          handler.resolve(
            Response<dynamic>(requestOptions: options, data: data),
          );
        },
      ),
    );
    final repository = ApiStockOpnameRepository(dio);

    final session = await repository.getActiveSession('tenant-a');
    await repository.recordCount('tenant-a', itemId: 101, physicalQty: 7);
    await repository.submitReview('tenant-a', sessionId: 42);

    expect(requests.map((request) => request.path), [
      '/tenant-a/stock-opname/active',
      '/tenant-a/stock-opname/record-count',
      '/tenant-a/stock-opname/submit-review',
    ]);
    expect(session?.sessionCode, 'SOP-2026-0042');
    expect(session?.warehouse, 'Gudang Utama');
    expect(session?.zone, 'Zona A1');
    expect(session?.items.single.physicalQty, isNull);
    expect(requests[1].data, {'item_id': 101, 'physical_qty': 7});
    expect(requests[2].data, {'session_id': 42});
  });
}
