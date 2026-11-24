import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Local SQLite storage for offline warehouse transactions and master data.
class OfflineDb {
  OfflineDb._();

  static const _syncQueueBoxName = 'sync_queue';
  static const _automaticSyncSettingKey = 'automatic_sync_enabled';
  static Database? _database;

  static Future<void> init({
    DatabaseFactory? factory,
    String? databasePath,
    bool initializeHive = true,
  }) async {
    if (initializeHive) {
      await Hive.initFlutter();
      await Hive.openBox<Map>(_syncQueueBoxName);
    }

    if (kIsWeb) {
      throw UnsupportedError('Offline SQLite is not supported on web.');
    }

    final selectedFactory =
        factory ??
        (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS
            ? sqflite.databaseFactory
            : _ffiDatabaseFactory());
    final resolvedPath =
        databasePath ??
        path.join(await selectedFactory.getDatabasesPath(), 'omni_offline.db');

    _database = await selectedFactory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE inbound_offline_queue (
              local_uuid TEXT PRIMARY KEY,
              tenant_slug TEXT NOT NULL,
              owner_key TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              metadata_json TEXT NOT NULL,
              created_at TEXT NOT NULL,
              status TEXT NOT NULL,
              error_message TEXT,
              server_manifest_code TEXT,
              retry_count INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE INDEX inbound_queue_owner_status
            ON inbound_offline_queue (tenant_slug, owner_key, status, created_at)
          ''');
          await db.execute('''
            CREATE TABLE inbound_master_cache (
              tenant_slug TEXT NOT NULL,
              owner_key TEXT NOT NULL,
              options_json TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              PRIMARY KEY (tenant_slug, owner_key)
            )
          ''');
          await _createOutboundTables(db);
          await _createTransferTables(db);
          await _createOpnameTables(db);
          await _createSettingsTable(db);
          await _createListSnapshotTable(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _createOutboundTables(db);
          if (oldVersion < 3) await _createTransferTables(db);
          if (oldVersion < 4) await _createOpnameTables(db);
          if (oldVersion < 5) await _createSettingsTable(db);
          if (oldVersion < 6) await _createListSnapshotTable(db);
        },
      ),
    );

    await database.update(
      'inbound_offline_queue',
      {'status': 'pending'},
      where: 'status = ?',
      whereArgs: ['syncing'],
    );
    await database.update(
      'outbound_offline_queue',
      {'status': 'pending'},
      where: 'status = ?',
      whereArgs: ['syncing'],
    );
    await database.update(
      'opname_offline_queue',
      {'status': 'pending'},
      where: 'status = ?',
      whereArgs: ['syncing'],
    );
  }

  static Future<void> _createOutboundTables(sqflite.DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE outbound_offline_queue (
        local_uuid TEXT PRIMARY KEY,
        tenant_slug TEXT NOT NULL,
        owner_key TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        metadata_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL,
        error_message TEXT,
        server_manifest_code TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE INDEX outbound_queue_owner_status
      ON outbound_offline_queue (tenant_slug, owner_key, status, created_at)
    ''');
    await db.execute('''
      CREATE TABLE outbound_master_cache (
        tenant_slug TEXT NOT NULL,
        owner_key TEXT NOT NULL,
        options_json TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (tenant_slug, owner_key)
      )
    ''');
  }

  static Future<void> _createTransferTables(sqflite.DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE transfer_offline_queue (
        local_uuid TEXT PRIMARY KEY,
        tenant_slug TEXT NOT NULL,
        owner_key TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        metadata_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL,
        error_message TEXT,
        server_transfer_code TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE INDEX transfer_queue_owner_status
      ON transfer_offline_queue (tenant_slug, owner_key, status, created_at)
    ''');
    await db.execute('''
      CREATE TABLE transfer_master_cache (
        tenant_slug TEXT NOT NULL,
        owner_key TEXT NOT NULL,
        options_json TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (tenant_slug, owner_key)
      )
    ''');
  }

  static Future<void> _createOpnameTables(sqflite.DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE opname_offline_queue (
        local_uuid TEXT PRIMARY KEY,
        tenant_slug TEXT NOT NULL,
        owner_key TEXT NOT NULL,
        session_id INTEGER,
        session_code TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        metadata_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL,
        error_message TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE INDEX opname_queue_owner_status
      ON opname_offline_queue (tenant_slug, owner_key, status, created_at)
    ''');
    await db.execute('''
      CREATE INDEX opname_queue_session
      ON opname_offline_queue (tenant_slug, owner_key, session_code, status)
    ''');
    await db.execute('''
      CREATE TABLE opname_session_cache (
        tenant_slug TEXT NOT NULL,
        owner_key TEXT NOT NULL,
        session_code TEXT NOT NULL,
        session_json TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (tenant_slug, owner_key, session_code)
      )
    ''');
  }

  static Future<void> _createSettingsTable(sqflite.DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE app_settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createListSnapshotTable(
    sqflite.DatabaseExecutor db,
  ) async {
    await db.execute('''
      CREATE TABLE api_list_snapshot (
        tenant_slug TEXT NOT NULL,
        owner_key TEXT NOT NULL,
        feature TEXT NOT NULL,
        query_key TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (tenant_slug, owner_key, feature, query_key)
      )
    ''');
  }

  static Future<bool> isAutomaticSyncEnabled() async {
    final rows = await database.query(
      'app_settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: [_automaticSyncSettingKey],
      limit: 1,
    );
    return rows.isNotEmpty && rows.single['setting_value'] == 'true';
  }

  static Future<void> setAutomaticSyncEnabled(bool enabled) async {
    await database.insert('app_settings', {
      'setting_key': _automaticSyncSettingKey,
      'setting_value': enabled ? 'true' : 'false',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static DatabaseFactory _ffiDatabaseFactory() {
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }

  static Database get database {
    final db = _database;
    if (db == null) {
      throw StateError(
        'OfflineDb.init() must be called before database access.',
      );
    }
    return db;
  }

  static Box<Map> get syncQueueBox => Hive.box<Map>(_syncQueueBoxName);

  static String _listQueryKey(Map<String, dynamic> filters) =>
      jsonEncode(SplayTreeMap<String, dynamic>.from(filters));

  static Future<void> cacheListSnapshot({
    required String tenantSlug,
    required String ownerKey,
    required String feature,
    required Map<String, dynamic> filters,
    required Object? payload,
  }) async {
    await database.insert(
      'api_list_snapshot',
      {
        'tenant_slug': tenantSlug,
        'owner_key': ownerKey,
        'feature': feature,
        'query_key': _listQueryKey(filters),
        'payload_json': jsonEncode(payload),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Object?> getCachedListSnapshot({
    required String tenantSlug,
    required String ownerKey,
    required String feature,
    required Map<String, dynamic> filters,
  }) async {
    final rows = await database.query(
      'api_list_snapshot',
      columns: ['payload_json'],
      where:
          'tenant_slug = ? AND owner_key = ? AND feature = ? AND query_key = ?',
      whereArgs: [
        tenantSlug,
        ownerKey,
        feature,
        _listQueryKey(filters),
      ],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.single['payload_json'] as String);
  }

  static Future<void> cacheInboundOptions({
    required String tenantSlug,
    required String ownerKey,
    required Map<String, dynamic> options,
  }) async {
    await database.insert('inbound_master_cache', {
      'tenant_slug': tenantSlug,
      'owner_key': ownerKey,
      'options_json': jsonEncodeMap(options),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getCachedInboundOptions({
    required String tenantSlug,
    required String ownerKey,
  }) async {
    final rows = await database.query(
      'inbound_master_cache',
      columns: ['options_json'],
      where: 'tenant_slug = ? AND owner_key = ?',
      whereArgs: [tenantSlug, ownerKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return decodeJsonMap(rows.single['options_json'] as String);
  }

  static Future<void> enqueueInbound({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> metadata,
  }) async {
    await database.insert('inbound_offline_queue', {
      'local_uuid': localUuid,
      'tenant_slug': tenantSlug,
      'owner_key': ownerKey,
      'payload_json': jsonEncodeMap(payload),
      'metadata_json': jsonEncodeMap(metadata),
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  static Future<List<Map<String, Object?>>> getInboundQueue({
    required String tenantSlug,
    required String ownerKey,
    String? localUuid,
  }) => database.query(
    'inbound_offline_queue',
    where: localUuid == null
        ? 'tenant_slug = ? AND owner_key = ? AND status IN (?, ?, ?)'
        : 'tenant_slug = ? AND owner_key = ? AND local_uuid = ? AND status IN (?, ?, ?)',
    whereArgs: localUuid == null
        ? [tenantSlug, ownerKey, 'pending', 'error', 'syncing']
        : [tenantSlug, ownerKey, localUuid, 'pending', 'error', 'syncing'],
    orderBy: 'created_at ASC',
  );

  static Future<int> countInboundQueue({
    required String tenantSlug,
    required String ownerKey,
  }) async {
    final result = await database.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM inbound_offline_queue
      WHERE tenant_slug = ? AND owner_key = ? AND status IN (?, ?, ?)
      ''',
      [tenantSlug, ownerKey, 'pending', 'error', 'syncing'],
    );
    return sqflite.Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<List<Map<String, Object?>>> getInboundManifests({
    required String tenantSlug,
    required String ownerKey,
  }) => database.query(
    'inbound_offline_queue',
    where: 'tenant_slug = ? AND owner_key = ? AND status IN (?, ?, ?)',
    whereArgs: [tenantSlug, ownerKey, 'pending', 'error', 'syncing'],
    orderBy: 'created_at DESC',
  );

  static Future<Map<String, Object?>?> getInboundQueueItem({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
  }) async {
    final rows = await database.query(
      'inbound_offline_queue',
      where: 'local_uuid = ? AND tenant_slug = ? AND owner_key = ?',
      whereArgs: [localUuid, tenantSlug, ownerKey],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  static Future<void> saveInboundProgress({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> metadata,
  }) async {
    final updated = await database.update(
      'inbound_offline_queue',
      {
        'payload_json': jsonEncodeMap(payload),
        'metadata_json': jsonEncodeMap(metadata),
        'status': 'pending',
        'error_message': null,
      },
      where:
          'local_uuid = ? AND tenant_slug = ? AND owner_key = ? AND status IN (?, ?, ?)',
      whereArgs: [localUuid, tenantSlug, ownerKey, 'pending', 'error', 'success'],
    );
    if (updated != 1) {
      throw StateError(
        'Manifes lokal sedang disinkronkan atau tidak tersedia untuk diedit.',
      );
    }
  }

  static Future<void> updateInboundQueueItem({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
    required String status,
    String? errorMessage,
    String? serverManifestCode,
    bool incrementRetry = false,
  }) async {
    await database.rawUpdate(
      '''
      UPDATE inbound_offline_queue
      SET status = ?,
          error_message = ?,
          server_manifest_code = COALESCE(?, server_manifest_code),
          retry_count = retry_count + ?
      WHERE local_uuid = ? AND tenant_slug = ? AND owner_key = ?
      ''',
      [
        status,
        errorMessage,
        serverManifestCode,
        incrementRetry ? 1 : 0,
        localUuid,
        tenantSlug,
        ownerKey,
      ],
    );
  }

  static Future<int> deleteInboundQueueItem({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
  }) async {
    return database.delete(
      'inbound_offline_queue',
      where:
          'local_uuid = ? AND tenant_slug = ? AND owner_key = ? AND status != ?',
      whereArgs: [localUuid, tenantSlug, ownerKey, 'syncing'],
    );
  }

  static Future<void> cacheOutboundOptions({
    required String tenantSlug,
    required String ownerKey,
    required Map<String, dynamic> options,
  }) async {
    await database.insert('outbound_master_cache', {
      'tenant_slug': tenantSlug,
      'owner_key': ownerKey,
      'options_json': jsonEncodeMap(options),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getCachedOutboundOptions({
    required String tenantSlug,
    required String ownerKey,
  }) async {
    final rows = await database.query(
      'outbound_master_cache',
      columns: ['options_json'],
      where: 'tenant_slug = ? AND owner_key = ?',
      whereArgs: [tenantSlug, ownerKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return decodeJsonMap(rows.single['options_json'] as String);
  }

  static Future<void> enqueueOutbound({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> metadata,
  }) async {
    await database.insert('outbound_offline_queue', {
      'local_uuid': localUuid,
      'tenant_slug': tenantSlug,
      'owner_key': ownerKey,
      'payload_json': jsonEncodeMap(payload),
      'metadata_json': jsonEncodeMap(metadata),
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  static Future<List<Map<String, Object?>>> getOutboundQueue({
    required String tenantSlug,
    required String ownerKey,
    String? localUuid,
  }) => database.query(
    'outbound_offline_queue',
    where: localUuid == null
        ? 'tenant_slug = ? AND owner_key = ? AND status IN (?, ?, ?)'
        : 'tenant_slug = ? AND owner_key = ? AND local_uuid = ? AND status IN (?, ?, ?)',
    whereArgs: localUuid == null
        ? [tenantSlug, ownerKey, 'pending', 'error', 'syncing']
        : [tenantSlug, ownerKey, localUuid, 'pending', 'error', 'syncing'],
    orderBy: 'created_at ASC',
  );

  static Future<int> countOutboundQueue({
    required String tenantSlug,
    required String ownerKey,
  }) async {
    final result = await database.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM outbound_offline_queue
      WHERE tenant_slug = ? AND owner_key = ? AND status IN (?, ?, ?)
      ''',
      [tenantSlug, ownerKey, 'pending', 'error', 'syncing'],
    );
    return sqflite.Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<List<Map<String, Object?>>> getOutboundManifests({
    required String tenantSlug,
    required String ownerKey,
  }) => database.query(
    'outbound_offline_queue',
    where: 'tenant_slug = ? AND owner_key = ? AND status IN (?, ?, ?)',
    whereArgs: [tenantSlug, ownerKey, 'pending', 'error', 'syncing'],
    orderBy: 'created_at DESC',
  );

  static Future<Map<String, Object?>?> getOutboundQueueItem({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
  }) async {
    final rows = await database.query(
      'outbound_offline_queue',
      where: 'local_uuid = ? AND tenant_slug = ? AND owner_key = ?',
      whereArgs: [localUuid, tenantSlug, ownerKey],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  static Future<void> saveOutboundProgress({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> metadata,
  }) async {
    final updated = await database.update(
      'outbound_offline_queue',
      {
        'payload_json': jsonEncodeMap(payload),
        'metadata_json': jsonEncodeMap(metadata),
        'status': 'pending',
        'error_message': null,
      },
      where:
          'local_uuid = ? AND tenant_slug = ? AND owner_key = ? AND status IN (?, ?, ?)',
      whereArgs: [localUuid, tenantSlug, ownerKey, 'pending', 'error', 'success'],
    );
    if (updated != 1) {
      throw StateError(
        'Manifes outbound lokal sedang disinkronkan atau tidak tersedia untuk diedit.',
      );
    }
  }

  static Future<void> updateOutboundQueueItem({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
    required String status,
    String? errorMessage,
    String? serverManifestCode,
    bool incrementRetry = false,
  }) async {
    await database.rawUpdate(
      '''
      UPDATE outbound_offline_queue
      SET status = ?,
          error_message = ?,
          server_manifest_code = COALESCE(?, server_manifest_code),
          retry_count = retry_count + ?
      WHERE local_uuid = ? AND tenant_slug = ? AND owner_key = ?
      ''',
      [
        status,
        errorMessage,
        serverManifestCode,
        incrementRetry ? 1 : 0,
        localUuid,
        tenantSlug,
        ownerKey,
      ],
    );
  }

  static Future<int> deleteOutboundQueueItem({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
  }) => database.delete(
    'outbound_offline_queue',
    where:
        'local_uuid = ? AND tenant_slug = ? AND owner_key = ? AND status != ?',
    whereArgs: [localUuid, tenantSlug, ownerKey, 'syncing'],
  );

  static Future<void> cacheTransferOptions({
    required String tenantSlug,
    required String ownerKey,
    required Map<String, dynamic> options,
  }) async {
    await database.insert('transfer_master_cache', {
      'tenant_slug': tenantSlug,
      'owner_key': ownerKey,
      'options_json': jsonEncodeMap(options),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getCachedTransferOptions({
    required String tenantSlug,
    required String ownerKey,
  }) async {
    final rows = await database.query(
      'transfer_master_cache',
      columns: ['options_json'],
      where: 'tenant_slug = ? AND owner_key = ?',
      whereArgs: [tenantSlug, ownerKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return decodeJsonMap(rows.single['options_json'] as String);
  }

  static Future<void> enqueueTransfer({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> metadata,
    DateTime? createdAt,
  }) async {
    final timestamp = (createdAt ?? DateTime.now()).toIso8601String();
    await database.insert('transfer_offline_queue', {
      'local_uuid': localUuid,
      'tenant_slug': tenantSlug,
      'owner_key': ownerKey,
      'payload_json': jsonEncodeMap(payload),
      'metadata_json': jsonEncodeMap(metadata),
      'created_at': timestamp,
      'status': 'pending',
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  static Future<List<Map<String, Object?>>> getTransferQueue({
    required String tenantSlug,
    required String ownerKey,
    String? localUuid,
  }) => database.query(
    'transfer_offline_queue',
    where: localUuid == null
        ? 'tenant_slug = ? AND owner_key = ? AND status IN (?, ?, ?)'
        : 'tenant_slug = ? AND owner_key = ? AND local_uuid = ? AND status IN (?, ?, ?)',
    whereArgs: localUuid == null
        ? [tenantSlug, ownerKey, 'pending', 'error', 'syncing']
        : [tenantSlug, ownerKey, localUuid, 'pending', 'error', 'syncing'],
    orderBy: 'created_at ASC',
  );

  static Future<int> countTransferQueue({
    required String tenantSlug,
    required String ownerKey,
  }) async {
    final result = await database.rawQuery(
      '''
    SELECT COUNT(*) AS count
    FROM transfer_offline_queue
    WHERE tenant_slug = ? AND owner_key = ? AND status IN (?, ?, ?)
    ''',
      [tenantSlug, ownerKey, 'pending', 'error', 'syncing'],
    );
    return sqflite.Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<List<Map<String, Object?>>> getTransferManifests({
    required String tenantSlug,
    required String ownerKey,
  }) => database.query(
    'transfer_offline_queue',
    where: 'tenant_slug = ? AND owner_key = ? AND status IN (?, ?, ?, ?, ?)',
    whereArgs: [
      tenantSlug,
      ownerKey,
      'pending',
      'error',
      'syncing',
      'success',
      'cancelled',
    ],
    orderBy: 'created_at DESC',
  );

  static Future<Map<String, Object?>?> getTransferQueueItem({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
  }) async {
    final rows = await database.query(
      'transfer_offline_queue',
      where: 'local_uuid = ? AND tenant_slug = ? AND owner_key = ?',
      whereArgs: [localUuid, tenantSlug, ownerKey],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  static Future<void> saveTransferProgress({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> metadata,
  }) async {
    final updated = await database.update(
      'transfer_offline_queue',
      {
        'payload_json': jsonEncodeMap(payload),
        'metadata_json': jsonEncodeMap(metadata),
        'status': 'pending',
        'error_message': null,
      },
      where:
          'local_uuid = ? AND tenant_slug = ? AND owner_key = ? AND status IN (?, ?)',
      whereArgs: [localUuid, tenantSlug, ownerKey, 'pending', 'error'],
    );
    if (updated != 1) {
      throw StateError(
        'Transaksi transfer lokal sedang disinkronkan atau tidak tersedia untuk diedit.',
      );
    }
  }

  static Future<void> updateTransferQueueItem({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
    required String status,
    String? errorMessage,
    String? serverTransferCode,
    String? serverStatus,
    bool incrementRetry = false,
  }) async {
    String? metadataJson;
    if (serverStatus != null) {
      final row = await getTransferQueueItem(
        localUuid: localUuid,
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
      );
      if (row != null) {
        final metadata = decodeJsonMap(row['metadata_json'] as String)
          ..['server_status'] = serverStatus;
        metadataJson = jsonEncodeMap(metadata);
      }
    }
    await database.rawUpdate(
      '''
    UPDATE transfer_offline_queue
    SET status = ?,
        error_message = ?,
        server_transfer_code = COALESCE(?, server_transfer_code),
        metadata_json = COALESCE(?, metadata_json),
        retry_count = retry_count + ?
    WHERE local_uuid = ? AND tenant_slug = ? AND owner_key = ?
    ''',
      [
        status,
        errorMessage,
        serverTransferCode,
        metadataJson,
        incrementRetry ? 1 : 0,
        localUuid,
        tenantSlug,
        ownerKey,
      ],
    );
  }

  static Future<void> cancelTransferQueueItem({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
  }) async {
    final updated = await database.update(
      'transfer_offline_queue',
      {'status': 'cancelled', 'error_message': null},
      where:
          'local_uuid = ? AND tenant_slug = ? AND owner_key = ? AND status IN (?, ?)',
      whereArgs: [localUuid, tenantSlug, ownerKey, 'pending', 'error'],
    );
    if (updated != 1) {
      throw StateError(
        'Transaksi transfer sedang disinkronkan atau tidak dapat dibatalkan lokal.',
      );
    }
  }

  static Future<int> deleteTransferQueueItem({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
  }) => database.delete(
    'transfer_offline_queue',
    where:
        'local_uuid = ? AND tenant_slug = ? AND owner_key = ? AND status != ?',
    whereArgs: [localUuid, tenantSlug, ownerKey, 'syncing'],
  );

  static Future<void> cacheOpnameSession({
    required String tenantSlug,
    required String ownerKey,
    required String sessionCode,
    required Map<String, dynamic> session,
  }) async {
    await database.insert('opname_session_cache', {
      'tenant_slug': tenantSlug,
      'owner_key': ownerKey,
      'session_code': sessionCode,
      'session_json': jsonEncodeMap(session),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getCachedOpnameSession({
    required String tenantSlug,
    required String ownerKey,
    String? sessionCode,
  }) async {
    final rows = await database.query(
      'opname_session_cache',
      where: sessionCode == null
          ? 'tenant_slug = ? AND owner_key = ?'
          : 'tenant_slug = ? AND owner_key = ? AND session_code = ?',
      whereArgs: sessionCode == null
          ? [tenantSlug, ownerKey]
          : [tenantSlug, ownerKey, sessionCode],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return decodeJsonMap(rows.single['session_json'] as String);
  }

  static Future<List<Map<String, dynamic>>> getCachedOpnameSessions({
    required String tenantSlug,
    required String ownerKey,
  }) async {
    final rows = await database.query(
      'opname_session_cache',
      where: 'tenant_slug = ? AND owner_key = ?',
      whereArgs: [tenantSlug, ownerKey],
      orderBy: 'updated_at DESC',
    );
    return rows
        .map((row) => decodeJsonMap(row['session_json'] as String))
        .toList();
  }

  static Future<void> enqueueOpname({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
    int? sessionId,
    required String sessionCode,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> metadata,
  }) async {
    await database.insert('opname_offline_queue', {
      'local_uuid': localUuid,
      'tenant_slug': tenantSlug,
      'owner_key': ownerKey,
      'session_id': sessionId,
      'session_code': sessionCode,
      'payload_json': jsonEncodeMap(payload),
      'metadata_json': jsonEncodeMap(metadata),
      'created_at': DateTime.now().toIso8601String(),
      'status': 'pending',
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  static Future<List<Map<String, Object?>>> getOpnameQueue({
    required String tenantSlug,
    required String ownerKey,
    String? localUuid,
  }) => database.query(
    'opname_offline_queue',
    where: localUuid == null
        ? 'tenant_slug = ? AND owner_key = ? AND status IN (?, ?, ?)'
        : 'tenant_slug = ? AND owner_key = ? AND local_uuid = ? AND status IN (?, ?, ?)',
    whereArgs: localUuid == null
        ? [tenantSlug, ownerKey, 'pending', 'error', 'syncing']
        : [tenantSlug, ownerKey, localUuid, 'pending', 'error', 'syncing'],
    orderBy: 'created_at ASC',
  );

  static Future<List<Map<String, Object?>>> getPendingOpnameForSession({
    required String tenantSlug,
    required String ownerKey,
    required String sessionCode,
  }) => database.query(
    'opname_offline_queue',
    where:
        'tenant_slug = ? AND owner_key = ? AND session_code = ? AND status IN (?, ?)',
    whereArgs: [tenantSlug, ownerKey, sessionCode, 'pending', 'error'],
    orderBy: 'created_at ASC',
  );

  static Future<int> countOpnameQueue({
    required String tenantSlug,
    required String ownerKey,
  }) async {
    final result = await database.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM opname_offline_queue
      WHERE tenant_slug = ? AND owner_key = ? AND status IN (?, ?, ?)
      ''',
      [tenantSlug, ownerKey, 'pending', 'error', 'syncing'],
    );
    return sqflite.Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<void> updateOpnameQueueItem({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
    required String status,
    String? errorMessage,
    bool incrementRetry = false,
  }) async {
    await database.rawUpdate(
      '''
      UPDATE opname_offline_queue
      SET status = ?,
          error_message = ?,
          retry_count = retry_count + ?
      WHERE local_uuid = ? AND tenant_slug = ? AND owner_key = ?
      ''',
      [
        status,
        errorMessage,
        incrementRetry ? 1 : 0,
        localUuid,
        tenantSlug,
        ownerKey,
      ],
    );
  }

  static Future<void> saveOpnameProgress({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> metadata,
  }) async {
    final updated = await database.update(
      'opname_offline_queue',
      {
        'payload_json': jsonEncodeMap(payload),
        'metadata_json': jsonEncodeMap(metadata),
        'status': 'pending',
        'error_message': null,
      },
      where:
          'local_uuid = ? AND tenant_slug = ? AND owner_key = ? AND status IN (?, ?)',
      whereArgs: [localUuid, tenantSlug, ownerKey, 'pending', 'error'],
    );
    if (updated != 1) {
      throw StateError(
        'Hitungan lokal sedang disinkronkan atau tidak tersedia untuk diperbarui.',
      );
    }
  }

  static Future<void> updateOpnameQueuePayload({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
    required Map<String, dynamic> payload,
  }) async {
    final updated = await database.update(
      'opname_offline_queue',
      {'payload_json': jsonEncodeMap(payload)},
      where:
          'local_uuid = ? AND tenant_slug = ? AND owner_key = ? AND status = ?',
      whereArgs: [localUuid, tenantSlug, ownerKey, 'syncing'],
    );
    if (updated != 1) {
      throw StateError('Antrean opname tidak tersedia untuk diperbarui.');
    }
  }

  static Future<int> deleteOpnameQueueItem({
    required String localUuid,
    required String tenantSlug,
    required String ownerKey,
  }) =>
      database.delete(
        'opname_offline_queue',
        where:
            'local_uuid = ? AND tenant_slug = ? AND owner_key = ? AND status != ?',
        whereArgs: [localUuid, tenantSlug, ownerKey, 'syncing'],
      );
}

String jsonEncodeMap(Map<String, dynamic> value) => jsonEncode(value);

Map<String, dynamic> decodeJsonMap(String value) =>
    Map<String, dynamic>.from(jsonDecode(value) as Map);
