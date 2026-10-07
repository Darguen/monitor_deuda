import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/appwrite/appwrite_constants.dart';
import '../../../core/appwrite/appwrite_providers.dart';
import '../domain/group.dart';

class GroupsRepository {
  GroupsRepository(this._account, this._teams, this._databases);

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

    // Quien crea el team queda automáticamente con el rol "owner".
    final team = await _teams.create(teamId: ID.unique(), name: name);

    final permissions = [
      Permission.read(Role.team(team.$id)),
      Permission.update(Role.team(team.$id, 'owner')),
      Permission.delete(Role.team(team.$id, 'owner')),
    ];

    final groupDoc = await _databases.createDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.groupsCollection,
      documentId: ID.unique(),
      data: {
        'name': name,
        'currency': currency,
        'createdBy': user.$id,
        'teamId': team.$id,
      },
      permissions: permissions,
    );

    await _databases.createDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.membersCollection,
      documentId: ID.unique(),
      data: {
        'groupId': groupDoc.$id,
        'userId': user.$id,
        'displayName': user.name,
        'role': 'owner',
      },
      permissions: permissions,
    );

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