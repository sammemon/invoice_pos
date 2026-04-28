import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/local_db.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/expense_model.dart';

final _expensesProvider = FutureProvider.autoDispose<List<ExpenseModel>>((ref) async {
  try {
    final res = await ApiClient.instance.get('/expenses', params: {'limit': '100'});
    return (res.data['data'] as List).map((j) => ExpenseModel.fromJson(j)).toList();
  } catch (_) {
    final db = await LocalDb.db;
    final rows = await db.query('expenses', orderBy: 'expenseDate DESC', limit: 100);
    return rows.map(ExpenseModel.fromMap).toList();
  }
});

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(_expensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(_expensesProvider)),
        ],
      ),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (expenses) {
          final total = expenses.fold(0.0, (s, e) => s + e.amount);
          return Column(children: [
            // Total card
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.error, Color(0xFFEF5350)]),
                borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Total Expenses', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(Helpers.formatCurrency(total),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                ]),
                const Icon(Icons.account_balance_wallet_rounded, color: Colors.white54, size: 40),
              ]),
            ),
            Expanded(
              child: expenses.isEmpty
                  ? const Center(child: Text('No expenses yet', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: expenses.length,
                      itemBuilder: (_, i) {
                        final e = expenses[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: AppTheme.error.withAlpha(20),
                                child: const Icon(Icons.receipt_outlined, color: AppTheme.error, size: 20)),
                            title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('${e.category} • ${Helpers.formatDate(e.expenseDate)}'),
                            trailing: Text(Helpers.formatCurrency(e.amount),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error, fontSize: 15)),
                          ),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addExpense(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _addExpense(BuildContext context, WidgetRef ref) {
    final titleCtrl    = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'General');
    final amountCtrl   = TextEditingController();
    final notesCtrl    = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Add Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title *')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Category'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount *'), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 12),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty) return;
                final expense = ExpenseModel(
                  id: Helpers.generateId(),
                  title: titleCtrl.text.trim(),
                  category: categoryCtrl.text.trim(),
                  amount: double.parse(amountCtrl.text),
                  description: notesCtrl.text.trim(),
                  expenseDate: DateTime.now(),
                );
                // Save locally
                final db = await LocalDb.db;
                await db.insert('expenses', expense.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
                // Try server
                try {
                  await ApiClient.instance.post('/expenses', data: expense.toJson());
                  await db.update('expenses', {'isSynced': 1}, where: 'id = ?', whereArgs: [expense.id]);
                } catch (_) {}
                ref.invalidate(_expensesProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save Expense'),
            ),
          ]),
        ),
      ),
    );
  }
}
