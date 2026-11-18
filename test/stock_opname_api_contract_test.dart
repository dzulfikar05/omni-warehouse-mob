import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/core/api/api_exception.dart';
import 'package:omni_warehouse_mob/features/stock_opname/stock_opname_repository.dart';

void main() {
  test('parses paginated sessions and selected session detail', () async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final response = options.path.endsWith('/sessions/42')
              ? {
                  'success': true,
                  'message': 'ok',
                  'data': {
                    'session': {
                      'id': 42,
                      'session_code': 'SOP-2026-0042',
                      'status': 'COUNTING',
                      'warehouse_id': 3,
                      'warehouse_name': 'Gudang Utama',
                      'warehouse_code': 'WH-01',
                      'location_id': 8,
                      'location_label': 'Rak A1',
                      'auditor_name': 'Operator A',
                      'created_at': '2026-11-18T08:30:00Z',
                    },
                    'items': [
                      {
                        'id': 101,
                        'sku_code': 'SKU-101',
                        'barcode': '00101',
                        'product_name': 'Produk 101',
                        'location_id': 8,
                        'location_label': 'Rak A1',
                        'target_rack': 'RACK-A1-01',
                        'physical_qty': null,
                        'system_qty': 500,
                        'variance': 492,
                      },
                    ],
                  },
                }
              : {
                  'success': true,
                  'message': 'ok',
                  'data': {
                    'data': [
                      {
                        'id': 42,
                        'session_code': 'SOP-2026-0042',
                        'status': 'COUNTING',
                        'warehouse_id': 3,
                        'warehouse_name': 'Gudang Utama',
                        'warehouse_code': 'WH-01',
                        'location_id': 8,
                        'location_label': 'Rak A1',
                        'auditor_name': 'Operator A',
                        'created_at': '2026-11-18T08:30:00Z',
                        'total_items': 10,
                        'counted_items': 4,
                      },
                    ],
                    'current_page': 2,
                    'last_page': 5,
                    'total': 41,
                  },
                };
          handler.resolve(
            Response<dynamic>(requestOptions: options, data: response),
          );
        },
      ),
    );
    final repository = ApiStockOpnameRepository(dio);

    final page = await repository.getSessions('tenant-a', page: 2);
    final detail = await repository.getSessionDetail('tenant-a', sessionId: 42);

    expect(requests[0].path, '/tenant-a/stock-opname');
    expect(requests[0].queryParameters, {'page': 2});
    expect(page.currentPage, 2);
    expect(page.lastPage, 5);
    expect(page.total, 41);
    expect(page.sessions.single.countedItems, 4);
    expect(page.sessions.single.totalItems, 10);
    expect(page.sessions.single.locationLabel, 'Rak A1');
    expect(requests[1].path, '/tenant-a/stock-opname/sessions/42');
    expect(detail.sessionCode, 'SOP-2026-0042');
    expect(detail.locationId, 8);
    expect(detail.items.single.physicalQty, isNull);
  });

  test('uses the stock opname endpoints and scoped count payloads', () async {
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
                      'location_id': 8,
                      'location_label': 'Rak A1',
                      'zone': {'name': 'Zona lama'},
                    },
                    'items': [
                      {
                        'id': 101,
                        'sku': {'sku': 'SKU-101', 'barcode': '00101'},
                        'product_name': 'Produk 101',
                        'location_id': 8,
                        'location_label': 'Rak A1',
                        'target_rack': 'RACK-A1-01',
                        'physical_qty': null,
                        'system_qty': 500,
                        'variance': 492,
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

    final session = await repository.getActiveSession(
      'tenant-a',
      sessionId: 42,
    );
    await repository.recordCount(
      'tenant-a',
      itemId: 101,
      physicalQty: 7,
      locationId: session!.locationId,
      targetRack: session.items.single.targetRack,
    );
    await repository.submitReview('tenant-a', sessionId: 42);

    expect(requests.map((request) => request.path), [
      '/tenant-a/stock-opname/active',
      '/tenant-a/stock-opname/record-count',
      '/tenant-a/stock-opname/submit-review',
    ]);
    expect(requests.first.queryParameters, {'session_id': 42});
    expect(session.sessionCode, 'SOP-2026-0042');
    expect(session.warehouse, 'Gudang Utama');
    expect(session.locationId, 8);
    expect(session.locationLabel, 'Rak A1');
    expect(session.items.single.physicalQty, isNull);
    expect(requests[1].data, {
      'item_id': 101,
      'physical_qty': 7,
      'location_id': 8,
      'target_rack': 'RACK-A1-01',
    });
    expect(requests[2].data, {'session_id': 42});
  });

  test(
    'surfaces backend validation details for a 422 count response',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: 422,
                  data: {
                    'message': 'Data tidak valid.',
                    'errors': {
                      'physical_qty': ['Jumlah fisik harus bilangan bulat.'],
                    },
                  },
                ),
              ),
            );
          },
        ),
      );

      await expectLater(
        ApiStockOpnameRepository(
          dio,
        ).recordCount('tenant-a', itemId: 101, physicalQty: 1.5),
        throwsA(
          isA<ValidationException>().having(
            (error) => error.message,
            'message',
            contains('Jumlah fisik harus bilangan bulat.'),
          ),
        ),
      );
    },
  );

  test('preserves readable unauthorized and not-found API errors', () async {
    for (final status in [401, 404]) {
      final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: status,
                data: {
                  'message': status == 401
                      ? 'Token kedaluwarsa.'
                      : 'Sesi tidak ditemukan.',
                },
              ),
            ),
          ),
        ),
      );

      await expectLater(
        ApiStockOpnameRepository(
          dio,
        ).getSessionDetail('tenant-a', sessionId: 404),
        throwsA(
          isA<AppException>().having(
            (error) => error.message,
            'message',
            status == 401 ? 'Token kedaluwarsa.' : 'Sesi tidak ditemukan.',
          ),
        ),
      );
    }
  });
}
