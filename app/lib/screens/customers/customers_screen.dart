import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/customer_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/customer_model.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});
  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(customerProvider.notifier).fetchFromServer());
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerProvider);
    final filtered = _search.isEmpty ? state.customers
        : state.customers.where((c) =>
            c.name.toLowerCase().contains(_search.toLowerCase()) ||
            (c.phone?.contains(_search) ?? false)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => _showForm(context, ref)),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(hintText: 'Search customers...', prefixIcon: Icon(Icons.search_rounded)),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: state.isLoading && state.customers.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
              ? const Center(child: Text('No customers found', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _CustomerTile(customer: filtered[i]),
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context, ref),
        child: const Icon(Icons.person_add_rounded),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref) {
    final nameCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addrCtrl  = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Add Customer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await ref.read(customerProvider.notifier).saveCustomer({
                  'name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim(), 'address': addrCtrl.text.trim(),
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save Customer'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  final CustomerModel customer;
  const _CustomerTile({required this.customer});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: CircleAvatar(backgroundColor: AppTheme.primary.withAlpha(20),
          child: Text(customer.name[0].toUpperCase(),
              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))),
      title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(customer.phone ?? customer.email ?? 'No contact'),
      trailing: customer.currentBalance > 0
          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Due', style: TextStyle(color: AppTheme.error, fontSize: 11)),
              Text(Helpers.formatCurrency(customer.currentBalance),
                  style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold, fontSize: 13)),
            ])
          : const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 20),
      onTap: () => context.go('/customers/${customer.id}'),
    ),
  );
}
