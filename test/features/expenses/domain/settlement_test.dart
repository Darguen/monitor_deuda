import 'package:flutter_test/flutter_test.dart';
import 'package:monitor_deuda/features/expenses/domain/settlement.dart';

import '../../../helpers/fixtures.dart';

void main() {
  group('Settlement.fromDocument', () {
    test('mapea todos los campos', () {
      final s = Settlement.fromDocument(makeDoc('st1', {
        'groupId': 'g1',
        'fromMember': 'm2',
        'toMember': 'm1',
        'amount': 7000,
      }));
      expect(s.id, 'st1');
      expect(s.groupId, 'g1');
      expect(s.fromMember, 'm2');
      expect(s.toMember, 'm1');
      expect(s.amount, 7000);
      expect(s.createdAt.toUtc(), DateTime.utc(2024, 5, 1, 12));
    });

    test('lanza si falta un campo requerido', () {
      expect(
        () => Settlement.fromDocument(makeDoc('st1', {'groupId': 'g1'})),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
