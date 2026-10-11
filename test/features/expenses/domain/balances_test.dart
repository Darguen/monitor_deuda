import 'package:flutter_test/flutter_test.dart';
import 'package:monitor_deuda/features/expenses/domain/balances.dart';
import 'package:monitor_deuda/features/expenses/domain/expense.dart';
import 'package:monitor_deuda/features/expenses/domain/settlement.dart';

Expense expense(String id, String paidBy, int amount) => Expense(
      id: id,
      groupId: 'g',
      description: 'x',
      amount: amount,
      paidBy: paidBy,
      createdAt: DateTime(2024),
    );

ExpenseSplit split(String expenseId, String member, int share) => ExpenseSplit(
      id: '$expenseId-$member',
      expenseId: expenseId,
      memberId: member,
      share: share,
    );

Settlement settlement(String from, String to, int amount) => Settlement(
      id: '$from-$to',
      groupId: 'g',
      fromMember: from,
      toMember: to,
      amount: amount,
      createdAt: DateTime(2024),
    );

void main() {
  group('computeBalances', () {
    test('sin movimientos todos quedan en 0', () {
      final b = computeBalances(
        memberIds: ['a', 'b'],
        expenses: [],
        splits: [],
        settlements: [],
      );
      expect(b, {'a': 0, 'b': 0});
    });

    test('quien paga queda a favor y el resto debe su parte', () {
      final b = computeBalances(
        memberIds: ['a', 'b', 'c'],
        expenses: [expense('e1', 'a', 300)],
        splits: [
          split('e1', 'a', 100),
          split('e1', 'b', 100),
          split('e1', 'c', 100),
        ],
        settlements: [],
      );
      expect(b, {'a': 200, 'b': -100, 'c': -100});
    });

    test('un pago registrado reduce la deuda', () {
      final b = computeBalances(
        memberIds: ['a', 'b'],
        expenses: [expense('e1', 'a', 200)],
        splits: [split('e1', 'a', 100), split('e1', 'b', 100)],
        settlements: [settlement('b', 'a', 100)],
      );
      expect(b, {'a': 0, 'b': 0});
    });

    test('la suma de saldos siempre es 0', () {
      final b = computeBalances(
        memberIds: ['a', 'b', 'c'],
        expenses: [expense('e1', 'a', 100), expense('e2', 'b', 50)],
        splits: [
          split('e1', 'a', 34),
          split('e1', 'b', 33),
          split('e1', 'c', 33),
          split('e2', 'b', 25),
          split('e2', 'c', 25),
        ],
        settlements: [settlement('c', 'a', 10)],
      );
      expect(b.values.fold<int>(0, (x, y) => x + y), 0);
    });

    test('ids que no están en memberIds igual se contabilizan', () {
      final b = computeBalances(
        memberIds: ['a'],
        expenses: [expense('e1', 'z', 100)],
        splits: [split('e1', 'a', 100)],
        settlements: [],
      );
      expect(b['z'], 100);
      expect(b['a'], -100);
    });
  });
}
