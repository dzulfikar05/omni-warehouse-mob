import 'dart:math';

String generateInboundLocalId() {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  final suffix = List.generate(
    8,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();

  return 'TX-INB-$suffix';
}
