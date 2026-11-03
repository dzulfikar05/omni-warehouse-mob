sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Tidak ada koneksi internet. Periksa jaringan Anda.',
  ]);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([
    super.message = 'Sesi habis. Silakan login kembali.',
  ]);
}

class ValidationException extends AppException {
  const ValidationException(super.message, {required this.errors});
  final Map<String, List<String>> errors;

  String? getFirstError(String field) => errors[field]?.first;
}

class ServerException extends AppException {
  const ServerException([super.message = 'Terjadi kesalahan server gudang.']);
}
