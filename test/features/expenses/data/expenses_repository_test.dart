import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monitor_deuda/core/appwrite/appwrite_constants.dart';
import 'package:monitor_deuda/core/appwrite/appwrite_providers.dart';
import 'package:monitor_deuda/features/expenses/data/expenses_repository.dart';

import '../../../helpers/fixtures.dart';

class MockDatabases extends Mock implements Databases {}

void main() {
  late MockDatabases db;
  late ExpensesRepository repo;

  setUp(() {
    db = MockDatabases();
    repo = ExpensesRepository(db, retryDelay: Duration.zero);
  });

  void stubList(List docs) {
    when(() => db.listDocuments(
          databaseId: any(named: 'databaseId'),
          collectionId: any(named: 'collectionId'),
          queries: any(named: 'queries'),
        )).thenAnswer((_) async => makeDocList(List.from(docs)));
  }

  void stubCreate() {
    var n = 0;
    when(() => db.createDocument(
          databaseId: any(named: 'databaseId'),
          collectionId: any(named: 'collectionId'),
          documentId: any(named: 'documentId'),
          data: any(named: 'data'),
          permissions: any(named: 'permissions'),
        )).thenAnswer((_) async => makeDoc('new${n++}', {}));
  }

  group('listExpenses', () {
    test('filtra por grupo, ordena y limita a 100', () async {
      stubList([
        makeDoc('e1', {
          'groupId': 'g1',
          'description': 'Cena',
          'amount': 9000,
          'paidBy': 'm1',
        }),
      ]);

      final list = await repo.listExpenses('g1');

      expect(list.single.description, 'Cena');
      final queries = verify(() => db.listDocuments(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.expensesCollection,
            queries: captureAny(named: 'queries'),
          )).captured.single as List<String>;
      expect(queries, contains(Query.equal('groupId', 'g1')));
      expect(queries, contains(Query.orderDesc(r'$createdAt')));
      expect(queries, contains(Query.limit(100)));
    });
  });

  group('listSplits', () {
    test('filtra por grupo y limita a 500', () async {
      stubList([
        makeDoc('s1', {'expenseId': 'e1', 'memberId': 'm1', 'share': 100}),
      ]);

      final list = await repo.listSplits('g1');

      expect(list.single.share, 100);
      final queries = verify(() => db.listDocuments(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.splitsCollection,
            queries: captureAny(named: 'queries'),
          )).captured.single as List<String>;
      expect(queries, contains(Query.equal('groupId', 'g1')));
      expect(queries, contains(Query.limit(500)));
    });
  });

  group('listSettlements', () {
    test('filtra por grupo y mapea', () async {
      stubList([
        makeDoc('st1', {
          'groupId': 'g1',
          'fromMember': 'm2',
          'toMember': 'm1',
          'amount': 500,
        }),
      ]);

      final list = await repo.listSettlements('g1');

      expect(list.single.amount, 500);
      verify(() => db.listDocuments(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.settlementsCollection,
            queries: any(named: 'queries'),
          )).called(1);
    });
  });

  group('addExpense', () {
    test('crea el gasto y una parte por miembro', () async {
      stubCreate();

      await repo.addExpense(
        group: testGroup,
        createdBy: 'u1',
        description: 'Cena',
        amount: 300,
        paidBy: 'm1',
        shares: {'m1': 150, 'm2': 150},
        splitType: 'equal',
      );

      final expenseCall = verify(() => db.createDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.expensesCollection,
            documentId: captureAny(named: 'documentId'),
            data: captureAny(named: 'data'),
            permissions: captureAny(named: 'permissions'),
          )).captured;
      final expenseId = expenseCall[0] as String;
      expect(expenseCall[1], {
        'groupId': 'g1',
        'description': 'Cena',
        'amount': 300,
        'paidBy': 'm1',
        'splitType': 'equal',
        'createdBy': 'u1',
      });
      expect(expenseCall[2], [
        Permission.read(Role.team('t1')),
        Permission.update(Role.user('u1')),
        Permission.delete(Role.user('u1')),
        Permission.update(Role.team('t1', 'owner')),
        Permission.delete(Role.team('t1', 'owner')),
      ]);

      final splits = verify(() => db.createDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.splitsCollection,
            documentId: any(named: 'documentId'),
            data: captureAny(named: 'data'),
            permissions: any(named: 'permissions'),
          )).captured.map((m) => Map<String, dynamic>.from(m as Map)).toList();
      expect(splits.length, 2);
      expect(splits.map((s) => s['memberId']).toList(), ['m1', 'm2']);
      expect(splits.every((s) => s['expenseId'] == expenseId), isTrue);
      expect(splits.every((s) => s['groupId'] == 'g1'), isTrue);
      expect(splits.map((s) => s['share']).toList(), [150, 150]);
    });

    test('reintenta un fallo transitorio sin duplicar el documento', () async {
      var calls = 0;
      final ids = <String>[];
      when(() => db.createDocument(
            databaseId: any(named: 'databaseId'),
            collectionId: any(named: 'collectionId'),
            documentId: any(named: 'documentId'),
            data: any(named: 'data'),
            permissions: any(named: 'permissions'),
          )).thenAnswer((inv) async {
        ids.add(inv.namedArguments[#documentId] as String);
        if (++calls == 1) throw AppwriteException('sin red', 503);
        return makeDoc('x', {});
      });

      await repo.addExpense(
        group: testGroup,
        createdBy: 'u1',
        description: 'Cena',
        amount: 100,
        paidBy: 'm1',
        shares: {'m1': 100},
        splitType: 'equal',
      );

      // 1 intento fallido + 1 reintento del gasto + 1 parte.
      expect(calls, 3);
      expect(ids[0], ids[1], reason: 'el reintento reusa el mismo ID');
    });

    test('si falla una parte, deshace las partes y el gasto', () async {
      var calls = 0;
      when(() => db.createDocument(
            databaseId: any(named: 'databaseId'),
            collectionId: any(named: 'collectionId'),
            documentId: any(named: 'documentId'),
            data: any(named: 'data'),
            permissions: any(named: 'permissions'),
          )).thenAnswer((_) async {
        // gasto, parte 1 OK; la parte 2 falla con un error no reintentable.
        if (++calls == 3) throw AppwriteException('sin permiso', 403);
        return makeDoc('x', {});
      });
      when(() => db.deleteDocument(
            databaseId: any(named: 'databaseId'),
            collectionId: any(named: 'collectionId'),
            documentId: any(named: 'documentId'),
          )).thenAnswer((_) async {});

      await expectLater(
        repo.addExpense(
          group: testGroup,
          createdBy: 'u1',
          description: 'Cena',
          amount: 300,
          paidBy: 'm1',
          shares: {'m1': 100, 'm2': 100, 'm3': 100},
          splitType: 'equal',
        ),
        throwsA(isA<AppwriteException>()),
      );

      // Partes (2 intentadas, la 2ª pudo quedar a medias) y luego el gasto.
      verify(() => db.deleteDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.splitsCollection,
            documentId: any(named: 'documentId'),
          )).called(2);
      verify(() => db.deleteDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.expensesCollection,
            documentId: any(named: 'documentId'),
          )).called(1);
    });

    test('un fallo en el rollback no tapa el error original', () async {
      var calls = 0;
      when(() => db.createDocument(
            databaseId: any(named: 'databaseId'),
            collectionId: any(named: 'collectionId'),
            documentId: any(named: 'documentId'),
            data: any(named: 'data'),
            permissions: any(named: 'permissions'),
          )).thenAnswer((_) async {
        if (++calls == 2) throw AppwriteException('sin permiso', 403);
        return makeDoc('x', {});
      });
      when(() => db.deleteDocument(
            databaseId: any(named: 'databaseId'),
            collectionId: any(named: 'collectionId'),
            documentId: any(named: 'documentId'),
          )).thenThrow(AppwriteException('rollback falló', 500));

      await expectLater(
        repo.addExpense(
          group: testGroup,
          createdBy: 'u1',
          description: 'Cena',
          amount: 100,
          paidBy: 'm1',
          shares: {'m1': 100},
          splitType: 'equal',
        ),
        throwsA(isA<AppwriteException>()
            .having((e) => e.code, 'code', 403)),
      );
    });
  });

  group('addSettlement', () {
    test('crea el pago con los permisos del grupo', () async {
      stubCreate();

      await repo.addSettlement(
        group: testGroup,
        createdBy: 'u1',
        fromMember: 'm2',
        toMember: 'm1',
        amount: 700,
      );

      final call = verify(() => db.createDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.settlementsCollection,
            documentId: any(named: 'documentId'),
            data: captureAny(named: 'data'),
            permissions: captureAny(named: 'permissions'),
          )).captured;
      expect(call[0], {
        'groupId': 'g1',
        'fromMember': 'm2',
        'toMember': 'm1',
        'amount': 700,
        'createdBy': 'u1',
      });
      expect(call[1], contains(Permission.read(Role.team('t1'))));
    });
  });

  group('deleteExpense', () {
    test('borra primero las partes y al final el gasto', () async {
      when(() => db.deleteDocument(
            databaseId: any(named: 'databaseId'),
            collectionId: any(named: 'collectionId'),
            documentId: any(named: 'documentId'),
          )).thenAnswer((_) async {});

      await repo.deleteExpense(expenseId: 'e1', splitIds: ['s1', 's2']);

      verifyInOrder([
        () => db.deleteDocument(
              databaseId: AppwriteConstants.databaseId,
              collectionId: AppwriteConstants.splitsCollection,
              documentId: 's1',
            ),
        () => db.deleteDocument(
              databaseId: AppwriteConstants.databaseId,
              collectionId: AppwriteConstants.splitsCollection,
              documentId: 's2',
            ),
        () => db.deleteDocument(
              databaseId: AppwriteConstants.databaseId,
              collectionId: AppwriteConstants.expensesCollection,
              documentId: 'e1',
            ),
      ]);
    });
  });

  group('deleteExpense idempotente', () {
    test('un 404 en una parte no corta el borrado', () async {
      when(() => db.deleteDocument(
            databaseId: any(named: 'databaseId'),
            collectionId: AppwriteConstants.splitsCollection,
            documentId: 's1',
          )).thenThrow(AppwriteException('no existe', 404));
      when(() => db.deleteDocument(
            databaseId: any(named: 'databaseId'),
            collectionId: any(named: 'collectionId'),
            documentId: any(named: 'documentId', that: isNot('s1')),
          )).thenAnswer((_) async {});

      await repo.deleteExpense(expenseId: 'e1', splitIds: ['s1', 's2']);

      verify(() => db.deleteDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.expensesCollection,
            documentId: 'e1',
          )).called(1);
    });
  });

  group('providers', () {
    test('expensesProvider, splitsProvider y settlementsProvider cargan', () async {
      stubList([]);
      final container = ProviderContainer(
        overrides: [databasesProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      expect(await container.read(expensesProvider('g1').future), isEmpty);
      expect(await container.read(splitsProvider('g1').future), isEmpty);
      expect(await container.read(settlementsProvider('g1').future), isEmpty);
    });
  });
}
