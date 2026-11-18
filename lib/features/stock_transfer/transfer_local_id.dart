import 'dart:math';

import 'package:uuid/uuid.dart';

String generateTransferLocalId([DateTime? createdAt]) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final date = createdAt ?? DateTime.now();
  final suffix = List.generate(
    4,
    (_) => alphabet[Random.secure().nextInt(alphabet.length)],
  ).join();
  final datePart =
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  return 'TRF-$datePart-$suffix';
}

String generateTransferLocalUuid() => const Uuid().v4();
