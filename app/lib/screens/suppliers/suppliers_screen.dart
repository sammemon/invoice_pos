import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/local_db.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/supplier_model.dart';

final _suppliersProvider = FutureProvider.autoDispose<List<SupplierModel>>((ref) async {
  try {
    final res = await ApiClient.instance.get('/suppliers');
    final list = (res.data['data'] as List).map((j) => SupplierModel.fromJson(j)).toList();
    final db = await LocalDb.db;
    final batch = db.batch();
    for (final s in list) { batch.insert('suppliers', s.toMap(), conflictAlgorithm: ConflictAlgorithm.replace); }
    await batch.commit(noResult: true);
    return list;
  } catch (_) {
    final db = await LocalDb.db;
    final rows = await db.query('suppliers', where: 'isActive = 1');
    return rows.map(SupplierModel.fromMap).toList();
  }
});

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(_suppliersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(_suppliersProvider)),
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => _showForm(context, ref)),
        ],
      ),
      body: suppliersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (suppliers) => suppliers.isEmpty
            ? const Center(child: Text('No suppliers yet', style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: suppliers.length,
                itemBuilder: (_, i) {
                  final s = suppliers[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: AppTheme.secondary.withAlpha(20),
                          child: Text(s.name[0].toUpperCase(), style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold))),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(s.phone ?? s.company ?? 'No contact'),
                      trailing: s.currentBalance > 0
                          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Text('Due', style: TextStyle(color: AppTheme.error, fontSize: 11)),
                              Text(Helpers.formatCurrency(s.currentBalance),
                                  style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
                            ])
                          : null,
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref) {
    final nameCtrl    = TextEditingController();
    final phoneCtrl   = TextEditingController();
    final companyCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Add Supplier', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Supplier Name *')),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextField(controller: companyCtrl, decoration: const InputDecoration(labelText: 'Company')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await ApiClient.instance.post('/suppliers', data: {
                  'name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim(), 'company': companyCtrl.text.trim(),
                });
                ref.invalidate(_suppliersProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save Supplier'),
            ),
          ]),
        ),
      ),
    );
  }
}
