/// Reparte [amount] en partes iguales sin perder pesos:
/// $100 entre 3 -> 34, 33, 33 (la suma siempre es exactamente [amount]).
Map<String, int> splitEqually(int amount, List<String> memberIds) {
  final n = memberIds.length;
  final base = amount ~/ n;
  var remainder = amount - base * n;
  final result = <String, int>{};
  for (final id in memberIds) {
    result[id] = base + (remainder > 0 ? 1 : 0);
    if (remainder > 0) remainder--;
  }
  return result;
}

/// Reparte [amount] según porcentajes enteros (deben sumar 100).
/// Usa el método del mayor resto, así la suma siempre es exactamente [amount].
Map<String, int> splitByPercent(int amount, Map<String, int> percents) {
  final ids = percents.keys.toList();
  final shares = <String, int>{};
  final fractions = <String, int>{};
  var assigned = 0;

  for (final id in ids) {
    final raw = amount * percents[id]!;
    shares[id] = raw ~/ 100;
    fractions[id] = raw % 100;
    assigned += shares[id]!;
  }

  var remainder = amount - assigned;
  final order = [...ids]
    ..sort((a, b) => fractions[b]!.compareTo(fractions[a]!));
  for (final id in order) {
    if (remainder <= 0) break;
    shares[id] = shares[id]! + 1;
    remainder--;
  }
  return shares;
}