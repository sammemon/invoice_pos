import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';

final _categoriesProvider = FutureProvider<List<String>>((ref) async {
  final res = await ApiClient.instance.get('/products/categories');
  return List<String>.from(res.data['data'] ?? []);
});

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(_categoriesProvider);
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Product Categories'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: InkWell(
            onTap: () => _showAddDialog(context, ref),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300)),
              child: const Row(children: [
                Icon(Icons.add, color: Colors.grey),
                SizedBox(width: 12),
                Text('Add Product Categories',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
              ]),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Align(alignment: Alignment.centerLeft,
              child: Text('All Product Categories List',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        ),
        const SizedBox(height: 8),
        Expanded(child: cats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (list) => list.isEmpty
              ? const Center(child: Text('No categories yet'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: list.length,
                  itemBuilder: (_, i) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(list[i],
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: Colors.blue, size: 20),
                          onPressed: () => _showEditDialog(context, ref, list[i]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () {},
                        ),
                      ]),
                    ),
                  ),
                ),
        )),
      ]),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add Category'),
      content: TextField(controller: ctrl,
          decoration: const InputDecoration(hintText: 'Category name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () { Navigator.pop(ctx); ref.invalidate(_categoriesProvider); },
          child: const Text('Save'),
        ),
      ],
    ));
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Edit Category'),
      content: TextField(controller: ctrl),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () { Navigator.pop(ctx); ref.invalidate(_categoriesProvider); },
          child: const Text('Save'),
        ),
      ],
    ));
  }
}
