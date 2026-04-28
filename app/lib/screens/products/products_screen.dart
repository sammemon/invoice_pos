import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/product_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/product_model.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});
  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(productProvider.notifier).fetchFromServer());
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products & Inventory'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.read(productProvider.notifier).fetchFromServer()),
          IconButton(icon: const Icon(Icons.add_rounded),
              onPressed: () => context.go('/products/add')),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Search by name, barcode, SKU...',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => ref.read(productProvider.notifier).search(v),
          ),
        ),
        _CategoryFilter(),
        Expanded(
          child: state.isLoading && state.products.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : state.filtered.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No products found', style: TextStyle(color: Colors.grey)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: state.filtered.length,
                  itemBuilder: (_, i) => _ProductTile(product: state.filtered[i]),
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/products/add'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _CategoryFilter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productProvider);
    final cats = state.products.map((p) => p.category).toSet().toList()..sort();

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _FilterChip(label: 'All', selected: state.selectedCategory == null,
              onTap: () => ref.read(productProvider.notifier).filterCategory(null)),
          ...cats.map((c) => _FilterChip(label: c, selected: state.selectedCategory == c,
              onTap: () => ref.read(productProvider.notifier).filterCategory(c))),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w500)),
      ),
    ),
  );
}

class _ProductTile extends ConsumerWidget {
  final ProductModel product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = product.stockStatus == 'in_stock' ? AppTheme.success
        : product.stockStatus == 'low_stock' ? AppTheme.warning : AppTheme.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withAlpha(20),
          child: Text(product.name[0].toUpperCase(),
              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
        ),
        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(product.category, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 2),
          Row(children: [
            Text('Buy: ${Helpers.formatCurrency(product.purchasePrice)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(width: 8),
            Text('Sell: ${Helpers.formatCurrency(product.sellingPrice)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500)),
          ]),
        ]),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withAlpha(20), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor, width: 1)),
            child: Text('${product.quantity} ${product.unit}',
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
        onTap: () => context.go('/products/edit/${product.id}'),
      ),
    );
  }
}
