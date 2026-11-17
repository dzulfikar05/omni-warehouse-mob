import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/core/api/api_exception.dart';
import 'package:omni_warehouse_mob/core/offline/offline_db.dart';
import 'package:omni_warehouse_mob/core/offline/sync_manager.dart';
import 'package:omni_warehouse_mob/features/inbound/inbound_local_id.dart';
import 'package:omni_warehouse_mob/features/inbound/inbound_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('generated offline inbound IDs use the server manifest format', () {
    expect(
      generateInboundLocalId(),
      matches(RegExp(r'^TX-INB-[A-Z0-9]{8}$')),
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

  test('sync is owner scoped and successful UUIDs are not posted twice',
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
          {
            'sku_id': 17,
            'po_qty': 4,
            'good_qty': 3,
            'damaged_qty': 1,
          },
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
  });

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

  test('local inbound manifests can be reopened and edited before sync',
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
          {
            'sku_id': 17,
            'po_qty': 4,
            'good_qty': 0,
            'damaged_qty': 0,
          },
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

    final notifier =
        InboundNotifier(_OfflineOnlyRepository(), tenantSlug, ownerKey);
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
                'data': {'manifest_code': 'INB-LOCAL'}
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
  });
}

class _OfflineOnlyRepository implements InboundRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
