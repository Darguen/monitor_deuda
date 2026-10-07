import 'package:appwrite/models.dart' as models;

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.currency,
    required this.createdBy,
    required this.teamId,
  });

  final String id;
  final String name;
  final String currency;
  final String createdBy;
  final String teamId;

  factory Group.fromDocument(models.Document doc) {
    return Group(
      id: doc.$id,
      name: doc.data['name'] as String,
      currency: doc.data['currency'] as String,
      createdBy: doc.data['createdBy'] as String,
      teamId: doc.data['teamId'] as String,
    );
  }
}