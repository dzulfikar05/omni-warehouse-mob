import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_state.dart';
import 'secure_storage.dart';

/// Global auth provider — satu-satunya sumber kebenaran untuk status login.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier()..initialize(),
);

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  /// Panggil saat app start — cek apakah ada session tersimpan di SecureStorage.
  Future<void> initialize() async {
    final storage = SecureStorage.instance;
    final token = await storage.getToken();

    if (token != null && token.isNotEmpty) {
      final tenantSlug = await storage.getTenantSlug();
      final tenantName = await storage.getTenantName();
      final userName = await storage.getUserName();
      final userRole = await storage.getUserRole();

      state = AuthState(
        token: token,
        tenantSlug: tenantSlug,
        tenantName: tenantName,
        userName: userName,
        userRole: userRole,
      );
    }
  }

  /// Panggil pada Step 1: Simpan tenant info hasil verifikasi API ke State
  void setTenant({required String tenantSlug, required String tenantName}) {
    state = state.copyWith(tenantSlug: tenantSlug, tenantName: tenantName);
  }

  /// Panggil pada Step 2: Simpan seluruh sesi login ke Memori dan SecureStorage
  Future<void> saveSession({
    required String token,
    required String tenantSlug,
    required String tenantName,
    required String userName,
    required String userRole,
  }) async {
    state = AuthState(
      token: token,
      tenantSlug: tenantSlug,
      tenantName: tenantName,
      userName: userName,
      userRole: userRole,
    );

    await SecureStorage.instance.saveSession(
      token: token,
      tenantSlug: tenantSlug,
      tenantName: tenantName,
      userName: userName,
      userRole: userRole,
    );
  }

  Future<void> logout() async {
    state = const AuthState();
    await SecureStorage.instance.clearSession();
  }
}
