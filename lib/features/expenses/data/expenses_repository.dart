import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/appwrite/appwrite_constants.dart';
import '../../../core/appwrite/appwrite_providers.dart';
import '../../groups/domain/group.dart';
import '../domain/expense.dart';
import '../domain/settlement.dart';

class ExpensesRepository {
  ExpensesRepository(this._databases);
  final Databases _databases;

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

    final expense = await _databases.createDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.expensesCollection,
      documentId: ID.unique(),
      data: {
        'groupId': group.id,
        'description': description,
        'amount': amount,
        'paidBy': paidBy,
        'splitType': splitType,
        'createdBy': createdBy,
      },
      permissions: permissions,
    );

    for (final entry in shares.entries) {
      await _databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.splitsCollection,
        documentId: ID.unique(),
        data: {
          'expenseId': expense.$id,
          'groupId': group.id,
          'memberId': entry.key,
          'share': entry.value,
        },
        permissions: permissions,
      );
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
    await _databases.createDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.settlementsCollection,
      documentId: ID.unique(),
      data: {
        'groupId': group.id,
        'fromMember': fromMember,
        'toMember': toMember,
        'amount': amount,
        'createdBy': createdBy,
      },
      permissions: [
        Permission.read(Role.team(group.teamId)),
        Permission.update(Role.user(createdBy)),
        Permission.delete(Role.user(createdBy)),
        Permission.update(Role.team(group.teamId, 'owner')),
        Permission.delete(Role.team(group.teamId, 'owner')),
      ],
    );
  }

  /// Borra primero las partes y al final el gasto.
  Future<void> deleteExpense({
    required String expenseId,
    required List<String> splitIds,
  }) async {
    for (final id in splitIds) {
      await _databases.deleteDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.splitsCollection,
        documentId: id,
      );
    }
    await _databases.deleteDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.expensesCollection,
      documentId: expenseId,
    );
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