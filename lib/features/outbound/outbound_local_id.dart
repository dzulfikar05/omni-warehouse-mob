import 'dart:math';

String generateOutboundLocalId() {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  final suffix = List.generate(
    8,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();

  return 'OUT-$suffix';
}
