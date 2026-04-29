import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/product_provider.dart';
import '../../models/product_model.dart';

class AddPurchaseScreen extends ConsumerStatefulWidget {
  const AddPurchaseScreen({super.key});
  @override
  ConsumerState<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends ConsumerState<AddPurchaseScreen> {
  final List<Map<String, dynamic>> _items = [];
  bool _showSearch = false;
  String _search = '';
  String _selectedCategory = 'All';

  double get _total => _items.fold(0, (s, i) => s + i['total']);

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productProvider);
    final products = productsState.products;
    final categories = ['All', ...products.map((p) => p.category).toSet()];

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Add Purchase'),
      ),
      body: Column(children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: InkWell(
            onTap: () => setState(() => _showSearch = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300)),
              child: Row(children: [
                const Expanded(child: Text('Add Product By Name',
                    style: TextStyle(color: Colors.grey))),
                Icon(Icons.qr_code_scanner_rounded, color: Colors.grey.shade500),
              ]),
            ),
          ),
        ),

        // Added items
        Expanded(child: _items.isEmpty
            ? const SizedBox()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final item = _items[i];
                  return Card(
                    child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                      Row(children: [
                        Expanded(child: Text(item['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold))),
                        IconButton(icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => setState(() => _items.removeAt(i))),
                      ]),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Cost: PKR ${item['cost']}',
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        Text('Sale: PKR ${item['sale']}',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ]),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: item['qty'] > 1
                              ? () => setState(() {
                                    item['qty']--;
                                    item['total'] = item['qty'] * item['cost'];
                                  })
                              : null,
                        ),
                        Text('${item['qty']}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Colors.blue),
                          onPressed: () => setState(() {
                            item['qty']++;
                            item['total'] = item['qty'] * item['cost'];
                          }),
                        ),
                      ]),
                    ])),
                  );
                },
              )),
      ]),

      // Bottom bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.green,
        child: SafeArea(child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total Items: ${_items.length}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Total Purchase: PKR ${_total.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        )),
      ),

      // Product search dialog
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _showSearch
          ? null
          : FloatingActionButton(
              onPressed: () => _showProductDialog(products, categories),
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  void _showProductDialog(List<ProductModel> products, List<String> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: Column(children: [
            Padding(padding: const EdgeInsets.all(12), child: Row(children: [
              const Expanded(child: Text('Add Product',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => Navigator.pop(ctx)),
            ])),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                onChanged: (v) => setModal(() => _search = v),
                decoration: const InputDecoration(
                    hintText: 'Search Product Name', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(height: 40, child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: categories.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(categories[i]),
                  selected: _selectedCategory == categories[i],
                  onSelected: (_) => setModal(() => _selectedCategory = categories[i]),
                ),
              ),
            )),
            const SizedBox(height: 8),
            Expanded(child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
                  childAspectRatio: 0.75),
              itemCount: products.where((p) =>
                (_selectedCategory == 'All' || p.category == _selectedCategory) &&
                p.name.toLowerCase().contains(_search.toLowerCase())).length,
              itemBuilder: (_, i) {
                final filtered = products.where((p) =>
                  (_selectedCategory == 'All' || p.category == _selectedCategory) &&
                  p.name.toLowerCase().contains(_search.toLowerCase())).toList();
                final p = filtered[i];
                return InkWell(
                  onTap: () {
                    setState(() {
                      final existing = _items.indexWhere((x) => x['id'] == p.id);
                      if (existing >= 0) {
                        _items[existing]['qty']++;
                        _items[existing]['total'] =
                            _items[existing]['qty'] * _items[existing]['cost'];
                      } else {
                        _items.add({
                          'id': p.id, 'name': p.name,
                          'cost': p.purchasePrice, 'sale': p.sellingPrice,
                          'qty': 1, 'total': p.purchasePrice,
                        });
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.image_not_supported_outlined,
                          size: 32, color: Colors.grey),
                      const SizedBox(height: 4),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(p.name, textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            maxLines: 2, overflow: TextOverflow.ellipsis)),
                      Text('PKR ${p.sellingPrice.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 11, color: Colors.blue)),
                      Text('Available: ${p.quantity}',
                          style: TextStyle(fontSize: 10,
                              color: p.quantity > 0 ? Colors.green : Colors.red)),
                    ]),
                  ),
                );
              },
            )),
          ]),
        ),
      ),
    );
  }
}
