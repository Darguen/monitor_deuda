import 'package:appwrite/models.dart' as models;

class Member {
  const Member({
    required this.id,
    required this.groupId,
    required this.displayName,
    required this.role,
    this.userId,
  });

  final String id;
  final String groupId;
  final String? userId;
  final String displayName;
  final String role;

  /// Un miembro sin cuenta es alguien que no usa la app (ej. un amigo).
  bool get hasAccount => userId != null;

  factory Member.fromDocument(models.Document doc) {
    return Member(
      id: doc.$id,
      groupId: doc.data['groupId'] as String,
      userId: doc.data['userId'] as String?,
      displayName: doc.data['displayName'] as String,
      role: doc.data['role'] as String,
    );
  }
}