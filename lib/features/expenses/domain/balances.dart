import 'expense.dart';
import 'settlement.dart';

/// Saldo neto por miembro. Positivo = le deben; negativo = debe.
Map<String, int> computeBalances({
  required List<String> memberIds,
  required List<Expense> expenses,
  required List<ExpenseSplit> splits,
  required List<Settlement> settlements,
}) {
  final balances = {for (final id in memberIds) id: 0};
  for (final e in expenses) {
    balances[e.paidBy] = (balances[e.paidBy] ?? 0) + e.amount;
  }
  for (final s in splits) {
    balances[s.memberId] = (balances[s.memberId] ?? 0) - s.share;
  }
  // Quien paga una deuda sube su saldo; quien la recibe lo baja.
  for (final s in settlements) {
    balances[s.fromMember] = (balances[s.fromMember] ?? 0) + s.amount;
    balances[s.toMember] = (balances[s.toMember] ?? 0) - s.amount;
  }
  return balances;
}