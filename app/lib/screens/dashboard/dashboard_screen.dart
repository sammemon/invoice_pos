import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/dashboard_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashState = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        title: const Text('You\'re a Premium Member',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: Colors.amber, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 22),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.read(dashboardProvider.notifier).fetch(),
        child: dashState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (model) => _DashboardBody(model: model),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final DashboardModel model;
  const _DashboardBody({required this.model});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      // ── Period cards ───────────────────────────────────────
      Row(children: [
        Expanded(child: _PeriodCard(label: 'Yesterday',
            sales: 0, profit: 0)),
        const SizedBox(width: 8),
        Expanded(child: _PeriodCard(label: 'Last 7 Days',
            sales: model.monthSales, profit: model.monthProfit)),
        const SizedBox(width: 8),
        Expanded(child: _PeriodCard(label: 'This Month',
            sales: model.monthSales, profit: model.monthProfit)),
      ]),
      const SizedBox(height: 8),

      // ── Today card ─────────────────────────────────────────
      Card(child: Padding(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Today so far',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Builder(builder: (ctx) => ElevatedButton.icon(
              onPressed: () => ctx.go('/pos'),
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('Add New Sale', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total Sales',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('PKR ${Helpers.formatAmount(model.todaySales)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(width: 40),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total Profit',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('PKR ${Helpers.formatAmount(model.todayProfit)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
            ]),
          ]),
        ]),
      )),
      const SizedBox(height: 8),

      // ── Stock value cards ──────────────────────────────────
      Row(children: [
        Expanded(child: _StockValueCard(label: 'Total Stock\nValue (No Profit)',
            value: 0, color: const Color(0xFF1A2A4A))),
        const SizedBox(width: 8),
        Expanded(child: _StockValueCard(label: 'Total Stock\nValue (With Profit)',
            value: 0, color: const Color(0xFF6A0DAD))),
        const SizedBox(width: 8),
        Expanded(child: _StockValueCard(label: 'Total Stock\nValue (WholeSale)',
            value: 0, color: Colors.grey.shade700)),
      ]),
      const SizedBox(height: 8),

      // ── Count cards ────────────────────────────────────────
      Row(children: [
        Expanded(child: _CountCard(label: 'Total Stock\nProducts',
            value: 0, color: Colors.blue.shade700)),
        const SizedBox(width: 8),
        Expanded(child: _CountCard(label: 'In Stock\nProducts',
            value: 0, color: Colors.green)),
        const SizedBox(width: 8),
        Expanded(child: _CountCard(label: 'Out of Stock\nProducts',
            value: 0, color: Colors.red)),
      ]),
      const SizedBox(height: 8),

      Row(children: [
        Expanded(child: _CountCard(label: 'Low In Stock\nProducts',
            value: model.lowStockCount, color: Colors.orange)),
        const SizedBox(width: 8),
        Expanded(child: _CountCard(label: 'Expire Stock\nProducts',
            value: 0, color: Colors.black87)),
        const SizedBox(width: 8),
        Expanded(child: _CountCard(label: 'Pending\nPayments',
            value: model.pendingCustomers, color: Colors.purple)),
      ]),
      const SizedBox(height: 16),
    ]);
  }
}

// ── Reusable small widgets ────────────────────────────────

class _PeriodCard extends StatelessWidget {
  final String label;
  final double sales, profit;
  const _PeriodCard({required this.label, required this.sales, required this.profit});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        const Text('Total Sales', style: TextStyle(fontSize: 10, color: Colors.grey)),
        Text('PKR ${Helpers.formatAmount(sales)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const Text('Total Profit', style: TextStyle(fontSize: 10, color: Colors.grey)),
        Text('PKR ${Helpers.formatAmount(profit)}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
      ]),
    ),
  );
}

class _StockValueCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _StockValueCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 10),
          textAlign: TextAlign.center),
      const SizedBox(height: 4),
      const Text('PKR', style: TextStyle(color: Colors.white70, fontSize: 10)),
      Text(Helpers.formatAmount(value),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    ]),
  );
}

class _CountCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _CountCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 10),
          textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text('$value',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
    ]),
  );
}

// ── Global App Drawer ─────────────────────────────────────

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    return Drawer(
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppTheme.primary, Color(0xFF1565C0)])),
          child: Column(children: [
            Stack(children: [
              const CircleAvatar(radius: 40, backgroundColor: Colors.white24,
                  child: Icon(Icons.person_rounded, size: 48, color: Colors.white)),
              Positioned(bottom: 0, right: 0,
                  child: Container(padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                    child: const Icon(Icons.workspace_premium_rounded, size: 16, color: Colors.white))),
            ]),
            const SizedBox(height: 10),
            const Text('Welcome', style: TextStyle(color: Colors.white70, fontSize: 13)),
            Text(user?.name ?? 'User',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(user?.email ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        Expanded(child: ListView(padding: EdgeInsets.zero, children: [
          _DTile(Icons.point_of_sale_rounded, 'Switch to POS',
              () { Navigator.pop(context); context.go('/pos'); }),
          _DTile(Icons.bar_chart_rounded, 'Profit Loss',
              () { Navigator.pop(context); context.go('/reports'); }),
          _DTile(Icons.inventory_2_rounded, 'Stock Management',
              () { Navigator.pop(context); context.go('/products'); }),
          _DTile(Icons.attach_money_rounded, 'Expense Management',
              () { Navigator.pop(context); context.go('/expenses'); }),
          _DTile(Icons.category_rounded, 'Product Categories',
              () { Navigator.pop(context); context.go('/categories'); }),
          _DTile(Icons.people_rounded, 'Customers',
              () { Navigator.pop(context); context.go('/customers'); }),
          _DTile(Icons.local_shipping_rounded, 'Suppliers',
              () { Navigator.pop(context); context.go('/suppliers'); }),
          _DTile(Icons.shopping_cart_rounded, 'Add Purchasing',
              () { Navigator.pop(context); context.go('/purchases/add'); }),
          const Divider(),
          _DTile(Icons.logout_rounded, 'Logout',
              () async {
                Navigator.pop(context);
                await ref.read(authProvider.notifier).logout();
              }, color: Colors.red),
        ])),
      ]),
    );
  }
}

class _DTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _DTile(this.icon, this.label, this.onTap, {this.color});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color ?? AppTheme.primary),
    title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
    onTap: onTap,
  );
}
