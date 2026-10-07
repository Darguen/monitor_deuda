import 'package:appwrite/models.dart' as models;

class Expense {
  const Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.createdAt,
  });

  final String id;
  final String groupId;
  final String description;
  final int amount;
  final String paidBy; // id del miembro que pagó
  final DateTime createdAt;

  factory Expense.fromDocument(models.Document doc) {
    return Expense(
      id: doc.$id,
      groupId: doc.data['groupId'] as String,
      description: doc.data['description'] as String,
      amount: doc.data['amount'] as int,
      paidBy: doc.data['paidBy'] as String,
      createdAt: DateTime.parse(doc.$createdAt).toLocal(),
    );
  }
}

class ExpenseSplit {
  const ExpenseSplit({
    required this.id,
    required this.expenseId,
    required this.memberId,
    required this.share,
  });

  final String id;
  final String expenseId;
  final String memberId;
  final int share;

  factory ExpenseSplit.fromDocument(models.Document doc) {
    return ExpenseSplit(
      id: doc.$id,
      expenseId: doc.data['expenseId'] as String,
      memberId: doc.data['memberId'] as String,
      share: doc.data['share'] as int,
    );
  }
}