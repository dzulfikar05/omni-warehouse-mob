import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  final _storage = const FlutterSecureStorage();

  static const _kToken = 'auth_token';
  static const _kTenantSlug = 'tenant_slug';
  static const _kTenantName = 'tenant_name';
  static const _kUserName = 'user_name';
  static const _kUserRole = 'user_role';
  static const _kCustomServerUrl = 'custom_server_url';

  // --- PRIMITIVE GETTERS & SETTERS ---
  Future<void> saveToken(String token) async =>
      await _storage.write(key: _kToken, value: token);
  Future<String?> getToken() async => await _storage.read(key: _kToken);

  Future<void> saveTenant({required String slug, required String name}) async {
    await _storage.write(key: _kTenantSlug, value: slug);
    await _storage.write(key: _kTenantName, value: name);
  }

  Future<String?> getTenantSlug() async =>
      await _storage.read(key: _kTenantSlug);
  Future<String?> getTenantName() async =>
      await _storage.read(key: _kTenantName);

  // --- CUSTOM SERVER URL (PERSISTEN & FLEKSIBEL) ---
  Future<void> saveCustomServerUrl(String url) async =>
      await _storage.write(key: _kCustomServerUrl, value: url);

  Future<String?> getCustomServerUrl() async =>
      await _storage.read(key: _kCustomServerUrl);

  Future<void> clearCustomServerUrl() async =>
      await _storage.delete(key: _kCustomServerUrl);

  // --- EXTENSION SESSION METHODS ---

  /// Menyimpan seluruh kredensial sesi setelah login berhasil
  Future<void> saveSession({
    required String token,
    required String tenantSlug,
    required String tenantName,
    required String userName,
    required String userRole,
  }) async {
    await saveToken(token);
    await saveTenant(slug: tenantSlug, name: tenantName);
    await _storage.write(key: _kUserName, value: userName);
    await _storage.write(key: _kUserRole, value: userRole);
  }

  Future<String?> getUserName() async => await _storage.read(key: _kUserName);

  Future<String?> getUserRole() async => await _storage.read(key: _kUserRole);

  /// Menghapus seluruh sesi login saat logout (tetap mempertahankan konfigurasi server)
  Future<void> clearSession() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kTenantSlug);
    await _storage.delete(key: _kTenantName);
    await _storage.delete(key: _kUserName);
    await _storage.delete(key: _kUserRole);
  }

  Future<void> clearAll() async => await clearSession();
}
