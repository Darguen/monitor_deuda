import 'package:flutter_test/flutter_test.dart';
import 'package:monitor_deuda/features/expenses/domain/split_logic.dart';
import 'package:monitor_deuda/features/expenses/domain/simplify_debts.dart';

void main() {
  test('reparte sin perder pesos', () {
    final r = splitEqually(100, ['a', 'b', 'c']);
    expect(r.values.fold<int>(0, (a, b) => a + b), 100);
    expect(r['a'], 34);
    expect(r['b'], 33);
  });

  test('simplifica deudas y deja a todos en cero', () {
    // Ana debe 10.000, Beto debe 5.000, Carla tiene a favor 15.000
    final t = simplifyDebts({'ana': -10000, 'beto': -5000, 'carla': 15000});
    expect(t.length, 2);
    expect(t.fold<int>(0, (a, x) => a + x.amount), 15000);
    expect(t.every((x) => x.to == 'carla'), true);
  });

  test('porcentajes reparten sin perder pesos', () {
    final r = splitByPercent(100, {'a': 33, 'b': 33, 'c': 34});
    expect(r.values.fold<int>(0, (a, b) => a + b), 100);
  });

  test('porcentajes 50/50 con monto impar', () {
    final r = splitByPercent(101, {'a': 50, 'b': 50});
    expect(r.values.fold<int>(0, (a, b) => a + b), 101);
  });
}