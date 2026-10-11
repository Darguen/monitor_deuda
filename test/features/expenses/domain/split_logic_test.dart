import 'package:flutter_test/flutter_test.dart';
import 'package:monitor_deuda/features/expenses/domain/split_logic.dart';

int sum(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);

void main() {
  group('splitEqually', () {
    test('reparte sin perder pesos', () {
      final r = splitEqually(100, ['a', 'b', 'c']);
      expect(sum(r), 100);
      expect(r, {'a': 34, 'b': 33, 'c': 33});
    });

    test('monto divisible reparte parejo', () {
      expect(splitEqually(90, ['a', 'b', 'c']), {'a': 30, 'b': 30, 'c': 30});
    });

    test('un solo participante se lleva todo', () {
      expect(splitEqually(777, ['a']), {'a': 777});
    });

    test('el resto se reparte de a uno desde el primero', () {
      expect(splitEqually(5, ['a', 'b', 'c']), {'a': 2, 'b': 2, 'c': 1});
    });
  });

  group('splitByPercent', () {
    test('33/33/34 suma exacto', () {
      final r = splitByPercent(100, {'a': 33, 'b': 33, 'c': 34});
      expect(sum(r), 100);
      expect(r, {'a': 33, 'b': 33, 'c': 34});
    });

    test('50/50 con monto impar suma exacto', () {
      expect(sum(splitByPercent(101, {'a': 50, 'b': 50})), 101);
    });

    test('el mayor resto recibe el peso sobrante', () {
      // 10 * 33% = 3.3 y 10 * 67% = 6.7 -> el sobrante va a quien tiene más resto.
      expect(splitByPercent(10, {'a': 33, 'b': 67}), {'a': 3, 'b': 7});
    });

    test('100% a un solo miembro', () {
      expect(splitByPercent(999, {'a': 100}), {'a': 999});
    });

    test('0% recibe 0', () {
      expect(splitByPercent(100, {'a': 0, 'b': 100}), {'a': 0, 'b': 100});
    });
  });
}
