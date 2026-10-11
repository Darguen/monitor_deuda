import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monitor_deuda/core/appwrite/appwrite_constants.dart';
import 'package:monitor_deuda/core/appwrite/appwrite_providers.dart';
import 'package:monitor_deuda/features/groups/data/groups_repository.dart';

import '../../../helpers/fixtures.dart';

class MockAccount extends Mock implements Account {}

class MockTeams extends Mock implements Teams {}

class MockDatabases extends Mock implements Databases {}

class MockTeam extends Mock implements models.Team {}

void main() {
  late MockAccount account;
  late MockTeams teams;
  late MockDatabases db;
  late GroupsRepository repo;

  setUp(() {
    account = MockAccount();
    teams = MockTeams();
    db = MockDatabases();
    repo = GroupsRepository(account, teams, db, retryDelay: Duration.zero);
  });

  group('listGroups', () {
    test('lista y mapea los grupos', () async {
      when(() => db.listDocuments(
            databaseId: any(named: 'databaseId'),
            collectionId: any(named: 'collectionId'),
            queries: any(named: 'queries'),
          )).thenAnswer((_) async => makeDocList([
            makeDoc('g1', {
              'name': 'Viaje',
              'currency': 'CLP',
              'createdBy': 'u1',
              'teamId': 't1',
            }),
          ]));

      final groups = await repo.listGroups();

      expect(groups.single.name, 'Viaje');
      verify(() => db.listDocuments(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.groupsCollection,
            queries: any(named: 'queries'),
          )).called(1);
    });
  });

  group('createGroup', () {
    late MockTeam team;
    late String createdTeamId;

    setUp(() {
      team = MockTeam();
      when(() => team.$id).thenReturn('t1');
      when(() => account.get()).thenAnswer((_) async => makeUser());
      when(() => teams.create(
            teamId: any(named: 'teamId'),
            name: any(named: 'name'),
          )).thenAnswer((inv) async {
        createdTeamId = inv.namedArguments[#teamId] as String;
        return team;
      });
      when(() => db.createDocument(
            databaseId: any(named: 'databaseId'),
            collectionId: any(named: 'collectionId'),
            documentId: any(named: 'documentId'),
            data: any(named: 'data'),
            permissions: any(named: 'permissions'),
          )).thenAnswer((inv) async => makeDoc('doc1', {
            ...Map<String, dynamic>.from(inv.namedArguments[#data] as Map),
          }));
    });

    test('crea team, grupo y miembro owner', () async {
      final group = await repo.createGroup(name: 'Viaje');

      expect(group.name, 'Viaje');
      expect(group.currency, 'CLP');
      expect(group.teamId, createdTeamId);
      expect(group.createdBy, 'u1');

      verify(() => teams.create(
            teamId: any(named: 'teamId'),
            name: 'Viaje',
          )).called(1);

      final groupCall = verify(() => db.createDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.groupsCollection,
            documentId: any(named: 'documentId'),
            data: captureAny(named: 'data'),
            permissions: captureAny(named: 'permissions'),
          )).captured;
      expect(groupCall[0], {
        'name': 'Viaje',
        'currency': 'CLP',
        'createdBy': 'u1',
        'teamId': createdTeamId,
      });
      expect(groupCall[1], [
        Permission.read(Role.team(createdTeamId)),
        Permission.update(Role.team(createdTeamId, 'owner')),
        Permission.delete(Role.team(createdTeamId, 'owner')),
      ]);

      final memberCall = verify(() => db.createDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.membersCollection,
            documentId: any(named: 'documentId'),
            data: captureAny(named: 'data'),
            permissions: any(named: 'permissions'),
          )).captured.single as Map;
      expect(memberCall['userId'], 'u1');
      expect(memberCall['displayName'], 'Ana');
      expect(memberCall['role'], 'owner');
    });

    test('permite elegir la moneda', () async {
      final group = await repo.createGroup(name: 'Viaje', currency: 'USD');
      expect(group.currency, 'USD');
    });

    test('si falla crear el miembro, deshace grupo y team', () async {
      when(() => db.createDocument(
            databaseId: any(named: 'databaseId'),
            collectionId: AppwriteConstants.membersCollection,
            documentId: any(named: 'documentId'),
            data: any(named: 'data'),
            permissions: any(named: 'permissions'),
          )).thenThrow(AppwriteException('sin permiso', 403));
      when(() => db.deleteDocument(
            databaseId: any(named: 'databaseId'),
            collectionId: any(named: 'collectionId'),
            documentId: any(named: 'documentId'),
          )).thenAnswer((_) async {});
      when(() => teams.delete(teamId: any(named: 'teamId')))
          .thenAnswer((_) async {});

      await expectLater(
        repo.createGroup(name: 'Viaje'),
        throwsA(isA<AppwriteException>().having((e) => e.code, 'code', 403)),
      );

      verify(() => db.deleteDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.groupsCollection,
            documentId: any(named: 'documentId'),
          )).called(1);
      verify(() => teams.delete(teamId: createdTeamId)).called(1);
    });

    test('si falla crear el team no queda nada creado', () async {
      when(() => teams.create(
            teamId: any(named: 'teamId'),
            name: any(named: 'name'),
          )).thenThrow(AppwriteException('sin permiso', 403));
      when(() => db.deleteDocument(
            databaseId: any(named: 'databaseId'),
            collectionId: any(named: 'collectionId'),
            documentId: any(named: 'documentId'),
          )).thenAnswer((_) async {});
      when(() => teams.delete(teamId: any(named: 'teamId')))
          .thenThrow(AppwriteException('no existe', 404));

      await expectLater(
        repo.createGroup(name: 'Viaje'),
        throwsA(isA<AppwriteException>()),
      );

      verifyNever(() => db.createDocument(
            databaseId: any(named: 'databaseId'),
            collectionId: any(named: 'collectionId'),
            documentId: any(named: 'documentId'),
            data: any(named: 'data'),
            permissions: any(named: 'permissions'),
          ));
    });

    test('reintenta crear el team ante un 503', () async {
      var calls = 0;
      when(() => teams.create(
            teamId: any(named: 'teamId'),
            name: any(named: 'name'),
          )).thenAnswer((inv) async {
        createdTeamId = inv.namedArguments[#teamId] as String;
        if (++calls == 1) throw AppwriteException('caído', 503);
        return team;
      });

      final group = await repo.createGroup(name: 'Viaje');

      expect(calls, 2);
      expect(group.teamId, createdTeamId);
    });
  });

  group('groupsRepositoryProvider', () {
    test('construye el repositorio', () {
      final container = ProviderContainer(overrides: [
        accountProvider.overrideWithValue(account),
        teamsProvider.overrideWithValue(teams),
        databasesProvider.overrideWithValue(db),
      ]);
      addTearDown(container.dispose);
      expect(container.read(groupsRepositoryProvider), isA<GroupsRepository>());
    });
  });
}
