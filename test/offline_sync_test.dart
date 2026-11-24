import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/core/api/api_exception.dart';
import 'package:omni_warehouse_mob/core/offline/offline_db.dart';
import 'package:omni_warehouse_mob/core/offline/sync_manager.dart';
import 'package:omni_warehouse_mob/features/inbound/inbound_local_id.dart';
import 'package:omni_warehouse_mob/features/inbound/inbound_model.dart';
import 'package:omni_warehouse_mob/features/inbound/inbound_repository.dart';
import 'package:omni_warehouse_mob/features/outbound/outbound_local_id.dart';
import 'package:omni_warehouse_mob/features/outbound/outbound_model.dart';
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

  test('generated offline transfer local IDs use the dated TRF format', () {
    expect(
      generateTransferLocalId(DateTime(2026, 11, 18)),
      matches(RegExp(r'^TRF-20261118-[A-Z0-9]{4}$')),
    );
  });

  test('generated transfer sync identities are UUIDs', () {
    expect(
      generateTransferLocalUuid(),
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('generated offline opname IDs use a stable transaction format', () {
    expect(generateOpnameLocalId(), matches(RegExp(r'^TX-OPN-[A-Z0-9]{8}$')));
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

  test(
    'offline opname list includes all owner-scoped cached sessions',
    () async {
      const tenantSlug = 'tenant-opname-list-offline';
      const ownerKey = 'user:opname-list-offline';
      for (final sessionId in [42, 43]) {
        final session = StockOpnameSession(
          id: sessionId,
          sessionCode: 'SOP-2026-00$sessionId',
          warehouse: 'Gudang Utama',
          zone: '',
          status: 'COUNTING',
          items: const [],
        );
        await OfflineDb.cacheOpnameSession(
          tenantSlug: tenantSlug,
          ownerKey: ownerKey,
          sessionCode: session.sessionCode,
          session: session.toJson(),
        );
      }

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
      final repository = OfflineStockOpnameRepository(
        api: ApiStockOpnameRepository(dio),
        dio: dio,
        ownerKey: ownerKey,
        authToken: 'test-token',
        operatorName: 'Operator A',
      );

      final page = await repository.getSessions(tenantSlug);

      expect(page.sessions.map((session) => session.id), containsAll([42, 43]));
      expect(page.total, 2);
      expect(page.hasMore, isFalse);
    },
  );

  test(
    'transfer validation and authorization errors keep the queue retryable',
    () async {
      const tenantSlug = 'tenant-transfer-errors';
      const ownerKey = 'user:transfer-errors';
      const localUuids = [
        '33333333-3333-4333-8333-333333333333',
        '44444444-4444-4444-8444-444444444444',
        '55555555-5555-4555-8555-555555555555',
      ];
      const statuses = [401, 404, 422];
      final errorsByStatus = <int, dynamic>{
        401: {'message': 'Token tidak berlaku.'},
        404: {'message': 'Lokasi tidak ditemukan.'},
        422: {
          'message': 'Data transfer tidak valid.',
          'errors': {
            'items.0.quantity': ['Jumlah transfer minimal 1.'],
          },
        },
      };
      for (final localUuid in localUuids) {
        await OfflineDb.enqueueTransfer(
          localUuid: localUuid,
          tenantSlug: tenantSlug,
          ownerKey: ownerKey,
          payload: {
            'local_uuid': localUuid,
            'items': [
              {
                'sku_id': 5,
                'from_location_id': 8,
                'to_location_id': 9,
                'quantity': 1,
              },
            ],
          },
          metadata: {'items': []},
        );
      }

      final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
      var index = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final status = statuses[index++];
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: status,
                  data: errorsByStatus[status],
                ),
              ),
            );
          },
        ),
      );

      final result = await SyncManager.instance.syncTransferQueue(
        dio: dio,
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
        authToken: 'test-token',
      );

      expect(result.syncedCount, 0);
      expect(result.failures, hasLength(3));
      expect(
        result.failures.any(
          (failure) => failure.message.contains('Jumlah transfer minimal 1.'),
        ),
        isTrue,
      );
      final repository = OfflineTransferTransactionRepository(
        api: ApiTransferTransactionRepository(dio),
        dio: dio,
        ownerKey: ownerKey,
        authToken: 'test-token',
        operatorName: 'Operator A',
      );
      await expectLater(
        repository.updateTransaction(
          tenantSlug,
          localUuids.first,
          items: const [
            {
              'sku_id': 5,
              'from_location_id': 8,
              'to_location_id': 9,
              'quantity': 2,
            },
          ],
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        repository.cancelTransaction(tenantSlug, localUuids.first),
        throwsA(isA<StateError>()),
      );
      for (final localUuid in localUuids) {
        final row = await OfflineDb.getTransferQueueItem(
          localUuid: localUuid,
          tenantSlug: tenantSlug,
          ownerKey: ownerKey,
        );
        expect(row?['status'], 'error');
        expect(row?['retry_count'], 1);
        expect(
          decodeJsonMap(row!['payload_json'] as String)['local_uuid'],
          localUuid,
        );
      }
    },
  );

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
    await OfflineDb.cacheTransferOptions(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      options: {
        'warehouses': [],
        'locations': [
          {'id': 10, 'rack_code': 'RACK-A1'},
          {'id': 11, 'rack_code': 'RACK-B1'},
        ],
        'skus': [
          {'id': 6, 'sku': 'SKU-202', 'name': 'Produk 202'},
        ],
      },
    );

    var requestCount = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestCount++;
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

    expect(requestCount, 3);
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

  test(
    'manual batch sync sends every transaction type through its queue',
    () async {
      const tenantSlug = 'tenant-batch-sync';
      const ownerKey = 'user:batch-sync';
      const inboundId = 'TX-INB-BATCH001';
      const outboundId = 'OUT-BATCH0001';
      const transferId = '11111111-1111-4111-8111-111111111111';
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
        payload: {
          'session_id': 42,
          'session_code': 'SOP-2026-0042',
          'local_uuid': opnameId,
          'items': [
            {
              'item_id': 101,
              'location_id': 8,
              'target_rack': 'RACK-A1-01',
              'physical_qty': 3,
            },
          ],
        },
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
                    'status': 'completed',
                    'already_synced': false,
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
    },
  );

  test(
    'offline transfer retries with the same ID at the transfer sync route',
    () async {
      const localUuid = '22222222-2222-4222-8222-222222222222';
      const tenantSlug = 'tenant-transfer-sync';
      const ownerKey = 'user:transfer-sync';
      final payload = {
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
                  'data': {
                    'transfer_code': 'TRF-100',
                    'status': 'completed',
                    'already_synced': true,
                  },
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
        everyElement('/$tenantSlug/stock-transfer/sync-offline'),
      );
      expect(requests[0].data['local_uuid'], localUuid);
      expect(requests[0].data['transaction_uuid'], localUuid);
      expect(requests[1].data['local_uuid'], localUuid);
      expect(requests[1].data['transaction_uuid'], localUuid);
      expect(requests[1].headers['Authorization'], 'Bearer test-token');
      final savedRow = await OfflineDb.getTransferQueueItem(
        localUuid: localUuid,
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
      );
      expect(savedRow?['status'], 'success');
      expect(savedRow?['server_transfer_code'], 'TRF-100');
      expect(
        decodeJsonMap(savedRow!['metadata_json'] as String)['server_status'],
        'completed',
      );
    },
  );

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
    await expectLater(
      repository.createTransaction(
        tenantSlug,
        items: const [
          {
            'sku_id': 999,
            'from_location_id': 8,
            'to_location_id': 9,
            'quantity': 1,
          },
        ],
      ),
      throwsA(isA<ValidationException>()),
    );
    expect(
      await OfflineDb.countTransferQueue(
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
      ),
      0,
    );
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
    expect(
      localId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    final queuedTransfer = await OfflineDb.getTransferQueueItem(
      localUuid: localId!,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
    );
    final queuedPayload = decodeJsonMap(
      queuedTransfer!['payload_json'] as String,
    );
    expect(queuedPayload['local_uuid'], localId);
    expect(queuedPayload['transaction_uuid'], localId);
    expect(queuedPayload['client_timestamp'], queuedTransfer['created_at']);
    expect(queuedPayload['notes'], 'Pindah rak');
    expect(queuedPayload.containsKey('transfer_code'), isFalse);
    expect(queuedPayload['items'], [
      {'sku_id': 5, 'from_location_id': 8, 'to_location_id': 9, 'quantity': 3},
    ]);
    final localCode = decodeJsonMap(
      queuedTransfer['metadata_json'] as String,
    )['local_id'];
    expect(localCode, matches(RegExp(r'^TRF-\d{8}-[A-Z0-9]{4}$')));
    final createdAt = queuedTransfer['created_at'] as String;
    expect(
      localCode,
      startsWith('TRF-${createdAt.substring(0, 10).replaceAll('-', '')}-'),
    );
    expect(result.transactions.single.code, localCode);
    expect(result.transactions.single.isOfflinePending, isTrue);
    expect(result.transactions.single.items.single.productName, 'Produk Lima');
    expect(result.transactions.single.items.single.fromLocation, 'RACK-A1');

    await repository.cancelTransaction(tenantSlug, localId);
    final cancelledRow = await OfflineDb.getTransferQueueItem(
      localUuid: localId,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
    );
    expect(cancelledRow?['status'], 'cancelled');
  });

  test('online transfer creation posts directly even in manual sync mode',
      () async {
    const tenantSlug = 'tenant-transfer-online-direct';
    const ownerKey = 'user:transfer-online-direct';
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
          {'id': 5, 'sku': 'SKU-5', 'name': 'Produk Lima'},
        ],
      },
    );
    RequestOptions? request;
    final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {'transfer_code': 'TRF-ONLINE-1'},
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

    final code = await repository.createTransaction(
      tenantSlug,
      items: const [
        {
          'sku_id': 5,
          'from_location_id': 8,
          'to_location_id': 9,
          'quantity': 2,
        },
      ],
    );

    expect(code, 'TRF-ONLINE-1');
    expect(request?.path, '/tenant-transfer-online-direct/stock-transfer/store');
    expect(
      await OfflineDb.countTransferQueue(
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
      ),
      0,
    );
  });

  test('online opname count posts directly even in manual sync mode', () async {
    const tenantSlug = 'tenant-opname-online-direct';
    const ownerKey = 'user:opname-online-direct';
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final data = options.path.endsWith('/active')
              ? {
                  'success': true,
                  'data': {
                    'session': {
                      'id': 44,
                      'session_code': 'SOP-2026-0044',
                      'warehouse': 'Gudang Utama',
                      'status': 'COUNTING',
                      'location_id': 8,
                      'location_label': 'Rak A1',
                    },
                    'items': [
                      {
                        'id': 101,
                        'sku_id': 5,
                        'sku': 'SKU-5',
                        'barcode': '0005',
                        'name': 'Produk Lima',
                        'unit': 'pcs',
                        'location_id': 8,
                        'target_rack': 'RACK-A1',
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
    final repository = OfflineStockOpnameRepository(
      api: ApiStockOpnameRepository(dio),
      dio: dio,
      ownerKey: ownerKey,
      authToken: 'test-token',
      operatorName: 'Operator A',
    );

    final outcome = await repository.recordCount(
      tenantSlug,
      itemId: 101,
      physicalQty: 4,
    );

    expect(outcome.synced, isTrue);
    expect(
      requests.map((request) => request.path),
      [
        '/tenant-opname-online-direct/stock-opname/active',
        '/tenant-opname-online-direct/stock-opname/record-count',
      ],
    );
    expect(
      await OfflineDb.countOpnameQueue(
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
      ),
      0,
    );
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
      locationId: 8,
      locationLabel: 'Rak A1',
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
    await repository.recordCount(tenantSlug, itemId: 101, physicalQty: 9);
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
    expect(
      requests
          .where((request) => request.path.endsWith('/sync-offline'))
          .map((request) => request.path),
      hasLength(2),
    );
    final syncRequest = requests.firstWhere(
      (request) => request.path.endsWith('/sync-offline'),
    );
    expect(syncRequest.data['session_id'], 42);
    expect(syncRequest.data.containsKey('local_uuid'), isFalse);
    expect(syncRequest.data.containsKey('transaction_uuid'), isFalse);
    expect(syncRequest.data.containsKey('should_submit_review'), isFalse);
    expect(syncRequest.data['items'].single, {
      'item_id': 101,
      'location_id': 8,
      'target_rack': 'RACK-A1-01',
      'physical_qty': 7,
    });
    expect(payload['items'].single['physical_qty'], 9);
    expect(payload['should_submit_review'], isFalse);

    await repository.submitReview(tenantSlug, sessionId: 42);
    final reviewQueue = await OfflineDb.getOpnameQueue(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
    );
    final reviewPayload = decodeJsonMap(
      reviewQueue.single['payload_json'] as String,
    );
    expect(reviewQueue.single['local_uuid'], localUuid);
    expect(reviewPayload['should_submit_review'], isTrue);
    expect(reviewPayload['items'].single['physical_qty'], 9);
  });

  test(
    'offline opname queue sync sends the contract payload successfully',
    () async {
      const tenantSlug = 'tenant-opname-sync-success';
      const ownerKey = 'user:opname-sync-success';
      const session = StockOpnameSession(
        id: 43,
        sessionCode: 'SOP-2026-0043',
        warehouse: 'Gudang Utama',
        zone: '',
        status: 'COUNTING',
        locationId: 12,
        locationLabel: 'Rak B2',
        items: [
          StockOpnameItem(
            id: 103,
            skuId: 8,
            sku: 'SKU-103',
            barcode: '00103',
            name: 'Produk 103',
            locationId: 12,
            locationLabel: 'Rak B2',
            targetRack: 'RACK-B2-01',
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
            if (options.path.endsWith('/active')) {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: {
                    'success': true,
                    'data': {
                      'session': {
                        'id': session.id,
                        'session_code': session.sessionCode,
                        'status': session.status,
                        'location_id': session.locationId,
                        'location_label': session.locationLabel,
                      },
                      'items': [
                        {
                          'id': 103,
                          'sku_id': 8,
                          'sku_code': 'SKU-103',
                          'barcode': '00103',
                          'location_id': 12,
                          'location_label': 'Rak B2',
                          'target_rack': 'RACK-B2-01',
                        },
                      ],
                    },
                  },
                ),
              );
              return;
            }
            if (options.path.endsWith('/record-count')) {
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
                data: {'success': true, 'message': 'ok'},
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

      final outcome = await repository.recordCount(
        tenantSlug,
        itemId: 103,
        physicalQty: 4,
      );
      final result = await SyncManager.instance.syncOpnameQueue(
        dio: dio,
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
        authToken: 'test-token',
      );

      expect(outcome.synced, isFalse);
      expect(result.syncedCount, 1);
      final syncRequest = requests.firstWhere(
        (request) => request.path.endsWith('/sync-offline'),
      );
      expect(syncRequest.data, {
        'session_id': 43,
        'items': [
          {
            'item_id': 103,
            'location_id': 12,
            'target_rack': 'RACK-B2-01',
            'physical_qty': 4,
          },
        ],
      });
    },
  );

  test('offline review sync submits counts before review', () async {
    const tenantSlug = 'tenant-opname-review-sync';
    const ownerKey = 'user:opname-review-sync';
    const localUuid = 'TX-OPN-REVIEW001';
    await OfflineDb.enqueueOpname(
      localUuid: localUuid,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      sessionId: 45,
      sessionCode: 'SOP-2026-0045',
      payload: {
        'session_id': 45,
        'session_code': 'SOP-2026-0045',
        'local_uuid': localUuid,
        'should_submit_review': true,
        'counts_synced': false,
        'items': [
          {
            'item_id': 105,
            'location_id': 14,
            'target_rack': 'RACK-D1-01',
            'physical_qty': 6,
          },
        ],
      },
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
              data: {'success': true, 'message': 'ok'},
            ),
          );
        },
      ),
    );

    final result = await SyncManager.instance.syncOpnameQueue(
      dio: dio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: 'test-token',
    );

    expect(result.syncedCount, 1);
    expect(requests.map((request) => request.path), [
      '/$tenantSlug/stock-opname/sync-offline',
      '/$tenantSlug/stock-opname/submit-review',
    ]);
    expect(requests.first.data, {
      'session_id': 45,
      'items': [
        {
          'item_id': 105,
          'location_id': 14,
          'target_rack': 'RACK-D1-01',
          'physical_qty': 6,
        },
      ],
    });
    expect(requests.last.data, {'session_id': 45});
  });

  test('rejects item counts outside a session location', () async {
    const tenantSlug = 'tenant-opname-wrong-location';
    const ownerKey = 'user:opname-wrong-location';
    const session = StockOpnameSession(
      id: 44,
      sessionCode: 'SOP-2026-0044',
      warehouse: 'Gudang Utama',
      zone: '',
      status: 'COUNTING',
      locationId: 12,
      locationLabel: 'Rak B2',
      items: [
        StockOpnameItem(
          id: 104,
          sku: 'SKU-104',
          barcode: '00104',
          name: 'Produk 104',
          locationId: 13,
          targetRack: 'RACK-C1-01',
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
    final repository = OfflineStockOpnameRepository(
      api: ApiStockOpnameRepository(dio),
      dio: dio,
      ownerKey: ownerKey,
      authToken: 'test-token',
      operatorName: 'Operator A',
    );

    await expectLater(
      repository.recordCount(tenantSlug, itemId: 104, physicalQty: 2),
      throwsA(
        isA<ServerException>().having(
          (error) => error.message,
          'message',
          contains('di luar lingkup'),
        ),
      ),
    );
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

  test('existing inbound and outbound scans queue offline and commit on sync',
      () async {
    const tenantSlug = 'tenant-existing-manifests';
    const ownerKey = 'user:existing-manifests';
    final offlineDio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    offlineDio.interceptors.add(
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
    final inboundSnapshot = InboundManifestDetail(
      manifest: InboundManifest(
        code: 'INB-OFFLINE-1',
        supplierId: 3,
        supplierName: 'Supplier A',
        totalUnits: 4,
        status: InboundStatus.receiving,
        items: [
          InboundItem(
            id: '41',
            productId: 17,
            sku: 'SKU-17',
            barcode: '0017',
            name: 'Product 17',
            expectedQty: 4,
          ),
        ],
      ),
      items: [
        InboundItem(
          id: '41',
          productId: 17,
          sku: 'SKU-17',
          barcode: '0017',
          name: 'Product 17',
          expectedQty: 4,
        ),
      ],
      locations: const [InboundLocation(id: 7, rackCode: 'R-01')],
    );
    final inboundNotifier = InboundNotifier(
      ApiInboundRepository(offlineDio),
      tenantSlug,
      ownerKey,
    );
    await inboundNotifier.updateItemTally(
      manifestCode: 'INB-OFFLINE-1',
      itemId: '41',
      goodQty: 3,
      damagedQty: 1,
      targetRack: 'R-01',
      snapshot: inboundSnapshot,
    );
    final inboundRows = await OfflineDb.getInboundManifests(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
    );
    final inboundPayload = decodeJsonMap(
      inboundRows.single['payload_json'] as String,
    );
    expect(inboundPayload['manifest_code'], 'INB-OFFLINE-1');
    expect(inboundPayload['items'].single['good_qty'], 3);
    expect(
      await inboundNotifier.commitManifestApi(
        'INB-OFFLINE-1',
        snapshot: inboundSnapshot,
      ),
      isFalse,
    );

    final outboundSnapshot = OutboundManifestDetail(
      manifest: OutboundOrder(
        code: 'OUT-OFFLINE-1',
        customer: 'Customer A',
        customerId: 12,
        destination: '',
        expedition: '',
        stagingBay: '-',
        status: OutboundStatus.picking,
        items: [
          OutboundItem(
            id: '52',
            sku: 'SKU-34',
            barcode: '0034',
            name: 'Product 34',
            fromRack: 'R-02',
            orderQty: 8,
            skuId: 34,
          ),
        ],
      ),
      items: [
        OutboundItem(
          id: '52',
          sku: 'SKU-34',
          barcode: '0034',
          name: 'Product 34',
          fromRack: 'R-02',
          orderQty: 8,
          skuId: 34,
        ),
      ],
      locations: const [OutboundLocation(id: 5, rackCode: 'R-02')],
    );
    final outboundNotifier = OutboundNotifier(
      repository: ApiOutboundRepository(offlineDio),
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
    );
    await outboundNotifier.savePicking(
      manifestCode: 'OUT-OFFLINE-1',
      itemId: '52',
      goodQty: 6,
      damagedQty: 1,
      sourceRackId: 5,
      sourceRack: 'R-02',
      snapshot: outboundSnapshot,
    );
    final outboundRows = await OfflineDb.getOutboundManifests(
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
    );
    final outboundPayload = decodeJsonMap(
      outboundRows.single['payload_json'] as String,
    );
    expect(outboundPayload['manifest_code'], 'OUT-OFFLINE-1');
    expect(outboundPayload['items'].single['good_qty'], 6);
    expect(
      await outboundNotifier.commitOutboundApi(
        'OUT-OFFLINE-1',
        snapshot: outboundSnapshot,
      ),
      isFalse,
    );

    final syncRequests = <RequestOptions>[];
    final syncDio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    syncDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          syncRequests.add(options);
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'success': true,
                'data': {'manifest_code': options.data['manifest_code']},
              },
            ),
          );
        },
      ),
    );
    final inboundSync = await SyncManager.instance.syncInboundQueue(
      dio: syncDio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: 'test-token',
    );
    final outboundSync = await SyncManager.instance.syncOutboundQueue(
      dio: syncDio,
      tenantSlug: tenantSlug,
      ownerKey: ownerKey,
      authToken: 'test-token',
    );

    expect(inboundSync.syncedCount, 1);
    expect(outboundSync.syncedCount, 1);
    expect(syncRequests, hasLength(2));
    expect(syncRequests[0].data['should_commit'], isTrue);
    expect(syncRequests[1].data['should_commit'], isTrue);

    await inboundNotifier.updateItemTally(
      manifestCode: 'INB-OFFLINE-1',
      itemId: '41',
      goodQty: 2,
      damagedQty: 2,
      targetRack: 'R-01',
      snapshot: inboundSnapshot,
    );
    await outboundNotifier.savePicking(
      manifestCode: 'OUT-OFFLINE-1',
      itemId: '52',
      goodQty: 5,
      damagedQty: 2,
      sourceRackId: 5,
      sourceRack: 'R-02',
      snapshot: outboundSnapshot,
    );
    expect(
      (await OfflineDb.getInboundManifests(
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
      ))
          .single['status'],
      'pending',
    );
    expect(
      (await OfflineDb.getOutboundManifests(
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
      ))
          .single['status'],
      'pending',
    );
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
