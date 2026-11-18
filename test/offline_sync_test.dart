import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/core/api/api_exception.dart';
import 'package:omni_warehouse_mob/core/offline/offline_db.dart';
import 'package:omni_warehouse_mob/core/offline/sync_manager.dart';
import 'package:omni_warehouse_mob/features/inbound/inbound_local_id.dart';
import 'package:omni_warehouse_mob/features/inbound/inbound_repository.dart';
import 'package:omni_warehouse_mob/features/outbound/outbound_local_id.dart';
import 'package:omni_warehouse_mob/features/outbound/outbound_repository.dart';
import 'package:omni_warehouse_mob/features/stock_transfer/transfer_local_id.dart';
import 'package:omni_warehouse_mob/features/stock_transfer/transfer_transaction_repository.dart';
import 'package:omni_warehouse_mob/features/stock_opname/stock_opname_local_id.dart';
import 'package:omni_warehouse_mob/features/stock_opname/stock_opname_model.dart';
import 'package:omni_warehouse_mob/features/stock_opname/stock_opname_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('generated offline inbound IDs use the server manifest format', () {
    expect(generateInboundLocalId(), matches(RegExp(r'^TX-INB-[A-Z0-9]{8}$')));
  });

  test('generated offline outbound IDs use the server manifest format', () {
    expect(generateOutboundLocalId(), matches(RegExp(r'^OUT-[A-Z0-9]{8}$')));
  });

  test('generated offline transfer IDs use the server transaction format', () {
    expect(
      generateTransferLocalId(),
      matches(RegExp(r'^TX-TRF-[A-Z0-9]{8}$')),
    );
  });

  test('generated offline opname IDs use a stable transaction format', () {
    expect(
      generateOpnameLocalId(),
      matches(RegExp(r'^TX-OPN-[A-Z0-9]{8}$')),
    );
  });

  setUpAll(() async {
    sqfliteFfiInit();
    await OfflineDb.init(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      initializeHive: false,
    );
  });

  setUp(() async {
    await OfflineDb.setAutomaticSyncEnabled(false);
  });

  test('automatic sync setting defaults to manual and persists', () async {
    expect(await OfflineDb.isAutomaticSyncEnabled(), isFalse);

    await OfflineDb.setAutomaticSyncEnabled(true);
    expect(await OfflineDb.isAutomaticSyncEnabled(), isTrue);

    await OfflineDb.setAutomaticSyncEnabled(false);
    expect(await OfflineDb.isAutomaticSyncEnabled(), isFalse);
  });

  test('transfer and opname stay queued in manual mode', () async {
    const tenantSlug = 'tenant-manual-queues';
    const ownerKey = 'user:manual-queues';
    const session = StockOpnameSession(
      id: 24,
      sessionCode: 'SOP-2026-0024',
      warehouse: 'Gudang Utama',
      zone: 'Zona A1',
      status: 'COUNTING',
      items: [
        StockOpnameItem(
          id: 202,
          skuId: 6,
          locationId: 10,
          sku: 'SKU-202',
          barcode: '00202',
          name: 'Produk 202',
          targetRack: 'RACK-A1-02',
          physicalQty: null,
        ),
      ],
    );
    await OfflineDb.cacheOpnameSession(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      sessionCode: session.sessionCode,
      session: session.toJson(),
    );

    var requestCount = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestCount++;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {'success': true, 'data': <String, dynamic>{}},
            ),
          );
        },
      ),
    );
    final transferRepository = OfflineTransferTransactionRepository(
      api: ApiTransferTransactionRepository(dio),
      dio: dio,
      ownerKey: ownerKey,
      authToken: 'test-token',
      operatorName: 'Operator A',
    );
    final opnameRepository = OfflineStockOpnameRepository(
      api: ApiStockOpnameRepository(dio),
      dio: dio,
      ownerKey: ownerKey,
      authToken: 'test-token',
      operatorName: 'Operator A',
    );

    final transferId = await transferRepository.createTransaction(
      tenantSlug,
      items: const [
        {
          'sku_id': 6,
          'from_location_id': 10,
          'to_location_id': 11,
          'quantity': 2,
        },
      ],
    );
    final opnameOutcome = await opnameRepository.recordCount(
      tenantSlug,
      itemId: 202,
      physicalQty: 4,
    );

    expect(requestCount, 0);
    expect(opnameOutcome.synced, isFalse);
    expect(
      (await OfflineDb.getTransferQueue(
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
      ))
          .single['local_uuid'],
      transferId,
    );
    expect(
      (await OfflineDb.getOpnameQueue(
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
      ))
          .single['status'],
      'pending',
    );
  });

  test('online transfer master data is cached for offline use', () async {
    const tenantSlug = 'tenant-transfer-options-cache';
    const ownerKey = 'user:transfer-options-cache';
    var online = true;
    final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (!online) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: const NetworkException('offline'),
              ),
            );
            return;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {
                  'warehouses': [
                    {'id': 2, 'name': 'Gudang Utama'},
                  ],
                  'available_locations': [
                    {
                      'id': 8,
                      'rack_code': 'RACK-A1',
                      'warehouse_id': 2,
                      'quantity': 12,
                    },
                  ],
                  'products': [
                    {
                      'id': 5,
                      'sku': 'SKU-5',
                      'product_name': 'Produk Lima',
                      'available_stock': 20,
                    },
                  ],
                },
              },
            ),
          );
        },
      ),
    );
    final repository = OfflineTransferTransactionRepository(
      api: ApiTransferTransactionRepository(dio),
      dio: dio,
      ownerKey: ownerKey,
      authToken: 'test-token',
      operatorName: 'Operator A',
    );

    final onlineOptions = await repository.getOptions(tenantSlug);
    online = false;
    final offlineOptions = await repository.getOptions(tenantSlug);

    expect(onlineOptions.skus.single.name, 'Produk Lima');
    expect(onlineOptions.locations.single.name, 'RACK-A1');
    expect(offlineOptions.skus.single.id, 5);
    expect(offlineOptions.locations.single.stockQuantity, 12);
  });

  test('manual batch sync sends every transaction type through its queue',
      () async {
    const tenantSlug = 'tenant-batch-sync';
    const ownerKey = 'user:batch-sync';
    const inboundId = 'TX-INB-BATCH001';
    const outboundId = 'OUT-BATCH0001';
    const transferId = 'TX-TRF-BATCH001';
    const opnameId = 'TX-OPN-BATCH001';
    await OfflineDb.enqueueInbound(
      localUuid: inboundId,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      payload: {'local_uuid': inboundId, 'supplier_id': 1, 'items': []},
      metadata: {'items': []},
    );
    await OfflineDb.enqueueOutbound(
      localUuid: outboundId,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      payload: {'local_uuid': outboundId, 'items': []},
      metadata: {'items': []},
    );
    await OfflineDb.enqueueTransfer(
      localUuid: transferId,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      payload: {'local_uuid': transferId, 'items': []},
      metadata: {'items': []},
    );
    await OfflineDb.enqueueOpname(
      localUuid: opnameId,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      sessionId: 42,
      sessionCode: 'SOP-2026-0042',
      payload: {'local_uuid': opnameId, 'items': []},
      metadata: {'items': []},
    );

    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {
                  'manifest_code': 'INB-1',
                  'transfer_code': 'TRF-1',
                },
              },
            ),
          );
        },
      ),
    );

    final result = await SyncManager.instance.syncAllQueues(
      dio: dio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: 'test-token',
    );

    expect(result.syncedCount, 4);
    expect(result.failureCount, 0);
    expect(requests.map((request) => request.path), [
      '/$tenantSlug/inbound/sync-offline',
      '/$tenantSlug/outbound/sync-offline',
      '/$tenantSlug/stock-transfer/sync-offline',
      '/$tenantSlug/stock-opname/sync-offline',
    ]);
  });

  test('offline transfer retries with the same ID at the transfer sync route',
      () async {
    const localUuid = 'TX-TRF-AB12CD34';
    const tenantSlug = 'tenant-transfer-sync';
    const ownerKey = 'user:transfer-sync';
    final payload = {
      'transfer_code': localUuid,
      'local_uuid': localUuid,
      'transaction_uuid': localUuid,
      'items': [
        {
          'sku_id': 5,
          'from_location_id': 8,
          'to_location_id': 9,
          'quantity': 3,
        },
      ],
    };
    await OfflineDb.enqueueTransfer(
      localUuid: localUuid,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      payload: payload,
      metadata: {'items': []},
    );

    expect(
      await OfflineDb.countTransferQueue(
        tenantSlug: tenantSlug,
        ownerKey: 'user:another-user',
      ),
      0,
    );

    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    var shouldFail = true;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (shouldFail) {
            shouldFail = false;
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: const NetworkException('offline'),
              ),
            );
            return;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {'transfer_code': 'TRF-100'},
              },
            ),
          );
        },
      ),
    );

    final firstResult = await SyncManager.instance.syncTransferQueue(
      dio: dio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: 'test-token',
    );
    final failedRow = await OfflineDb.getTransferQueueItem(
      localUuid: localUuid,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
    );
    expect(firstResult.failures, hasLength(1));
    expect(failedRow?['status'], 'error');
    expect(failedRow?['retry_count'], 1);

    final retryResult = await SyncManager.instance.syncTransferQueue(
      dio: dio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: 'test-token',
    );

    expect(retryResult.syncedCount, 1);
    expect(retryResult.failures, isEmpty);
    expect(requests, hasLength(2));
    expect(
        requests.map((request) => request.path),
        everyElement(
          '/$tenantSlug/stock-transfer/sync-offline',
        ));
    expect(requests[0].data['local_uuid'], localUuid);
    expect(requests[0].data['transaction_uuid'], localUuid);
    expect(requests[1].data['local_uuid'], localUuid);
    expect(requests[1].headers['Authorization'], 'Bearer test-token');
    final savedRow = await OfflineDb.getTransferQueueItem(
      localUuid: localUuid,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
    );
    expect(savedRow?['status'], 'success');
    expect(savedRow?['server_transfer_code'], 'TRF-100');
  });

  test('transfer drafts are stored locally with cached master details',
      () async {
    const tenantSlug = 'tenant-transfer-local';
    const ownerKey = 'user:transfer-local';
    await OfflineDb.cacheTransferOptions(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      options: {
        'warehouses': [],
        'locations': [
          {'id': 8, 'rack_code': 'RACK-A1'},
          {'id': 9, 'rack_code': 'RACK-B1'},
        ],
        'skus': [
          {'id': 5, 'sku': 'SKU-5', 'name': 'Produk Lima', 'unit': 'pcs'},
        ],
      },
    );
    final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              error: const NetworkException('offline'),
            ),
          );
        },
      ),
    );
    final repository = OfflineTransferTransactionRepository(
      api: ApiTransferTransactionRepository(dio),
      dio: dio,
      ownerKey: ownerKey,
      authToken: 'test-token',
      operatorName: 'Operator Lokal',
    );

    final options = await repository.getOptions(tenantSlug);
    final localId = await repository.createTransaction(
      tenantSlug,
      items: const [
        {
          'sku_id': 5,
          'from_location_id': 8,
          'to_location_id': 9,
          'quantity': 3,
        },
      ],
      notes: 'Pindah rak',
    );
    final result = await repository.getTransactions(tenantSlug);

    expect(options.skus.single.name, 'Produk Lima');
    expect(localId, matches(RegExp(r'^TX-TRF-[A-Z0-9]{8}$')));
    expect(result.transactions.single.code, localId);
    expect(result.transactions.single.isOfflinePending, isTrue);
    expect(result.transactions.single.items.single.productName, 'Produk Lima');
    expect(result.transactions.single.items.single.fromLocation, 'RACK-A1');

    await repository.cancelTransaction(tenantSlug, localId!);
    final cancelledRow = await OfflineDb.getTransferQueueItem(
      localUuid: localId,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
    );
    expect(cancelledRow?['status'], 'cancelled');
  });

  test('offline opname counts merge and retry through sync-offline', () async {
    const tenantSlug = 'tenant-opname-offline';
    const ownerKey = 'user:opname-offline';
    const session = StockOpnameSession(
      id: 42,
      sessionCode: 'SOP-2026-0042',
      warehouse: 'Gudang Utama',
      zone: 'Zona A1',
      status: 'COUNTING',
      items: [
        StockOpnameItem(
          id: 101,
          skuId: 5,
          locationId: 8,
          sku: 'SKU-101',
          barcode: '00101',
          name: 'Produk 101',
          targetRack: 'RACK-A1-01',
          physicalQty: null,
        ),
      ],
    );
    await OfflineDb.cacheOpnameSession(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      sessionCode: session.sessionCode,
      session: session.toJson(),
    );
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              error: const NetworkException('offline'),
            ),
          );
        },
      ),
    );
    final repository = OfflineStockOpnameRepository(
      api: ApiStockOpnameRepository(dio),
      dio: dio,
      ownerKey: ownerKey,
      authToken: 'test-token',
      operatorName: 'Operator A',
    );

    final offlineSession = await repository.getActiveSession(tenantSlug);
    final firstOutcome = await repository.recordCount(
      tenantSlug,
      itemId: 101,
      physicalQty: 7,
    );
    await SyncManager.instance.syncOpnameQueue(
      dio: dio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: 'test-token',
    );
    final firstQueue = await OfflineDb.getOpnameQueue(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
    );
    final localUuid = firstQueue.single['local_uuid'] as String;
    await repository.recordCount(
      tenantSlug,
      itemId: 101,
      physicalQty: 9,
    );
    await SyncManager.instance.syncOpnameQueue(
      dio: dio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: 'test-token',
    );
    final retryQueue = await OfflineDb.getOpnameQueue(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
    );
    final payload = decodeJsonMap(retryQueue.single['payload_json'] as String);

    expect(offlineSession?.sessionCode, session.sessionCode);
    expect(firstOutcome.synced, isFalse);
    expect(localUuid, matches(RegExp(r'^TX-OPN-[A-Z0-9]{8}$')));
    expect(retryQueue, hasLength(1));
    expect(retryQueue.single['local_uuid'], localUuid);
    expect(requests, hasLength(3));
    expect(
      requests.skip(1).map((request) => request.path),
      everyElement('/$tenantSlug/stock-opname/sync-offline'),
    );
    expect(requests[1].data['transaction_uuid'], localUuid);
    expect(requests[1].data['items'].single['item_id'], 101);
    expect(requests[1].data['items'].single['physical_qty'], 7);
    expect(payload['items'].single['physical_qty'], 9);
    expect(payload['should_submit_review'], isFalse);

    await repository.submitReview(tenantSlug, sessionId: 42);
    final reviewQueue = await OfflineDb.getOpnameQueue(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
    );
    final reviewPayload =
        decodeJsonMap(reviewQueue.single['payload_json'] as String);
    expect(reviewQueue.single['local_uuid'], localUuid);
    expect(reviewPayload['should_submit_review'], isTrue);
    expect(reviewPayload['items'].single['physical_qty'], 9);
  });

  test(
    'sync is owner scoped and successful UUIDs are not posted twice',
    () async {
      const localUuid = 'inbound-local-uuid-1';
      await OfflineDb.enqueueInbound(
        localUuid: localUuid,
        tenantSlug: 'tenant-a',
        ownerKey: 'user:1',
        payload: {
          'local_uuid': localUuid,
          'supplier_id': 3,
          'should_commit': false,
          'items': [
            {'sku_id': 17, 'po_qty': 4, 'good_qty': 3, 'damaged_qty': 1},
          ],
        },
        metadata: {'supplier_name': 'Supplier A', 'items': []},
      );

      expect(
        await OfflineDb.countInboundQueue(
          tenantSlug: 'tenant-a',
          ownerKey: 'user:2',
        ),
        0,
      );

      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: {
                  'success': true,
                  'data': {'manifest_code': 'INB-100'},
                },
              ),
            );
          },
        ),
      );

      final manager = SyncManager.instance;
      final result = await manager.syncInboundQueue(
        dio: dio,
        tenantSlug: 'tenant-a',
        ownerKey: 'user:1',
        authToken: 'test-token',
      );
      final repeatedResult = await manager.syncInboundQueue(
        dio: dio,
        tenantSlug: 'tenant-a',
        ownerKey: 'user:1',
        authToken: 'test-token',
      );

      expect(result.syncedCount, 1);
      expect(result.failures, isEmpty);
      expect(repeatedResult.syncedCount, 0);
      expect(requests, hasLength(1));
      expect(requests.single.path, '/tenant-a/inbound/sync-offline');
      expect(requests.single.data['local_uuid'], localUuid);
      expect(requests.single.headers['Authorization'], 'Bearer test-token');
      expect(
        await OfflineDb.countInboundQueue(
          tenantSlug: 'tenant-a',
          ownerKey: 'user:1',
        ),
        0,
      );
    },
  );

  test('failed sync remains queued and retries with the same UUID', () async {
    const localUuid = 'inbound-retry-uuid-1';
    await OfflineDb.enqueueInbound(
      localUuid: localUuid,
      tenantSlug: 'tenant-a',
      ownerKey: 'user:retry',
      payload: {
        'local_uuid': localUuid,
        'supplier_id': 3,
        'should_commit': false,
        'items': [
          {'sku_id': 17, 'po_qty': 4, 'good_qty': 4, 'damaged_qty': 0},
        ],
      },
      metadata: {'supplier_name': 'Supplier A', 'items': []},
    );

    final failingDio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    failingDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              error: const NetworkException('offline'),
            ),
          );
        },
      ),
    );
    final manager = SyncManager.instance;
    final failedResult = await manager.syncInboundQueue(
      dio: failingDio,
      tenantSlug: 'tenant-a',
      ownerKey: 'user:retry',
      authToken: 'test-token',
    );

    expect(failedResult.failures, hasLength(1));
    expect(failedResult.failures.single.message, 'offline');
    expect(
      await OfflineDb.countInboundQueue(
        tenantSlug: 'tenant-a',
        ownerKey: 'user:retry',
      ),
      1,
    );

    final retryRequests = <RequestOptions>[];
    final retryDio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    retryDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          retryRequests.add(options);
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {'success': true, 'data': null},
            ),
          );
        },
      ),
    );
    final retriedResult = await manager.syncInboundQueue(
      dio: retryDio,
      tenantSlug: 'tenant-a',
      ownerKey: 'user:retry',
      authToken: 'test-token',
    );

    expect(retriedResult.syncedCount, 1);
    expect(retryRequests.single.data['local_uuid'], localUuid);
  });

  test('outbound sync posts stable local IDs and is owner scoped', () async {
    const localUuid = 'OUT-A1B2C3D4';
    const tenantSlug = 'tenant-outbound';
    const ownerKey = 'user:outbound';
    final payload = {
      'manifest_code': localUuid,
      'local_uuid': localUuid,
      'transaction_uuid': localUuid,
      'customer_id': 12,
      'should_commit': false,
      'items': [
        {
          'sku_id': 34,
          'so_qty': 8,
          'good_qty': 6,
          'damaged_qty': 1,
          'source_rack_id': 5,
          'source_rack': 'RACK-B2-01',
          'damage_note': 'Outer box dented',
        },
      ],
    };
    await OfflineDb.enqueueOutbound(
      localUuid: localUuid,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      payload: payload,
      metadata: {'customer_name': 'Customer A', 'items': []},
    );

    expect(
      await OfflineDb.countOutboundQueue(
        tenantSlug: tenantSlug,
        ownerKey: 'user:other',
      ),
      0,
    );

    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {'manifest_code': localUuid},
              },
            ),
          );
        },
      ),
    );

    final result = await SyncManager.instance.syncOutboundQueue(
      dio: dio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: 'test-token',
    );
    final repeatedResult = await SyncManager.instance.syncOutboundQueue(
      dio: dio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: 'test-token',
    );

    expect(result.syncedCount, 1);
    expect(result.failures, isEmpty);
    expect(repeatedResult.syncedCount, 0);
    expect(requests, hasLength(1));
    expect(requests.single.path, '/$tenantSlug/outbound/sync-offline');
    expect(requests.single.data, payload);
    expect(requests.single.headers['Authorization'], 'Bearer test-token');
    final saved = await OfflineDb.getOutboundQueueItem(
      localUuid: localUuid,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
    );
    expect(saved?['status'], 'success');
    expect(saved?['server_manifest_code'], localUuid);
  });

  test('failed outbound sync retries with the same local ID', () async {
    const localUuid = 'OUT-RETRY123';
    const tenantSlug = 'tenant-outbound-retry';
    const ownerKey = 'user:outbound-retry';
    await OfflineDb.enqueueOutbound(
      localUuid: localUuid,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      payload: {
        'manifest_code': localUuid,
        'local_uuid': localUuid,
        'transaction_uuid': localUuid,
        'customer_id': 12,
        'items': [
          {'sku_id': 34, 'so_qty': 2, 'good_qty': 0, 'damaged_qty': 0},
        ],
      },
      metadata: {'customer_name': 'Customer Retry', 'items': []},
    );

    final failingDio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    failingDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              error: const NetworkException('offline'),
            ),
          );
        },
      ),
    );
    final manager = SyncManager.instance;
    final failedResult = await manager.syncOutboundQueue(
      dio: failingDio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: 'test-token',
    );
    expect(failedResult.failures.single.message, 'offline');

    final retryRequests = <RequestOptions>[];
    final retryDio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    retryDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          retryRequests.add(options);
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {'success': true, 'data': null},
            ),
          );
        },
      ),
    );
    final retriedResult = await manager.syncOutboundQueue(
      dio: retryDio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: 'test-token',
    );

    expect(retriedResult.syncedCount, 1);
    expect(retryRequests.single.path, '/$tenantSlug/outbound/sync-offline');
    expect(retryRequests.single.data['local_uuid'], localUuid);
  });

  test(
    'local outbound manifests reopen and persist picking allocation',
    () async {
      const localUuid = 'OUT-PICK1234';
      const tenantSlug = 'tenant-outbound-local';
      const ownerKey = 'user:outbound-local';
      await OfflineDb.cacheOutboundOptions(
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
        options: {
          'locations': [
            {'id': 5, 'rack_code': 'RACK-B2-01', 'stock_quantity': 15},
          ],
        },
      );
      await OfflineDb.enqueueOutbound(
        localUuid: localUuid,
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
        payload: {
          'manifest_code': localUuid,
          'local_uuid': localUuid,
          'customer_id': 12,
          'should_commit': false,
          'items': [
            {'sku_id': 34, 'so_qty': 8, 'good_qty': 0, 'damaged_qty': 0},
          ],
        },
        metadata: {
          'customer_name': 'Customer Local',
          'items': [
            {
              'sku_id': 34,
              'sku': 'SKU-34',
              'barcode': '0034',
              'name': 'Product Local',
              'so_qty': 8,
            },
          ],
        },
      );

      final notifier = OutboundNotifier(
        repository: _OfflineOnlyOutboundRepository(),
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
      );
      final detail = await notifier.loadManifestDetail(localUuid);
      expect(detail.manifest.isOfflinePending, isTrue);
      expect(detail.manifest.customer, 'Customer Local');
      expect(detail.items.single.id, 'local:0');
      expect(detail.items.single.barcode, '0034');
      expect(detail.locations.single.rackCode, 'RACK-B2-01');

      await notifier.verifyBarcode(localUuid, '0034');
      await notifier.savePicking(
        manifestCode: localUuid,
        itemId: 'local:0',
        goodQty: 6,
        damagedQty: 1,
        sourceRackId: 5,
        sourceRack: 'RACK-B2-01',
        damageNote: 'Outer box dented',
      );

      final saved = await OfflineDb.getOutboundQueueItem(
        localUuid: localUuid,
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
      );
      final savedPayload = decodeJsonMap(saved!['payload_json'] as String);
      final savedItem = (savedPayload['items'] as List).single;
      expect(savedItem['good_qty'], 6);
      expect(savedItem['damaged_qty'], 1);
      expect(savedItem['source_rack_id'], 5);
      expect(savedItem['source_rack'], 'RACK-B2-01');
      expect(savedItem['damage_note'], 'Outer box dented');
    },
  );

  test(
    'local inbound manifests can be reopened and edited before sync',
    () async {
      const localUuid = 'offline-receiving-uuid';
      const tenantSlug = 'tenant-local';
      const ownerKey = 'user-local';
      await OfflineDb.cacheInboundOptions(
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
        options: {
          'available_racks': ['R-01'],
        },
      );
      await OfflineDb.enqueueInbound(
        localUuid: localUuid,
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
        payload: {
          'local_uuid': localUuid,
          'supplier_id': 3,
          'should_commit': false,
          'items': [
            {'sku_id': 17, 'po_qty': 4, 'good_qty': 0, 'damaged_qty': 0},
          ],
        },
        metadata: {
          'supplier_id': 3,
          'supplier_name': 'Supplier Local',
          'items': [
            {
              'sku_id': 17,
              'sku': 'SKU-17',
              'barcode': '123456',
              'name': 'Product Local',
              'po_qty': 4,
              'good_qty': 0,
              'damaged_qty': 0,
            },
          ],
        },
      );

      final notifier = InboundNotifier(
        _OfflineOnlyRepository(),
        tenantSlug,
        ownerKey,
      );
      final initial = await notifier.loadManifestDetail('LOCAL-$localUuid');
      expect(initial.manifest.isOfflinePending, isTrue);
      expect(initial.items.single.barcode, '123456');
      expect(initial.locations.single.rackCode, 'R-01');

      await notifier.updateItemTally(
        manifestCode: 'LOCAL-$localUuid',
        itemId: initial.items.single.id,
        goodQty: 3,
        damagedQty: 1,
        targetRack: 'R-01',
        damageNote: 'Kemasan rusak',
      );

      final updated = await notifier.loadManifestDetail('LOCAL-$localUuid');
      expect(updated.items.single.goodQty, 3);
      expect(updated.items.single.damagedQty, 1);
      expect(updated.items.single.targetRack, 'R-01');
      expect(updated.items.single.notes, 'Kemasan rusak');

      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                data: {
                  'success': true,
                  'data': {'manifest_code': 'INB-LOCAL'},
                },
              ),
            );
          },
        ),
      );
      final syncResult = await SyncManager.instance.syncInboundQueue(
        dio: dio,
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
        authToken: 'test-token',
      );
      expect(syncResult.syncedCount, 1);
      expect(requests.single.data['items'][0]['good_qty'], 3);
      expect(requests.single.data['items'][0]['damaged_qty'], 1);
      expect(requests.single.data['items'][0]['damage_note'], 'Kemasan rusak');
    },
  );
}

class _OfflineOnlyRepository implements InboundRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OfflineOnlyOutboundRepository implements OutboundRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
