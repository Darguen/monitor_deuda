import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monitor_deuda/core/appwrite/appwrite_constants.dart';
import 'package:monitor_deuda/core/appwrite/appwrite_providers.dart';
import 'package:monitor_deuda/features/groups/data/members_repository.dart';

import '../../../helpers/fixtures.dart';

class MockDatabases extends Mock implements Databases {}

void main() {
  late MockDatabases db;
  late MembersRepository repo;

  setUp(() {
    db = MockDatabases();
    repo = MembersRepository(db);
  });

  group('listMembers', () {
    test('consulta la colección de miembros del grupo y mapea', () async {
      when(() => db.listDocuments(
            databaseId: any(named: 'databaseId'),
            collectionId: any(named: 'collectionId'),
            queries: any(named: 'queries'),
          )).thenAnswer((_) async => makeDocList([
            makeDoc('m1', {
              'groupId': 'g1',
              'userId': 'u1',
              'displayName': 'Ana',
              'role': 'owner',
            }),
            makeDoc('m2', {
              'groupId': 'g1',
              'displayName': 'Beto',
              'role': 'member',
            }),
          ]));

      final members = await repo.listMembers('g1');

      expect(members.map((m) => m.displayName), ['Ana', 'Beto']);
      expect(members.last.hasAccount, isFalse);

      final captured = verify(() => db.listDocuments(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.membersCollection,
            queries: captureAny(named: 'queries'),
          )).captured.single as List<String>;
      expect(captured, contains(Query.equal('groupId', 'g1')));
      expect(captured, contains(Query.limit(100)));
    });
  });

  group('addMember', () {
    test('crea un miembro sin userId con permisos del team', () async {
      when(() => db.createDocument(
            databaseId: any(named: 'databaseId'),
            collectionId: any(named: 'collectionId'),
            documentId: any(named: 'documentId'),
            data: any(named: 'data'),
            permissions: any(named: 'permissions'),
          )).thenAnswer((_) async => makeDoc('m9', {}));

      await repo.addMember(group: testGroup, displayName: 'Carla');

      final call = verify(() => db.createDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.membersCollection,
            documentId: any(named: 'documentId'),
            data: captureAny(named: 'data'),
            permissions: captureAny(named: 'permissions'),
          )).captured;

      expect(call[0], {
        'groupId': 'g1',
        'displayName': 'Carla',
        'role': 'member',
      });
      expect(call[1], [
        Permission.read(Role.team('t1')),
        Permission.update(Role.team('t1', 'owner')),
        Permission.delete(Role.team('t1', 'owner')),
      ]);
    });
  });

  group('providers', () {
    test('membersProvider lista los miembros del grupo', () async {
      when(() => db.listDocuments(
            databaseId: any(named: 'databaseId'),
            collectionId: any(named: 'collectionId'),
            queries: any(named: 'queries'),
          )).thenAnswer((_) async => makeDocList([]));
      final container = ProviderContainer(
        overrides: [databasesProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      expect(await container.read(membersProvider('g1').future), isEmpty);
    });
  });
}
