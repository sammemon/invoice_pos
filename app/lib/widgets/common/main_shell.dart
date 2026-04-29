import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/sync_provider.dart';
import 'update_dialog.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    (icon: Icons.dashboard_rounded, label: 'Dashboard', path: '/dashboard'),
    (icon: Icons.point_of_sale_rounded, label: 'POS', path: '/pos'),
    (icon: Icons.inventory_2_rounded, label: 'Products', path: '/products'),
    (icon: Icons.people_rounded, label: 'Customers', path: '/customers'),
    (icon: Icons.bar_chart_rounded, label: 'Reports', path: '/reports'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final isWide = MediaQuery.of(context).size.width >= 720;

    final selectedIndex = _tabs.indexWhere((t) => location.startsWith(t.path));

    final scaffold = isWide
        ? Scaffold(
            body: Row(children: [
              NavigationRail(
                extended: MediaQuery.of(context).size.width >= 960,
                selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
                onDestinationSelected: (i) => context.go(_tabs[i].path),
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(children: [
                    const Icon(Icons.receipt_long_rounded, size: 32, color: Color(0xFF1565C0)),
                    const SizedBox(height: 4),
                    _SyncIndicator(sync: sync),
                  ]),
                ),
                destinations: _tabs.map((t) => NavigationRailDestination(
                    icon: Icon(t.icon), label: Text(t.label))).toList(),
                trailing: IconButton(
                  icon: const Icon(Icons.settings_rounded),
                  onPressed: () => context.go('/settings'),
                ),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: child),
            ]),
          )
        : Scaffold(
            appBar: AppBar(
              title: const Text('Invoice & POS'),
              actions: [
                _SyncIndicator(sync: sync),
                IconButton(icon: const Icon(Icons.settings_rounded), onPressed: () => context.go('/settings')),
              ],
            ),
            body: child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onDestinationSelected: (i) => context.go(_tabs[i].path),
              destinations: _tabs.map((t) => NavigationDestination(
                  icon: Icon(t.icon), label: t.label)).toList(),
            ),
          );

    // UpdateChecker silently checks for a new version 3s after login.
    // When found it shows the download dialog automatically.
    return UpdateChecker(child: scaffold);
  }
}

class _SyncIndicator extends StatelessWidget {
  final SyncState sync;
  const _SyncIndicator({required this.sync});

  @override
  Widget build(BuildContext context) {
    if (!sync.isOnline) {
      return const Tooltip(message: 'Offline', child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 20)));
    }
    if (sync.status == SyncStatus.syncing) {
      return const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (sync.pendingCount > 0) {
      return Tooltip(message: '${sync.pendingCount} pending sync',
          child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.sync_problem_rounded, color: Colors.orange, size: 20)));
    }
    return const Tooltip(message: 'Synced', child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Icon(Icons.cloud_done_rounded, color: Colors.green, size: 20)));
  }
}
