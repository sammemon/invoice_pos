import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/dashboard_model.dart';
import '../../services/update_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  UpdateResult? _pendingUpdate;

  @override
  void initState() {
    super.initState();
    // Check for update silently on every dashboard open
    Future.microtask(_checkUpdate);
  }

  Future<void> _checkUpdate() async {
    final update = await UpdateService.silentCheck();
    if (update != null && mounted) {
      setState(() => _pendingUpdate = update);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashAsync = ref.watch(dashboardProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      // Update banner at top when new version available
      bottomNavigationBar: _pendingUpdate != null
          ? _UpdateBanner(
              update: _pendingUpdate!,
              onDismiss: () => setState(() => _pendingUpdate = null),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(dashboardProvider.notifier).fetch();
          ref.read(productProvider.notifier).fetchFromServer();
        },
        child: CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.primary, AppTheme.secondary],
                      begin: Alignment.topLeft, end: Alignment.bottomRight)),
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('Welcome back,', style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13)),
                    Text(user?.name ?? 'User', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(user?.shopName ?? '', style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 12)),
                  ]),
                  CircleAvatar(backgroundColor: Colors.white.withAlpha(50),
                      child: Text((user?.name ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ]),
              ),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: () => ref.read(dashboardProvider.notifier).fetch()),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: dashAsync.when(
              loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('Could not load data', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: () => ref.read(dashboardProvider.notifier).fetch(),
                      child: const Text('Retry')),
                ]))),
              data: (d) => _DashboardContent(data: d),
            ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/pos'),
        icon: const Icon(Icons.point_of_sale_rounded),
        label: const Text('New Sale'),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  final DashboardModel data;
  const _DashboardContent({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStock = ref.watch(productProvider).lowStock;

    return SliverList(delegate: SliverChildListDelegate([
      // Today
      Text('Today', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _StatCard(label: 'Sales', value: Helpers.formatCurrency(data.todaySales),
            sub: '${data.todaySalesCount} orders', icon: Icons.shopping_cart_rounded, color: AppTheme.primary)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Profit', value: Helpers.formatCurrency(data.todayProfit),
            sub: 'Net today', icon: Icons.trending_up_rounded, color: AppTheme.success)),
      ]),
      const SizedBox(height: 16),

      // Month
      Text('This Month', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _StatCard(label: 'Revenue', value: Helpers.formatCurrency(data.monthSales),
            sub: '${data.monthSalesCount} orders', icon: Icons.account_balance_wallet_rounded, color: AppTheme.secondary)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: 'Profit', value: Helpers.formatCurrency(data.monthProfit),
            sub: 'Net month', icon: Icons.bar_chart_rounded, color: AppTheme.accent)),
      ]),
      const SizedBox(height: 16),

      // Alerts
      Row(children: [
        Expanded(child: _AlertCard(label: 'Low Stock', value: data.lowStockCount.toString(),
            sub: 'items to reorder', icon: Icons.warning_rounded, color: AppTheme.warning,
            onTap: () => GoRouter.of(context).go('/products'))),
        const SizedBox(width: 12),
        Expanded(child: _AlertCard(label: 'Pending', value: Helpers.formatCurrency(data.pendingAmount),
            sub: '${data.pendingCustomers} customers', icon: Icons.pending_actions_rounded, color: AppTheme.error,
            onTap: () => GoRouter.of(context).go('/customers'))),
      ]),

      if (lowStock.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('Low Stock Items', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...lowStock.take(5).map((p) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: AppTheme.warning.withAlpha(30),
                child: const Icon(Icons.inventory_2_outlined, color: AppTheme.warning, size: 20)),
            title: Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text(p.category),
            trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: p.quantity == 0 ? AppTheme.error : AppTheme.warning,
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${p.quantity} ${p.unit}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
          ),
        )),
      ],

      const SizedBox(height: 80),
    ]));
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.sub,
      required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          Icon(icon, color: color, size: 20),
        ]),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
      ]),
    ),
  );
}

// ── Update banner shown at bottom of dashboard ────────────────────
class _UpdateBanner extends StatefulWidget {
  final UpdateResult update;
  final VoidCallback onDismiss;
  const _UpdateBanner({required this.update, required this.onDismiss});
  @override
  State<_UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<_UpdateBanner> {
  bool _downloading = false;
  double _progress  = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        top: false,
        child: _downloading
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Downloading update v${widget.update.latestVersion}...',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
                const SizedBox(height: 4),
                Text('${(_progress * 100).toStringAsFixed(0)}%  — App will restart automatically',
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ])
            : Row(children: [
                const Icon(Icons.system_update_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, children: [
                  Text('Update v${widget.update.latestVersion} available',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  if (widget.update.releaseNotes.isNotEmpty)
                    Text(widget.update.releaseNotes,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                TextButton(
                  onPressed: widget.onDismiss,
                  child: const Text('Later', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                  onPressed: () async {
                    setState(() { _downloading = true; _progress = 0; });
                    await UpdateService.downloadAndInstall(
                      widget.update.downloadUrl,
                      onProgress: (received, total) {
                        if (total > 0 && mounted) {
                          setState(() => _progress = received / total);
                        }
                      },
                    );
                  },
                  child: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ]),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AlertCard({required this.label, required this.value, required this.sub,
      required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            Icon(icon, color: color, size: 20),
          ]),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ]),
      ),
    ),
  );
}
