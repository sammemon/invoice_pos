import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../services/update_service.dart';
import '../../services/wifi_export_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final sync = ref.watch(syncProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: [
        // ── Account ──────────────────────────────────────────
        _SectionHeader('Account'),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primary.withAlpha(20),
            child: Text((user?.name ?? 'U')[0].toUpperCase(),
                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
          title: Text(user?.name ?? ''),
          subtitle: Text(user?.email ?? ''),
          trailing: const Icon(Icons.edit_rounded),
          onTap: () => _editProfile(context, ref, user),
        ),
        ListTile(
          leading: const Icon(Icons.store_outlined),
          title: const Text('Shop Name'),
          subtitle: Text(user?.shopName ?? ''),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline_rounded),
          title: const Text('Change Password'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _changePassword(context, ref),
        ),
        const Divider(),

        // ── Server ───────────────────────────────────────────
        _SectionHeader('Server'),
        ListTile(
          leading: const Icon(Icons.dns_rounded, color: AppTheme.secondary),
          title: const Text('Backend Server URL'),
          subtitle: Text(ApiClient.instance.currentBaseUrl,
              style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.edit_rounded),
          onTap: () => _editServerUrl(context),
        ),
        const Divider(),

        // ── Sync ─────────────────────────────────────────────
        _SectionHeader('Sync & Data'),
        ListTile(
          leading: Icon(
            sync.isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: sync.isOnline ? AppTheme.success : AppTheme.error,
          ),
          title: Text(sync.isOnline ? 'Online — Connected' : 'Offline Mode'),
          subtitle: sync.pendingCount > 0
              ? Text('${sync.pendingCount} items pending sync',
                  style: const TextStyle(color: AppTheme.warning))
              : const Text('All data synced'),
          trailing: TextButton(
            onPressed: () => ref.read(syncProvider.notifier).syncNow(),
            child: const Text('Sync Now'),
          ),
        ),
        const Divider(),

        // ── Wi-Fi Export ─────────────────────────────────────
        _SectionHeader('Wi-Fi Export'),
        ListTile(
          leading: const Icon(Icons.wifi_rounded, color: AppTheme.secondary),
          title: const Text('Start Wi-Fi Export Server'),
          subtitle: const Text('Share data over local network (CSV / PDF)'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _startWifiExport(context),
        ),
        const Divider(),

        // ── App ──────────────────────────────────────────────
        _SectionHeader('App'),
        ListTile(
          leading: const Icon(Icons.system_update_rounded),
          title: const Text('Check for Updates'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _checkUpdate(context),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('App Version'),
          trailing: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snap) => Text(
              snap.data?.version ?? AppConstants.appVersion,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ),
        const Divider(),

        // ── Logout ───────────────────────────────────────────
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: AppTheme.error),
          title: const Text('Logout', style: TextStyle(color: AppTheme.error)),
          onTap: () => _logout(context, ref),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  // ── Edit profile ─────────────────────────────────────────
  void _editProfile(BuildContext context, WidgetRef ref, user) {
    final nameCtrl  = TextEditingController(text: user?.name ?? '');
    final shopCtrl  = TextEditingController(text: user?.shopName ?? '');
    final phoneCtrl = TextEditingController(text: user?.phone ?? '');
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Edit Profile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(controller: shopCtrl,
                  decoration: const InputDecoration(labelText: 'Shop Name')),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: saving ? null : () async {
                  setState(() => saving = true);
                  try {
                    await ref.read(authProvider.notifier).updateProfile(
                      name: nameCtrl.text.trim(),
                      shopName: shopCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Failed: $e')));
                    }
                  } finally {
                    setState(() => saving = false);
                  }
                },
                child: saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Change password ──────────────────────────────────────
  void _changePassword(BuildContext context, WidgetRef ref) {
    final currentCtrl = TextEditingController();
    final newCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Change Password',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: currentCtrl, obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password')),
            const SizedBox(height: 12),
            TextField(controller: newCtrl, obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password')),
            const SizedBox(height: 12),
            TextField(controller: confirmCtrl, obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password')),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (newCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Passwords do not match')));
                  return;
                }
                try {
                  await ref.read(authProvider.notifier).changePassword(
                    currentCtrl.text, newCtrl.text);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Password changed successfully')));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Failed: $e')));
                  }
                }
              },
              child: const Text('Change Password'),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Server URL ───────────────────────────────────────────
  void _editServerUrl(BuildContext context) {
    final ctrl = TextEditingController(text: ApiClient.instance.currentBaseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend Server URL'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enter the full API URL including /api',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'http://192.168.1.10:5000/api',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final url = ctrl.text.trim();
              if (url.isEmpty) return;
              await ApiClient.instance.updateBaseUrl(url);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Server URL saved. Restart app to apply.')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Wi-Fi export ─────────────────────────────────────────
  void _startWifiExport(BuildContext context) async {
    try {
      final url = await WifiExportService.start();
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Wi-Fi Export Active'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Open on any device on the same Wi-Fi:'),
            const SizedBox(height: 12),
            SelectableText(url,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ]),
          actions: [
            TextButton(
              onPressed: () { WifiExportService.stop(); Navigator.pop(context); },
              child: const Text('Stop Server'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  // ── Update check ─────────────────────────────────────────
  void _checkUpdate(BuildContext context) async {
    try {
      final result = await UpdateService.checkForUpdate();
      if (!context.mounted) return;
      if (!result['hasUpdate']) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are on the latest version!')));
      } else {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Update Available'),
            content: Text(
                'Version ${result['latestVersion']} is available.\n\n${result['releaseNotes'] ?? ''}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  UpdateService.downloadAndInstall(result['downloadUrl']);
                },
                child: const Text('Update Now'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Check failed: $e')));
      }
    }
  }

  // ── Logout ───────────────────────────────────────────────
  void _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('You will be signed out.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authProvider.notifier).logout();
      // refreshListenable is suppressed during logout to prevent ShellRoute conflict.
      // Navigate explicitly here — this is the only navigation that fires.
      if (context.mounted) context.go('/login');
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(title,
        style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5)),
  );
}
