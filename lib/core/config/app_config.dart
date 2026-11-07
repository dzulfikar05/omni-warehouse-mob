import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../auth/secure_storage.dart';

/// Konfigurasi global lingkungan (Environment Configuration).
/// Mendukung hierarki 4 tingkat:
/// 1. [Prioritas Tertinggi] In-App Custom Override (Disimpan di HP via SecureStorage)
/// 2. Compile-time variables (`--dart-define` / `--dart-define-from-file=.env.json`)
/// 3. Runtime `.env` asset file
/// 4. [Default Fallback] Zero-config otomatis untuk Android Emulator (10.0.2.2) & Web/Simulator (127.0.0.1).
class AppConfig {
  AppConfig._();

  static String? _loadedEnvBaseUrl;
  static String? _storedCustomBaseUrl;

  /// Inisialisasi awal membaca custom override & file `.env`.
  /// Dipanggil sekali saat app start di `main()`.
  static Future<void> init() async {
    // 1. Baca server custom yang pernah disimpan user di HP ini
    try {
      _storedCustomBaseUrl = await SecureStorage.instance.getCustomServerUrl();
    } catch (_) {}

    // 2. Baca file .env jika ada di assets
    try {
      final content = await rootBundle.loadString('.env');
      final lines = content.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final parts = trimmed.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final val = parts.sublist(1).join('=').trim();
          if (key == 'API_BASE_URL' && val.isNotEmpty) {
            _loadedEnvBaseUrl = val;
          }
        }
      }
    } catch (_) {}
  }

  /// Apakah server saat ini menggunakan konfigurasi custom in-app
  static bool get isCustom =>
      _storedCustomBaseUrl != null && _storedCustomBaseUrl!.isNotEmpty;

  /// Menyimpan override URL server langsung dari UI HP
  static Future<void> setCustomBaseUrl(String url) async {
    final clean = _normalizeUrl(url);
    _storedCustomBaseUrl = clean;
    await SecureStorage.instance.saveCustomServerUrl(clean);
  }

  /// Menghapus override custom dan kembali ke default auto-detect/.env
  static Future<void> resetToDefault() async {
    _storedCustomBaseUrl = null;
    await SecureStorage.instance.clearCustomServerUrl();
  }

  /// Resolusi cerdas URL dasar API Laravel:
  static String get baseUrl {
    // 1. In-App User Custom Override (Paling utama jika disetel di HP)
    if (_storedCustomBaseUrl != null && _storedCustomBaseUrl!.isNotEmpty) {
      return _normalizeUrl(_storedCustomBaseUrl!);
    }

    // 2. Compile-time flag
    const dartDefineUrl = String.fromEnvironment('API_BASE_URL');
    if (dartDefineUrl.isNotEmpty) {
      return _normalizeUrl(dartDefineUrl);
    }

    // 3. Dari file .env
    if (_loadedEnvBaseUrl != null && _loadedEnvBaseUrl!.isNotEmpty) {
      return _normalizeUrl(_loadedEnvBaseUrl!);
    }

    // 4. Fallback Auto-detect Platform
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }

    if (Platform.isAndroid) {
      // Android Emulator host loopback adalah 10.0.2.2
      return 'http://10.0.2.2:8000/api';
    }

    if (Platform.isIOS) {
      return 'http://127.0.0.1:8000/api';
    }

    return 'http://127.0.0.1:8000/api';
  }

  static String _normalizeUrl(String url) {
    var clean = url.trim();
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'http://$clean';
    }
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (!clean.endsWith('/api')) {
      clean = '$clean/api';
    }
    return clean;
  }
}
