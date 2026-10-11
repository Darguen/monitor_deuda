import 'package:flutter_test/flutter_test.dart';
import 'package:monitor_deuda/features/expenses/domain/expense.dart';

import '../../../helpers/fixtures.dart';

void main() {
  group('Expense.fromDocument', () {
    test('mapea todos los campos', () {
      final e = Expense.fromDocument(makeDoc('e1', {
        'groupId': 'g1',
        'description': 'Cena',
        'amount': 15000,
        'paidBy': 'm1',
      }));
      expect(e.id, 'e1');
      expect(e.groupId, 'g1');
      expect(e.description, 'Cena');
      expect(e.amount, 15000);
      expect(e.paidBy, 'm1');
    });

    test('createdAt se parsea desde \$createdAt', () {
      final e = Expense.fromDocument(makeDoc(
        'e1',
        {'groupId': 'g', 'description': 'd', 'amount': 1, 'paidBy': 'm'},
        createdAt: '2024-05-01T12:00:00.000+00:00',
      ));
      expect(e.createdAt.toUtc(), DateTime.utc(2024, 5, 1, 12));
    });

    test('lanza si falta un campo requerido', () {
      expect(
        () => Expense.fromDocument(makeDoc('e1', {'groupId': 'g'})),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('ExpenseSplit.fromDocument', () {
    test('mapea todos los campos', () {
      final s = ExpenseSplit.fromDocument(makeDoc('s1', {
        'expenseId': 'e1',
        'memberId': 'm1',
        'share': 5000,
      }));
      expect(s.id, 's1');
      expect(s.expenseId, 'e1');
      expect(s.memberId, 'm1');
      expect(s.share, 5000);
    });
  });
}
