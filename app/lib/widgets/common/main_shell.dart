import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/sync_provider.dart';
import 'update_dialog.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _tabs = [
    (icon: Icons.home_rounded,        label: 'Dashboard',  path: '/dashboard'),
    (icon: Icons.inventory_2_rounded,  label: 'Products',   path: '/products'),
    (icon: Icons.point_of_sale_rounded,label: 'Counter',    path: '/pos'),
    (icon: Icons.bar_chart_rounded,    label: 'Reports',    path: '/reports'),
    (icon: Icons.settings_rounded,     label: 'Settings',   path: '/settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync    = ref.watch(syncProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final isWide   = MediaQuery.of(context).size.width >= 720;
    final selIdx   = _tabs.indexWhere((t) => location.startsWith(t.path));

    final content = isWide
        ? Scaffold(
            body: Row(children: [
              NavigationRail(
                extended: MediaQuery.of(context).size.width >= 960,
                selectedIndex: selIdx < 0 ? 0 : selIdx,
                onDestinationSelected: (i) => context.go(_tabs[i].path),
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(children: [
                    const Icon(Icons.receipt_long_rounded,
                        size: 32, color: Color(0xFF1565C0)),
                    const SizedBox(height: 4),
                    _SyncDot(sync: sync),
                  ]),
                ),
                destinations: _tabs.map((t) => NavigationRailDestination(
                    icon: Icon(t.icon), label: Text(t.label))).toList(),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: child),
            ]),
          )
        : Scaffold(
            body: child,
            bottomNavigationBar: NavigationBar(
              selectedIndex: selIdx < 0 ? 0 : selIdx,
              onDestinationSelected: (i) => context.go(_tabs[i].path),
              destinations: _tabs.map((t) => NavigationDestination(
                  icon: Icon(t.icon), label: t.label)).toList(),
            ),
          );

    return UpdateChecker(child: content);
  }
}

class _SyncDot extends StatelessWidget {
  final SyncState sync;
  const _SyncDot({required this.sync});

  @override
  Widget build(BuildContext context) {
    if (!sync.isOnline) {
      return const Tooltip(message: 'Offline',
          child: Padding(padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 20)));
    }
    if (sync.status == SyncStatus.syncing) {
      return const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (sync.pendingCount > 0) {
      return Tooltip(message: '${sync.pendingCount} pending',
          child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.sync_problem_rounded, color: Colors.orange, size: 20)));
    }
    return const Tooltip(message: 'Synced',
        child: Padding(padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.cloud_done_rounded, color: Colors.green, size: 20)));
  }
}
