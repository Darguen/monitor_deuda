import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/appwrite/appwrite_constants.dart';
import '../../../core/appwrite/appwrite_providers.dart';
import '../domain/group.dart';
import '../domain/member.dart';

class MembersRepository {
  MembersRepository(this._databases);
  final Databases _databases;

  Future<List<Member>> listMembers(String groupId) async {
    final res = await _databases.listDocuments(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.membersCollection,
      queries: [
        Query.equal('groupId', groupId),
        Query.orderAsc(r'$createdAt'),
        Query.limit(100),
      ],
    );
    return res.documents.map(Member.fromDocument).toList();
  }

  Future<void> addMember({
    required Group group,
    required String displayName,
  }) async {
    await _databases.createDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.membersCollection,
      documentId: ID.unique(),
      data: {
        'groupId': group.id,
        'displayName': displayName,
        'role': 'member',
      },
      permissions: [
        Permission.read(Role.team(group.teamId)),
        Permission.update(Role.team(group.teamId, 'owner')),
        Permission.delete(Role.team(group.teamId, 'owner')),
      ],
    );
  }
}

final membersRepositoryProvider = Provider<MembersRepository>(
      (ref) => MembersRepository(ref.watch(databasesProvider)),
);

/// Miembros de un grupo, por groupId.
final membersProvider =
FutureProvider.family<List<Member>, String>((ref, groupId) {
  return ref.read(membersRepositoryProvider).listMembers(groupId);
});