/// Model state auth yang di-hold oleh auth_provider.
class AuthState {
  const AuthState({
    this.token,
    this.tenantSlug,
    this.tenantName,
    this.userName,
    this.userRole,
    this.isLoading = false,
  });

  final String? token;
  final String? tenantSlug;
  final String? tenantName;
  final String? userName;
  final String? userRole;
  final bool isLoading;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  AuthState copyWith({
    String? token,
    String? tenantSlug,
    String? tenantName,
    String? userName,
    String? userRole,
    bool? isLoading,
  }) {
    return AuthState(
      token: token ?? this.token,
      tenantSlug: tenantSlug ?? this.tenantSlug,
      tenantName: tenantName ?? this.tenantName,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
