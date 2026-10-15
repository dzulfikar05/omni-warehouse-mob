import 'package:dio/dio.dart';

/// Singleton Dio instance dengan interceptors:
/// - Auto-inject Bearer token dari SecureStorage
/// - Handle 401 → redirect ke login
/// - Handle 422 → parse Laravel validation errors
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  late final Dio dio;

  // TODO: initialize(String baseUrl) — panggil dari main.dart setelah tenant login
}
