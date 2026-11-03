import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/secure_storage.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({required String baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.instance.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          final tenantSlug = await SecureStorage.instance.getTenantSlug();
          if (tenantSlug != null && tenantSlug.isNotEmpty) {
            options.headers['X-Tenant-Slug'] = tenantSlug;
          }

          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            await SecureStorage.instance.clearAll();
          }

          final mappedError = _mapDioException(error);
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: mappedError,
            ),
          );
        },
      ),
    );
  }

  late final Dio _dio;
  Dio get dio => _dio;

  static AppException _mapDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return const NetworkException('Tidak dapat terhubung ke server backend.');

      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        final data = error.response?.data;

        if (code == 401) return const UnauthorizedException();

        if (code == 422 && data is Map) {
          final message = data['message']?.toString() ?? 'Validasi gagal.';
          final rawErrors = data['errors'];
          final errors = <String, List<String>>{};

          if (rawErrors is Map) {
            rawErrors.forEach((k, v) {
              if (v is List) {
                errors[k.toString()] = v.map((e) => e.toString()).toList();
              }
            });
          }
          return ValidationException(message, errors: errors);
        }

        return ServerException(data is Map && data['message'] != null 
            ? data['message'].toString() 
            : 'Terjadi kesalahan server.');

      default:
        return const ServerException();
    }
  }
}

String _resolveBaseUrl() {
  const baseUrl = String.fromEnvironment('API_BASE_URL');
  if (baseUrl.isEmpty) {
    throw StateError(
      'API_BASE_URL belum dikonfigurasi. '
      'Jalankan aplikasi dengan --dart-define-from-file=.env.json.',
    );
  }

  final uri = Uri.tryParse(baseUrl);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw StateError('API_BASE_URL harus berupa URL absolut yang valid.');
  }

  return baseUrl;
}

final baseUrlProvider = StateProvider<String>((ref) => _resolveBaseUrl());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: ref.watch(baseUrlProvider));
});

final dioProvider = Provider<Dio>((ref) {
  return ref.watch(apiClientProvider).dio;
});