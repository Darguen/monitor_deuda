import 'package:flutter_test/flutter_test.dart';
import 'package:monitor_deuda/features/groups/domain/member.dart';

import '../../../helpers/fixtures.dart';

void main() {
  group('Member.fromDocument', () {
    test('mapea miembro con cuenta', () {
      final m = Member.fromDocument(makeDoc('m1', {
        'groupId': 'g1',
        'userId': 'u1',
        'displayName': 'Ana',
        'role': 'owner',
      }));
      expect(m.id, 'm1');
      expect(m.groupId, 'g1');
      expect(m.userId, 'u1');
      expect(m.displayName, 'Ana');
      expect(m.role, 'owner');
      expect(m.hasAccount, isTrue);
    });

    test('miembro sin userId no tiene cuenta', () {
      final m = Member.fromDocument(makeDoc('m2', {
        'groupId': 'g1',
        'displayName': 'Beto',
        'role': 'member',
      }));
      expect(m.userId, isNull);
      expect(m.hasAccount, isFalse);
    });
  });
}
