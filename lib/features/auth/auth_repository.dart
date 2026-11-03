import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/secure_storage.dart';
import 'auth_model.dart';

class AuthRepository {
  AuthRepository(this._dio);
  final Dio _dio;

  Future<TenantInfo> verifyTenant(String workspaceSlug) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.verifyTenant,
        data: {'workspace_slug': workspaceSlug},
      );

      final tenant = TenantInfo.fromJson(response.data['data']);
      await SecureStorage.instance.saveTenant(
        slug: tenant.slug,
        name: tenant.name,
      );
      return tenant;
    } on DioException catch (e) {
      throw e.error is AppException
          ? (e.error as AppException)
          : const ServerException();
    }
  }

  Future<AuthSession> login({
    required String workspaceSlug,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.login,
        data: {
          'workspace_slug': workspaceSlug,
          'email': email,
          'password': password,
          'device_name': 'handheld_flutter_scanner',
        },
      );

      final responseBody = response.data;
      final data = responseBody is Map ? responseBody['data'] : null;
      if (data is! Map) {
        throw const ServerException('Data sesi login tidak valid.');
      }

      return AuthSession.fromJson(Map<String, dynamic>.from(data));
    } on FormatException catch (e) {
      throw ServerException(e.message);
    } on DioException catch (e) {
      throw e.error is AppException
          ? (e.error as AppException)
          : const ServerException();
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiEndpoints.logout);
    } catch (_) {}
    await SecureStorage.instance.clearAll();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});
