// Model: TenantInfo, UserSession
class TenantInfo {
  final int id;
  final String name;
  final String slug;

  TenantInfo({required this.id, required this.name, required this.slug});

  factory TenantInfo.fromJson(Map<String, dynamic> json) {
    return TenantInfo(
      id: json['tenant_id'] ?? json['id'],
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
    );
  }
}

class UserModel {
  final int id;
  final String name;
  final String email;
  final int tenantId;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.tenantId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      tenantId: json['tenant_id'],
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.userName,
    required this.userRole,
    required this.tenantSlug,
    required this.tenantName,
  });

  final String token;
  final String userName;
  final String userRole;
  final String tenantSlug;
  final String tenantName;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    final user = json['user'];

    // Validasi token dan objek user
    if (token is! String || token.isEmpty || user is! Map) {
      throw const FormatException(
        'Incomplete authentication session response.',
      );
    }

    final userData = Map<String, dynamic>.from(user);

    // DUKUNGAN FLEKSIBEL: Cari tenant di root map ATAU di dalam userData['tenant']
    final rawTenant = json['tenant'] ?? userData['tenant'];

    if (rawTenant is! Map) {
      throw const FormatException(
        'Incomplete authentication session response.',
      );
    }

    final tenantData = Map<String, dynamic>.from(rawTenant);
    final userName = userData['name'];
    final tenantSlug = tenantData['slug'];
    final tenantName = tenantData['name'];

    if (userName is! String ||
        userName.isEmpty ||
        tenantSlug is! String ||
        tenantSlug.isEmpty ||
        tenantName is! String ||
        tenantName.isEmpty) {
      throw const FormatException(
        'Incomplete authentication session response.',
      );
    }

    // Extraction defensif untuk Role (Support Spatie RBAC / Map / String)
    final role = userData['role'] ?? userData['roles'];
    String? userRole;

    if (role is List && role.isNotEmpty) {
      userRole = role.first['name']?.toString() ?? role.first.toString();
    } else if (role is Map) {
      userRole = role['name']?.toString();
    } else {
      userRole = role?.toString();
    }

    return AuthSession(
      token: token,
      userName: userName,
      userRole: userRole ?? '',
      tenantSlug: tenantSlug,
      tenantName: tenantName,
    );
  }
}