import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_state.dart';
import 'secure_storage.dart';

/// Global auth provider — satu-satunya sumber kebenaran untuk status login.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  /// Panggil saat app start — cek apakah ada session tersimpan.
  Future<void> initialize() async {
    final storage = SecureStorage.instance;
    if (await storage.hasSession()) {
      state = state.copyWith(
        token: await storage.getToken(),
        tenantSlug: await storage.getTenantSlug(),
        tenantName: await storage.getTenantName(),
        userName: await storage.getUserName(),
        userRole: await storage.getUserRole(),
      );
    }
  }

  Future<void> saveSession({
    required String token,
    required String tenantSlug,
    required String tenantName,
    required String userName,
    required String userRole,
  }) async {
    await SecureStorage.instance.saveSession(
      token: token,
      tenantSlug: tenantSlug,
      tenantName: tenantName,
      userName: userName,
      userRole: userRole,
    );
    state = AuthState(
      token: token,
      tenantSlug: tenantSlug,
      tenantName: tenantName,
      userName: userName,
      userRole: userRole,
    );
  }

  void enterDemoSession() {
    state = const AuthState(
      token: 'demo-session',
      tenantSlug: 'naratel-logistics',
      tenantName: 'Naratel Logistics',
      userName: 'Budi',
      userRole: 'Operator',
    );
  }

  Future<void> logout() async {
    await SecureStorage.instance.clearSession();
    state = const AuthState();
  }
}
