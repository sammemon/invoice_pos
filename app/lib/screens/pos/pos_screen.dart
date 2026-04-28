import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/customer_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/product_model.dart';
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});
  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchCtrl = TextEditingController();
  final _paidCtrl   = TextEditingController();
  bool _scanning    = false;
  bool _processing  = false;

  @override
  void dispose() { _searchCtrl.dispose(); _paidCtrl.dispose(); super.dispose(); }

  void _addProduct(ProductModel p) {
    ref.read(posProvider.notifier).addToCart(p);
    _searchCtrl.clear();
    ref.read(productProvider.notifier).search('');
  }

  Future<void> _checkout() async {
    final pos = ref.read(posProvider);
    if (pos.cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart is empty')));
      return;
    }
    final paid = double.tryParse(_paidCtrl.text) ?? pos.grandTotal;
    setState(() => _processing = true);
    try {
      final sale = await ref.read(saleProvider.notifier).createSale(pos, paid);
      ref.read(posProvider.notifier).clearCart();
      _paidCtrl.clear();
      if (!mounted) return;
      final invoiceId = sale?.id ?? 'offline';
      context.go('/invoice/$invoiceId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos    = ref.watch(posProvider);
    final isWide = MediaQuery.of(context).size.width >= 720;

    if (isWide) {
      return Scaffold(
        appBar: AppBar(title: const Text('Point of Sale')),
        body: Row(children: [
          Expanded(flex: 3, child: _ProductPanel(
            searchCtrl: _searchCtrl, scanning: _scanning,
            onScanToggle: () => setState(() => _scanning = !_scanning),
            onAdd: _addProduct,
          )),
          const VerticalDivider(width: 1),
          Expanded(flex: 2, child: _CartPanel(pos: pos, paidCtrl: _paidCtrl,
              processing: _processing, onCheckout: _checkout)),
        ]),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Point of Sale'),
          bottom: const TabBar(tabs: [Tab(text: 'Products'), Tab(text: 'Cart')]),
        ),
        body: TabBarView(children: [
          _ProductPanel(searchCtrl: _searchCtrl, scanning: _scanning,
              onScanToggle: () => setState(() => _scanning = !_scanning), onAdd: _addProduct),
          _CartPanel(pos: pos, paidCtrl: _paidCtrl, processing: _processing, onCheckout: _checkout),
        ]),
      ),
    );
  }
}

// ─── Product Search Panel ─────────────────────────────────
class _ProductPanel extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final bool scanning;
  final VoidCallback onScanToggle;
  final void Function(ProductModel) onAdd;

  const _ProductPanel({required this.searchCtrl, required this.scanning,
      required this.onScanToggle, required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productProvider).filtered
        .where((p) => p.isActive && p.quantity > 0).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: TextField(
            controller: searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Search product...', prefixIcon: Icon(Icons.search_rounded),
              isDense: true, border: OutlineInputBorder(),
            ),
            onChanged: (v) => ref.read(productProvider.notifier).search(v),
          )),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onScanToggle,
            icon: Icon(scanning ? Icons.close : Icons.qr_code_scanner_rounded),
            style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
        ]),
      ),
      if (scanning) SizedBox(height: 180, child: MobileScanner(
        onDetect: (capture) {
          final code = capture.barcodes.firstOrNull?.rawValue;
          if (code != null) {
            final p = ref.read(productProvider).products
                .where((pr) => pr.barcode == code).firstOrNull;
            if (p != null) onAdd(p);
          }
        },
      )),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180, childAspectRatio: 1.1, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: products.length,
          itemBuilder: (_, i) => _ProductCard(product: products[i], onTap: () => onAdd(products[i])),
        ),
      ),
    ]);
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 18, backgroundColor: AppTheme.primary.withAlpha(20),
              child: Text(product.name[0].toUpperCase(),
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 14))),
          const Spacer(),
          Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(Helpers.formatCurrency(product.sellingPrice),
              style: const TextStyle(fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.bold)),
          Text('Stock: ${product.quantity}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      ),
    ),
  );
}

// ─── Cart Panel ───────────────────────────────────────────
class _CartPanel extends ConsumerWidget {
  final PosState pos;
  final TextEditingController paidCtrl;
  final bool processing;
  final VoidCallback onCheckout;

  const _CartPanel({required this.pos, required this.paidCtrl,
      required this.processing, required this.onCheckout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(posProvider.notifier);

    return Column(children: [
      // Customer selector
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: InkWell(
          onTap: () => _selectCustomer(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300)),
            child: Row(children: [
              const Icon(Icons.person_outline, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(child: Text(pos.customerName ?? 'Walk-in Customer',
                  style: TextStyle(color: pos.customerId == null ? Colors.grey : Colors.black87,
                      fontSize: 13))),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ]),
          ),
        ),
      ),

      // Cart items
      Expanded(
        child: pos.cart.isEmpty
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 8),
                Text('Cart is empty', style: TextStyle(color: Colors.grey)),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: pos.cart.length,
                itemBuilder: (_, i) => _CartItemTile(item: pos.cart[i], notifier: notifier),
              ),
      ),

      // Summary & checkout
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Divider(),
          _SummaryRow('Subtotal', Helpers.formatCurrency(pos.subTotal)),
          if (pos.discountAmount > 0)
            _SummaryRow('Discount', '- ${Helpers.formatCurrency(pos.discountAmount)}', red: true),
          if (pos.taxAmount > 0)
            _SummaryRow('Tax', '+ ${Helpers.formatCurrency(pos.taxAmount)}'),
          const Divider(),
          _SummaryRow('Total', Helpers.formatCurrency(pos.grandTotal), bold: true),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(
              controller: paidCtrl,
              decoration: InputDecoration(
                labelText: 'Paid Amount',
                prefixText: '${Helpers.formatCurrency(0).substring(0, 1)} ',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            )),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: pos.paymentMethod,
              items: const [
                DropdownMenuItem(value: 'cash',  child: Text('Cash')),
                DropdownMenuItem(value: 'card',  child: Text('Card')),
                DropdownMenuItem(value: 'bank',  child: Text('Bank')),
                DropdownMenuItem(value: 'credit',child: Text('Credit')),
              ],
              onChanged: (v) => notifier.setPaymentMethod(v!),
            ),
          ]),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: processing ? null : onCheckout,
            icon: processing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(processing ? 'Processing...' : 'Complete Sale'),
          ),
          if (pos.cart.isNotEmpty) TextButton(
            onPressed: () => notifier.clearCart(),
            child: const Text('Clear Cart', style: TextStyle(color: Colors.red)),
          ),
        ]),
      ),
    ]);
  }

  void _selectCustomer(BuildContext context, WidgetRef ref) {
    final customers = ref.read(customerProvider).customers;
    showModalBottomSheet(context: context, builder: (_) => _CustomerPicker(
      customers: customers,
      onSelected: (id, name) {
        ref.read(posProvider.notifier).setCustomer(id, name);
        Navigator.pop(context);
      },
    ));
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final PosNotifier notifier;
  const _CartItemTile({required this.item, required this.notifier});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(Helpers.formatCurrency(item.sellingPrice), style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
        ])),
        Row(children: [
          IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: () => notifier.updateQuantity(item.product.id, item.quantity - 1),
              padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold))),
          IconButton(icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: () => notifier.updateQuantity(item.product.id, item.quantity + 1),
              padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          const SizedBox(width: 8),
          Text(Helpers.formatCurrency(item.total),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.red),
              onPressed: () => notifier.removeFromCart(item.product.id),
              padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ]),
      ]),
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool bold, red;
  const _SummaryRow(this.label, this.value, {this.bold = false, this.red = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 13)),
      Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontSize: bold ? 16 : 13, color: red ? AppTheme.error : null)),
    ]),
  );
}

class _CustomerPicker extends StatelessWidget {
  final List customers;
  final void Function(String, String) onSelected;
  const _CustomerPicker({required this.customers, required this.onSelected});

  @override
  Widget build(BuildContext context) => Column(children: [
    const Padding(padding: EdgeInsets.all(16), child: Text('Select Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
    ListTile(leading: const Icon(Icons.person_outline), title: const Text('Walk-in Customer'),
        onTap: () { onSelected('', 'Walk-in Customer'); }),
    ...customers.map((c) => ListTile(
      leading: CircleAvatar(child: Text(c.name[0])),
      title: Text(c.name),
      subtitle: Text(c.phone ?? ''),
      trailing: c.currentBalance > 0
          ? Text('Due: ${Helpers.formatCurrency(c.currentBalance)}', style: const TextStyle(color: AppTheme.error, fontSize: 12))
          : null,
      onTap: () => onSelected(c.id, c.name),
    )),
  ]);
}
