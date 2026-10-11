import 'package:flutter_test/flutter_test.dart';
import 'package:monitor_deuda/features/expenses/domain/simplify_debts.dart';

void main() {
  group('Transfer', () {
    test('guarda sus campos', () {
      const t = Transfer(from: 'a', to: 'b', amount: 10);
      expect([t.from, t.to, t.amount], ['a', 'b', 10]);
    });
  });

  group('simplifyDebts', () {
    test('mapa vacío no genera pagos', () {
      expect(simplifyDebts({}), isEmpty);
    });

    test('todos en cero no genera pagos', () {
      expect(simplifyDebts({'a': 0, 'b': 0}), isEmpty);
    });

    test('dos deudores un acreedor', () {
      final t = simplifyDebts({'ana': -10000, 'beto': -5000, 'carla': 15000});
      expect(t.length, 2);
      expect(t.fold<int>(0, (a, x) => a + x.amount), 15000);
      expect(t.every((x) => x.to == 'carla'), isTrue);
    });

    test('un deudor un acreedor genera un solo pago', () {
      final t = simplifyDebts({'a': -300, 'b': 300});
      expect(t.single.from, 'a');
      expect(t.single.to, 'b');
      expect(t.single.amount, 300);
    });

    test('empareja mayor deudor con mayor acreedor', () {
      final t = simplifyDebts({'d1': -700, 'd2': -300, 'c1': 600, 'c2': 400});
      expect(t.first.from, 'd1');
      expect(t.first.to, 'c1');
      expect(t.first.amount, 600);
    });

    test('al aplicar los pagos todos quedan en cero', () {
      final balances = {'a': -250, 'b': -150, 'c': 100, 'd': 300};
      final after = {...balances};
      for (final t in simplifyDebts(balances)) {
        after[t.from] = after[t.from]! + t.amount;
        after[t.to] = after[t.to]! - t.amount;
      }
      expect(after.values.every((v) => v == 0), isTrue);
    });

    test('no muta el mapa de entrada', () {
      final balances = {'a': -100, 'b': 100};
      simplifyDebts(balances);
      expect(balances, {'a': -100, 'b': 100});
    });
  });
}
