import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/customer_provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/customer_model.dart';
import '../../models/sale_model.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});
  @override
  ConsumerState<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  List<SaleModel> _sales = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance.get('/customers/${widget.customerId}');
      final salesJson = res.data['sales'] as List? ?? [];
      setState(() {
        _sales = salesJson.map((j) => SaleModel.fromJson(j)).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = ref.watch(customerProvider).customers
        .where((c) => c.id == widget.customerId).firstOrNull;

    if (customer == null) return const Scaffold(body: Center(child: Text('Customer not found')));

    return Scaffold(
      appBar: AppBar(title: Text(customer.name),
          actions: [
            if (customer.currentBalance > 0)
              ElevatedButton.icon(
                onPressed: () => _settlePayment(context, customer),
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Settle'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white,
                    minimumSize: const Size(0, 36)),
              ),
          ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              // Profile card
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                CircleAvatar(radius: 32, backgroundColor: AppTheme.primary.withAlpha(20),
                    child: Text(customer.name[0].toUpperCase(),
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 24))),
                const SizedBox(height: 12),
                Text(customer.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (customer.phone != null) Text(customer.phone!, style: const TextStyle(color: Colors.grey)),
                if (customer.email != null) Text(customer.email!, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: customer.currentBalance > 0 ? AppTheme.error.withAlpha(15) : AppTheme.success.withAlpha(15),
                    borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    Text('Outstanding Balance', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Text(Helpers.formatCurrency(customer.currentBalance),
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                            color: customer.currentBalance > 0 ? AppTheme.error : AppTheme.success)),
                  ])),
              ]))),
              const SizedBox(height: 16),
              if (_sales.isNotEmpty) ...[
                Text('Purchase History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ..._sales.map((s) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(s.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(Helpers.formatDate(s.saleDate)),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(Helpers.formatCurrency(s.grandTotal),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: s.paymentStatus == 'paid' ? AppTheme.success : AppTheme.warning,
                          borderRadius: BorderRadius.circular(10)),
                        child: Text(s.paymentStatus, style: const TextStyle(color: Colors.white, fontSize: 10))),
                    ]),
                  ),
                )),
              ],
            ]),
    );
  }

  void _settlePayment(BuildContext context, CustomerModel customer) {
    final ctrl = TextEditingController(text: customer.currentBalance.toStringAsFixed(2));
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Record Payment'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Outstanding: ${Helpers.formatCurrency(customer.currentBalance)}',
            style: const TextStyle(color: AppTheme.error)),
        const SizedBox(height: 16),
        TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Amount'),
            keyboardType: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final amount = double.tryParse(ctrl.text) ?? 0;
            if (amount <= 0) return;
            await ApiClient.instance.post('/customers/${customer.id}/payment',
                data: {'amount': amount, 'paymentMethod': 'cash'});
            await ref.read(customerProvider.notifier).fetchFromServer();
            if (context.mounted) { Navigator.pop(context); _load(); }
          },
          child: const Text('Record'),
        ),
      ],
    ));
  }
}
