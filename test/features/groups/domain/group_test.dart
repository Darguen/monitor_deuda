import 'package:flutter_test/flutter_test.dart';
import 'package:monitor_deuda/features/groups/domain/group.dart';

import '../../../helpers/fixtures.dart';

void main() {
  group('Group.fromDocument', () {
    test('mapea todos los campos', () {
      final g = Group.fromDocument(makeDoc('g1', {
        'name': 'Viaje a Pucón',
        'currency': 'CLP',
        'createdBy': 'u1',
        'teamId': 't1',
      }));
      expect(g.id, 'g1');
      expect(g.name, 'Viaje a Pucón');
      expect(g.currency, 'CLP');
      expect(g.createdBy, 'u1');
      expect(g.teamId, 't1');
    });

    test('lanza si falta un campo requerido', () {
      expect(
        () => Group.fromDocument(makeDoc('g1', {'name': 'x'})),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
