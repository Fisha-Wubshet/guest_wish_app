import 'dart:math';

/// Generate a strong password: 1 upper + 3 lower + 4 lower + 4 digits.
/// Ambiguous chars (I, l, 1, O, 0) are excluded.
String generatePassword() {
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const lower = 'abcdefghjkmnpqrstuvwxyz';
  const digits = '23456789';

  final rand = Random.secure();
  String pick(String pool, int n) =>
      List.generate(n, (_) => pool[rand.nextInt(pool.length)]).join();

  return pick(upper, 1) + pick(lower, 3) + pick(lower, 4) + pick(digits, 4);
}
