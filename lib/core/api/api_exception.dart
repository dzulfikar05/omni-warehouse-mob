/// Custom exception untuk semua error dari API layer.
/// Screen tidak perlu tahu DioException — cukup tangkap AppException.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;
}

class NetworkException extends AppException {
  const NetworkException() : super('Tidak ada koneksi. Data disimpan offline.');
}

class UnauthorizedException extends AppException {
  const UnauthorizedException() : super('Sesi habis. Silakan login kembali.');
}

class ValidationException extends AppException {
  const ValidationException(super.message, {required this.errors});
  final Map<String, List<String>> errors;
}

class ServerException extends AppException {
  const ServerException() : super('Terjadi kesalahan server. Coba lagi.');
}

class NotFoundException extends AppException {
  const NotFoundException(super.message);
}
