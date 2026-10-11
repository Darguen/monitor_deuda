import 'package:appwrite/models.dart' as models;
import 'package:mocktail/mocktail.dart';
import 'package:monitor_deuda/features/groups/domain/group.dart';
import 'package:monitor_deuda/features/groups/domain/member.dart';

class MockUser extends Mock implements models.User {}

class MockSession extends Mock implements models.Session {}

/// Arma un documento de Appwrite con los campos mínimos.
models.Document makeDoc(
  String id,
  Map<String, dynamic> data, {
  String createdAt = '2024-05-01T12:00:00.000+00:00',
}) {
  return models.Document(
    $id: id,
    $sequence: '1',
    $collectionId: 'col',
    $databaseId: 'db',
    $createdAt: createdAt,
    $updatedAt: createdAt,
    $permissions: const [],
    data: data,
  );
}

models.DocumentList makeDocList(List<models.Document> docs) =>
    models.DocumentList(total: docs.length, documents: docs);

MockUser makeUser({String id = 'u1', String name = 'Ana'}) {
  final user = MockUser();
  when(() => user.$id).thenReturn(id);
  when(() => user.name).thenReturn(name);
  return user;
}

const testGroup = Group(
  id: 'g1',
  name: 'Viaje',
  currency: 'CLP',
  createdBy: 'u1',
  teamId: 't1',
);

const testMembers = [
  Member(id: 'm1', groupId: 'g1', userId: 'u1', displayName: 'Ana', role: 'owner'),
  Member(id: 'm2', groupId: 'g1', displayName: 'Beto', role: 'member'),
];
