class ExpenseModel {
  final String id;
  final String? serverId;
  final String title;
  final String category;
  final double amount;
  final String? description;
  final String paymentMethod;
  final DateTime expenseDate;
  final bool isSynced;
  final String? syncId;

  const ExpenseModel({
    required this.id,
    this.serverId,
    required this.title,
    this.category = 'General',
    required this.amount,
    this.description,
    this.paymentMethod = 'cash',
    required this.expenseDate,
    this.isSynced = false,
    this.syncId,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> j) => ExpenseModel(
        id: j['_id'] ?? j['id'] ?? '',
        serverId: j['_id'],
        title: j['title'] ?? '',
        category: j['category'] ?? 'General',
        amount: (j['amount'] ?? 0).toDouble(),
        description: j['description'],
        paymentMethod: j['paymentMethod'] ?? 'cash',
        expenseDate: j['expenseDate'] != null ? DateTime.parse(j['expenseDate']) : DateTime.now(),
        isSynced: true,
      );

  factory ExpenseModel.fromMap(Map<String, dynamic> m) => ExpenseModel(
        id: m['id'] ?? '',
        serverId: m['serverId'],
        title: m['title'] ?? '',
        category: m['category'] ?? 'General',
        amount: (m['amount'] ?? 0).toDouble(),
        description: m['description'],
        paymentMethod: m['paymentMethod'] ?? 'cash',
        expenseDate: m['expenseDate'] != null ? DateTime.parse(m['expenseDate']) : DateTime.now(),
        isSynced: (m['isSynced'] ?? 0) == 1,
        syncId: m['id'],
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'serverId': serverId, 'title': title, 'category': category,
        'amount': amount, 'description': description,
        'paymentMethod': paymentMethod,
        'expenseDate': expenseDate.toIso8601String(),
        'isSynced': isSynced ? 1 : 0,
      };

  Map<String, dynamic> toJson() => {
        'title': title, 'category': category, 'amount': amount,
        'description': description, 'paymentMethod': paymentMethod,
        'expenseDate': expenseDate.toIso8601String(), 'syncId': syncId ?? id,
      };
}
