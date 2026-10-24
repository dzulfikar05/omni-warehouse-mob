import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/secure_storage.dart';
import 'api_exception.dart';

/// Singleton Dio instance dengan interceptors:
/// - Auto-inject Bearer token dari SecureStorage
/// - Auto-prefix tenant route jika baseUrl belum mencakup tenant
/// - Handle 401 → redirect ke login / UnauthorizedException
/// - Handle 422 → parse Laravel validation errors (ValidationException)
class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
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
          // 1. Inject Bearer token
          final token = await SecureStorage.instance.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // 2. Multi-tenant prefix handling jika diperlukan
          final tenantSlug = await SecureStorage.instance.getTenantSlug();
          if (tenantSlug != null && tenantSlug.isNotEmpty) {
            options.headers['X-Tenant-Slug'] = tenantSlug;
          }

          handler.next(options);
        },
        onResponse: (response, handler) {
          handler.next(response);
        },
        onError: (DioException error, handler) {
          final mappedException = _mapDioException(error);
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              type: error.type,
              error: mappedException,
            ),
          );
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._();
  late final Dio _dio;

  Dio get dio => _dio;

  /// Inisialisasi baseUrl (misal: "https://api.omniwarehouse.com" atau IP lokal)
  void initialize(String baseUrl, {String? tenantSlug}) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    if (tenantSlug != null && tenantSlug.isNotEmpty) {
      _dio.options.baseUrl = '$cleanBase/api/tenant/$tenantSlug';
    } else {
      _dio.options.baseUrl = cleanBase;
    }
  }

  static AppException _mapDioException(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const NetworkException();
    }

    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;

    if (statusCode == 401) {
      return const UnauthorizedException();
    }

    if (statusCode == 404) {
      final msg = responseData is Map && responseData['message'] != null
          ? responseData['message'].toString()
          : 'Data tidak ditemukan di server.';
      return NotFoundException(msg);
    }

    if (statusCode == 422 && responseData is Map) {
      final message = responseData['message']?.toString() ?? 'Validasi gagal.';
      final rawErrors = responseData['errors'];
      final errors = <String, List<String>>{};
      if (rawErrors is Map) {
        rawErrors.forEach((key, val) {
          if (val is List) {
            errors[key.toString()] = val.map((e) => e.toString()).toList();
          } else if (val != null) {
            errors[key.toString()] = [val.toString()];
          }
        });
      }
      return ValidationException(message, errors: errors);
    }

    if (statusCode != null && statusCode >= 500) {
      return const ServerException();
    }

    return const ServerException();
  }
}

/// Provider ApiClient untuk Riverpod DI
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient.instance;
});

/// Provider Dio instance untuk repository layer
final dioProvider = Provider<Dio>((ref) {
  return ref.watch(apiClientProvider).dio;
});
