import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/appwrite/appwrite_constants.dart';
import '../../../core/appwrite/appwrite_providers.dart';
import '../../../core/utils/retry.dart';
import '../../groups/domain/group.dart';
import '../domain/expense.dart';
import '../domain/settlement.dart';

class ExpensesRepository {
  ExpensesRepository(
    this._databases, {
    this.retryDelay = const Duration(milliseconds: 300),
  });
  final Databases _databases;

  /// Espera base del backoff entre reintentos (se baja a cero en tests).
  final Duration retryDelay;

  /// Crea un documento con retry idempotente; ver [retryCreate].
  Future<void> _create(
    String collectionId,
    String id,
    Map<String, dynamic> data,
    List<String> permissions,
  ) {
    return retryCreate<Object>(
      baseDelay: retryDelay,
      create: () => _databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: collectionId,
        documentId: id,
        data: data,
        permissions: permissions,
      ),
      fetch: () => _databases.getDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: collectionId,
        documentId: id,
      ),
    );
  }

  Future<void> _delete(String collectionId, String id) {
    return retryDelete(
      baseDelay: retryDelay,
      () => _databases.deleteDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: collectionId,
        documentId: id,
      ),
    );
  }

  // OJO: Appwrite devuelve 25 filas por defecto, por eso el limit explícito.
  // Cuando haya grupos con más de 100 gastos, habrá que paginar.
  Future<List<Expense>> listExpenses(String groupId) async {
    final res = await _databases.listDocuments(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.expensesCollection,
      queries: [
        Query.equal('groupId', groupId),
        Query.orderDesc(r'$createdAt'),
        Query.limit(100),
      ],
    );
    return res.documents.map(Expense.fromDocument).toList();
  }

  Future<List<ExpenseSplit>> listSplits(String groupId) async {
    final res = await _databases.listDocuments(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.splitsCollection,
      queries: [
        Query.equal('groupId', groupId),
        Query.limit(500),
      ],
    );
    return res.documents.map(ExpenseSplit.fromDocument).toList();
  }

  Future<void> addExpense({
    required Group group,
    required String createdBy,
    required String description,
    required int amount,
    required String paidBy,
    required Map<String, int> shares,
    required String splitType,
  }) async {
    final permissions = [
      Permission.read(Role.team(group.teamId)),
      Permission.update(Role.user(createdBy)),
      Permission.delete(Role.user(createdBy)),
      Permission.update(Role.team(group.teamId, 'owner')),
      Permission.delete(Role.team(group.teamId, 'owner')),
    ];

    // IDs generados antes de escribir: hacen seguros los reintentos y
    // permiten deshacer lo creado si algo falla a medias.
    final expenseId = ID.unique();
    final splitIds = <String>[];

    try {
      await _create(
        AppwriteConstants.expensesCollection,
        expenseId,
        {
          'groupId': group.id,
          'description': description,
          'amount': amount,
          'paidBy': paidBy,
          'splitType': splitType,
          'createdBy': createdBy,
        },
        permissions,
      );

      for (final entry in shares.entries) {
        final splitId = ID.unique();
        splitIds.add(splitId);
        await _create(
          AppwriteConstants.splitsCollection,
          splitId,
          {
            'expenseId': expenseId,
            'groupId': group.id,
            'memberId': entry.key,
            'share': entry.value,
          },
          permissions,
        );
      }
    } catch (_) {
      // Rollback: un gasto sin todas sus partes dejaría los saldos mal.
      for (final id in splitIds.reversed) {
        await bestEffort(() => _delete(AppwriteConstants.splitsCollection, id));
      }
      await bestEffort(
          () => _delete(AppwriteConstants.expensesCollection, expenseId));
      rethrow;
    }
  }

  Future<List<Settlement>> listSettlements(String groupId) async {
    final res = await _databases.listDocuments(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.settlementsCollection,
      queries: [
        Query.equal('groupId', groupId),
        Query.orderDesc(r'$createdAt'),
        Query.limit(100),
      ],
    );
    return res.documents.map(Settlement.fromDocument).toList();
  }

  Future<void> addSettlement({
    required Group group,
    required String createdBy,
    required String fromMember,
    required String toMember,
    required int amount,
  }) async {
    await _create(
      AppwriteConstants.settlementsCollection,
      ID.unique(),
      {
        'groupId': group.id,
        'fromMember': fromMember,
        'toMember': toMember,
        'amount': amount,
        'createdBy': createdBy,
      },
      [
        Permission.read(Role.team(group.teamId)),
        Permission.update(Role.user(createdBy)),
        Permission.delete(Role.user(createdBy)),
        Permission.update(Role.team(group.teamId, 'owner')),
        Permission.delete(Role.team(group.teamId, 'owner')),
      ],
    );
  }

  /// Borra primero las partes y al final el gasto. Un borrado no se puede
  /// deshacer, pero cada paso es idempotente (404 = ya borrado): si falla a
  /// medias, repetir la llamada con los mismos IDs lo completa.
  Future<void> deleteExpense({
    required String expenseId,
    required List<String> splitIds,
  }) async {
    for (final id in splitIds) {
      await _delete(AppwriteConstants.splitsCollection, id);
    }
    await _delete(AppwriteConstants.expensesCollection, expenseId);
  }
}

final expensesRepositoryProvider = Provider<ExpensesRepository>(
      (ref) => ExpensesRepository(ref.watch(databasesProvider)),
);

final expensesProvider =
FutureProvider.family<List<Expense>, String>((ref, groupId) {
  return ref.read(expensesRepositoryProvider).listExpenses(groupId);
});

final splitsProvider =
FutureProvider.family<List<ExpenseSplit>, String>((ref, groupId) {
  return ref.read(expensesRepositoryProvider).listSplits(groupId);
});

final settlementsProvider =
FutureProvider.family<List<Settlement>, String>((ref, groupId) {
  return ref.read(expensesRepositoryProvider).listSettlements(groupId);
});