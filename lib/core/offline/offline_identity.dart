import 'dart:convert';

import 'package:crypto/crypto.dart';

String offlineOwnerKey({int? userId, required String token}) {
  if (userId != null) return 'user:$userId';
  return 'token:${sha256.convert(utf8.encode(token))}';
}
