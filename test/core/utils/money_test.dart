import 'package:flutter_test/flutter_test.dart';
import 'package:monitor_deuda/core/utils/money.dart';

void main() {
  group('formatMoney', () {
    test('cero', () => expect(formatMoney(0), r'$0'));
    test('menos de mil no lleva separador', () => expect(formatMoney(999), r'$999'));
    test('miles', () => expect(formatMoney(1000), r'$1.000'));
    test('12345 -> \$12.345', () => expect(formatMoney(12345), r'$12.345'));
    test('millones', () => expect(formatMoney(1234567), r'$1.234.567'));
    test('negativos llevan el signo antes del \$', () {
      expect(formatMoney(-5000), r'-$5.000');
    });
  });
}
