import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/appwrite/appwrite_constants.dart';
import '../../../core/appwrite/appwrite_providers.dart';
import '../../../core/utils/retry.dart';
import '../domain/group.dart';

class GroupsRepository {
  GroupsRepository(
    this._account,
    this._teams,
    this._databases, {
    this.retryDelay = const Duration(milliseconds: 300),
  });

  /// Espera base del backoff entre reintentos (se baja a cero en tests).
  final Duration retryDelay;

  final Account _account;
  final Teams _teams;
  final Databases _databases;

  /// Appwrite devuelve solo los documentos que el usuario puede leer,
  /// así que no hace falta filtrar por usuario.
  Future<List<Group>> listGroups() async {
    final res = await _databases.listDocuments(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.groupsCollection,
      queries: [Query.orderDesc(r'$createdAt')],
    );
    return res.documents.map(Group.fromDocument).toList();
  }

  Future<Group> createGroup({
    required String name,
    String currency = 'CLP',
  }) async {
    final user = await _account.get();

    // IDs generados antes de escribir: reintentos seguros y rollback posible.
    final teamId = ID.unique();
    final groupId = ID.unique();
    final memberId = ID.unique();

    Future<void> del(String collection, String id) => retryDelete(
          baseDelay: retryDelay,
          () => _databases.deleteDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: collection,
            documentId: id,
          ),
        );

    final models.Document groupDoc;
    try {
      // Quien crea el team queda automáticamente con el rol "owner".
      await retryCreate<Object>(
        baseDelay: retryDelay,
        create: () => _teams.create(teamId: teamId, name: name),
        fetch: () => _teams.get(teamId: teamId),
      );

      final permissions = [
        Permission.read(Role.team(teamId)),
        Permission.update(Role.team(teamId, 'owner')),
        Permission.delete(Role.team(teamId, 'owner')),
      ];

      groupDoc = await retryCreate<models.Document>(
        baseDelay: retryDelay,
        create: () => _databases.createDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.groupsCollection,
          documentId: groupId,
          data: {
            'name': name,
            'currency': currency,
            'createdBy': user.$id,
            'teamId': teamId,
          },
          permissions: permissions,
        ),
        fetch: () => _databases.getDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.groupsCollection,
          documentId: groupId,
        ),
      );

      await retryCreate<Object>(
        baseDelay: retryDelay,
        create: () => _databases.createDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.membersCollection,
          documentId: memberId,
          data: {
            'groupId': groupId,
            'userId': user.$id,
            'displayName': user.name,
            'role': 'owner',
          },
          permissions: permissions,
        ),
        fetch: () => _databases.getDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.membersCollection,
          documentId: memberId,
        ),
      );
    } catch (_) {
      // Rollback en orden inverso, sin tapar el error original. Se intenta
      // borrar todo: si un create falló sin respuesta pudo haber quedado
      // creado, y el 404 de lo que no existe se ignora.
      await bestEffort(() => del(AppwriteConstants.membersCollection, memberId));
      await bestEffort(() => del(AppwriteConstants.groupsCollection, groupId));
      await bestEffort(() => retryDelete(
            baseDelay: retryDelay,
            () => _teams.delete(teamId: teamId),
          ));
      rethrow;
    }

    return Group.fromDocument(groupDoc);
  }
}

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(
    ref.watch(accountProvider),
    ref.watch(teamsProvider),
    ref.watch(databasesProvider),
  );
});