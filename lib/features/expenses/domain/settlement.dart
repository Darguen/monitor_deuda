import 'package:appwrite/models.dart' as models;

class Settlement {
  const Settlement({
    required this.id,
    required this.groupId,
    required this.fromMember,
    required this.toMember,
    required this.amount,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String fromMember; // quien pagó la deuda
  final String toMember; // quien recibió el pago
  final int amount;
  final DateTime createdAt;

  factory Settlement.fromDocument(models.Document doc) {
    return Settlement(
      id: doc.$id,
      groupId: doc.data['groupId'] as String,
      fromMember: doc.data['fromMember'] as String,
      toMember: doc.data['toMember'] as String,
      amount: doc.data['amount'] as int,
      createdAt: DateTime.parse(doc.$createdAt).toLocal(),
    );
  }
}