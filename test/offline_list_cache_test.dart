import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/core/api/api_exception.dart';
import 'package:omni_warehouse_mob/core/offline/offline_db.dart';
import 'package:omni_warehouse_mob/features/inbound/inbound_repository.dart';
import 'package:omni_warehouse_mob/features/outbound/outbound_repository.dart';
import 'package:omni_warehouse_mob/features/stock_opname/stock_opname_repository.dart';
import 'package:omni_warehouse_mob/features/stock_transfer/transfer_transaction_repository.dart';
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

  test('all transaction list APIs serve their last successful snapshot offline',
      () async {
    const ownerKey = 'user:list-snapshot';
    const tenantSlug = 'tenant-list-snapshot';
    final inbound = {
      'data': {
        'manifests': {
          'data': [
            {
              'manifest_code': 'IN-100',
              'supplier_name': 'Supplier A',
              'total_units': 5,
              'status': 'RECEIVING',
            },
          ],
        },
        'summary': {'total': 1},
      },
    };
    final outbound = {
      'success': true,
      'data': {
        'manifests': {
          'data': [
            {
              'manifest_code': 'OUT-100',
              'customer': {'name': 'Customer A'},
              'status': 'PENDING',
              'items': [],
            },
          ],
        },
        'summary': {'total': 1},
      },
    };
    final transfer = {
      'success': true,
      'data': {
        'transfers': [
          {
            'transfer_code': 'TR-100',
            'status': 'COMPLETED',
            'items': [
              {'sku_id': 3, 'sku_code': 'SKU-3', 'quantity': 2},
            ],
          },
        ],
      },
    };
    final opname = {
      'success': true,
      'data': {
        'data': [
          {
            'id': 7,
            'session_code': 'SOP-7',
            'status': 'COUNTING',
            'warehouse_name': 'Warehouse A',
            'total_items': 2,
            'counted_items': 1,
          },
        ],
        'current_page': 1,
        'last_page': 1,
        'total': 1,
      },
    };

    final inboundRepository = ApiInboundRepository(
      _dioWithResponse(inbound),
      ownerKey: ownerKey,
    );
    expect(
      (await inboundRepository.getManifests(tenantSlug)).manifests.single.code,
      'IN-100',
    );
    expect(
      (await ApiInboundRepository(
        _offlineDio(),
        ownerKey: ownerKey,
      ).getManifests(tenantSlug))
          .manifests
          .single
          .code,
      'IN-100',
    );

    final outboundRepository = ApiOutboundRepository(
      _dioWithResponse(outbound),
      ownerKey: ownerKey,
    );
    expect(
      (await outboundRepository.getManifests(tenantSlug)).manifests.single.code,
      'OUT-100',
    );
    expect(
      (await ApiOutboundRepository(
        _offlineDio(),
        ownerKey: ownerKey,
      ).getManifests(tenantSlug))
          .manifests
          .single
          .code,
      'OUT-100',
    );

    final transferRepository = ApiTransferTransactionRepository(
      _dioWithResponse(transfer),
      ownerKey: ownerKey,
    );
    expect(
      (await transferRepository.getTransactions(tenantSlug))
          .transactions
          .single
          .code,
      'TR-100',
    );
    expect(
      (await ApiTransferTransactionRepository(
        _offlineDio(),
        ownerKey: ownerKey,
      ).getTransactions(tenantSlug))
          .transactions
          .single
          .code,
      'TR-100',
    );

    final opnameRepository = ApiStockOpnameRepository(
      _dioWithResponse(opname),
      ownerKey: ownerKey,
    );
    expect(
      (await opnameRepository.getSessions(tenantSlug))
          .sessions
          .single
          .sessionCode,
      'SOP-7',
    );
    expect(
      (await ApiStockOpnameRepository(
        _offlineDio(),
        ownerKey: ownerKey,
      ).getSessions(tenantSlug))
          .sessions
          .single
          .sessionCode,
      'SOP-7',
    );
    final offlineOpnameRepository = OfflineStockOpnameRepository(
      api: ApiStockOpnameRepository(_offlineDio(), ownerKey: ownerKey),
      dio: _offlineDio(),
      ownerKey: ownerKey,
      authToken: 'test-token',
      operatorName: 'Operator A',
    );
    expect(
      (await offlineOpnameRepository.getSessions(tenantSlug))
          .sessions
          .single
          .sessionCode,
      'SOP-7',
    );
  });
}

Dio _dioWithResponse(Object responseData) {
  final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          data: responseData,
        ),
      ),
    ),
  );
  return dio;
}

Dio _offlineDio() {
  final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const NetworkException('offline'),
        ),
      ),
    ),
  );
  return dio;
}
