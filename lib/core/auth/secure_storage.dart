import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper untuk flutter_secure_storage.
/// Semua key ada di sini — tidak ada magic string di luar file ini.
class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  final _storage = const FlutterSecureStorage();

  static const _keyToken = 'auth_token';
  static const _keyTenantSlug = 'tenant_slug';
  static const _keyTenantName = 'tenant_name';
  static const _keyUserName = 'user_name';
  static const _keyUserRole = 'user_role';

  Future<void> saveSession({
    required String token,
    required String tenantSlug,
    required String tenantName,
    required String userName,
    required String userRole,
  }) async {
    await Future.wait([
      _storage.write(key: _keyToken, value: token),
      _storage.write(key: _keyTenantSlug, value: tenantSlug),
      _storage.write(key: _keyTenantName, value: tenantName),
      _storage.write(key: _keyUserName, value: userName),
      _storage.write(key: _keyUserRole, value: userRole),
    ]);
  }

  Future<String?> getToken() => _storage.read(key: _keyToken);
  Future<String?> getTenantSlug() => _storage.read(key: _keyTenantSlug);
  Future<String?> getTenantName() => _storage.read(key: _keyTenantName);
  Future<String?> getUserName() => _storage.read(key: _keyUserName);
  Future<String?> getUserRole() => _storage.read(key: _keyUserRole);

  Future<bool> hasSession() async => (await getToken()) != null;

  Future<void> clearSession() => _storage.deleteAll();
}
