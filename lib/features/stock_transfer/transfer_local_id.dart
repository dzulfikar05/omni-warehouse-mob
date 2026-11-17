import 'dart:math';

String generateTransferLocalId() {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  final suffix = List.generate(
    8,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();

  return 'TX-TRF-$suffix';
}
