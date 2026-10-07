class Transfer {
  const Transfer({required this.from, required this.to, required this.amount});
  final String from; // quien debe pagar
  final String to; // quien recibe
  final int amount;
}

class _Entry {
  _Entry(this.id, this.amount);
  final String id;
  int amount;
}

/// Empareja al mayor deudor con el mayor acreedor hasta saldar todo.
List<Transfer> simplifyDebts(Map<String, int> balances) {
  int byAmountDesc(_Entry a, _Entry b) => b.amount.compareTo(a.amount);

  final creditors = balances.entries
      .where((e) => e.value > 0)
      .map((e) => _Entry(e.key, e.value))
      .toList()
    ..sort(byAmountDesc);
  final debtors = balances.entries
      .where((e) => e.value < 0)
      .map((e) => _Entry(e.key, -e.value))
      .toList()
    ..sort(byAmountDesc);

  final result = <Transfer>[];
  var i = 0, j = 0;
  while (i < debtors.length && j < creditors.length) {
    final d = debtors[i];
    final c = creditors[j];
    final amount = d.amount < c.amount ? d.amount : c.amount;
    result.add(Transfer(from: d.id, to: c.id, amount: amount));
    d.amount -= amount;
    c.amount -= amount;
    if (d.amount == 0) i++;
    if (c.amount == 0) j++;
  }
  return result;
}