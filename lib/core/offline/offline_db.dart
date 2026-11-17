import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Local SQLite storage for offline inbound transactions and master data.
class OfflineDb {
  OfflineDb._();

  static const _syncQueueBoxName = 'sync_queue';
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

    final selectedFactory = factory ??
        (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS
            ? sqflite.databaseFactory
            : _ffiDatabaseFactory());
    final resolvedPath = databasePath ??
        path.join(
          await selectedFactory.getDatabasesPath(),
          'omni_offline.db',
        );

    _database = await selectedFactory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: 1,
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
        },
      ),
    );

    await database.update(
      'inbound_offline_queue',
      {'status': 'pending'},
      where: 'status = ?',
      whereArgs: ['syncing'],
    );
  }

  static DatabaseFactory _ffiDatabaseFactory() {
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }

  static Database get database {
    final db = _database;
    if (db == null) {
      throw StateError(
          'OfflineDb.init() must be called before database access.');
    }
    return db;
  }

  static Box<Map> get syncQueueBox => Hive.box<Map>(_syncQueueBoxName);

  static Future<void> cacheInboundOptions({
    required String tenantSlug,
    required String ownerKey,
    required Map<String, dynamic> options,
  }) async {
    await database.insert(
      'inbound_master_cache',
      {
        'tenant_slug': tenantSlug,
        'owner_key': ownerKey,
        'options_json': jsonEncodeMap(options),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
    await database.insert(
      'inbound_offline_queue',
      {
        'local_uuid': localUuid,
        'tenant_slug': tenantSlug,
        'owner_key': ownerKey,
        'payload_json': jsonEncodeMap(payload),
        'metadata_json': jsonEncodeMap(metadata),
        'created_at': DateTime.now().toIso8601String(),
        'status': 'pending',
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  static Future<List<Map<String, Object?>>> getInboundQueue({
    required String tenantSlug,
    required String ownerKey,
    String? localUuid,
  }) =>
      database.query(
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
  }) =>
      database.query(
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
          'local_uuid = ? AND tenant_slug = ? AND owner_key = ? AND status IN (?, ?)',
      whereArgs: [localUuid, tenantSlug, ownerKey, 'pending', 'error'],
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
}

String jsonEncodeMap(Map<String, dynamic> value) => jsonEncode(value);

Map<String, dynamic> decodeJsonMap(String value) =>
    Map<String, dynamic>.from(jsonDecode(value) as Map);
