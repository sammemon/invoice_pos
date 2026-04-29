import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/update_provider.dart';
import '../../core/theme/app_theme.dart';

// Static flag — survives widget rebuilds/navigation, resets only on app restart.
// Prevents the dialog from reappearing every time the user navigates.
bool _sessionDialogShown = false;

class UpdateChecker extends ConsumerStatefulWidget {
  final Widget child;
  const UpdateChecker({super.key, required this.child});

  @override
  ConsumerState<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends ConsumerState<UpdateChecker> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) ref.read(updateProvider.notifier).checkForUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UpdateState>(updateProvider, (_, next) {
      // Only show once per session, and only if update is available and not dismissed
      if (next.hasUpdate && !next.dismissed && !_sessionDialogShown) {
        _sessionDialogShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showDialog(context);
        });
      }
    });
    return widget.child;
  }

  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      useRootNavigator: true,  // Root navigator — survives ShellRoute teardown
      barrierDismissible: false,
      builder: (_) => const _UpdateDialog(),
    );
  }
}

class _UpdateDialog extends ConsumerWidget {
  const _UpdateDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state  = ref.watch(updateProvider);
    final result = state.available;
    if (result == null) return const SizedBox.shrink();

    return PopScope(
      canPop: false, // prevent back-button dismiss which also caused black screen
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.system_update_rounded, color: AppTheme.primary),
          const SizedBox(width: 10),
          const Text('Update Available'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Version ${result.latestVersion} is ready to install.',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (result.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(result.releaseNotes,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
          if (state.downloading) ...[
            const SizedBox(height: 16),
            ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
              )),
            const SizedBox(height: 6),
            Text(
              state.progress > 0
                  ? 'Downloading... ${(state.progress * 100).toStringAsFixed(0)}%'
                  : 'Starting download...',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ]),
        actions: [
          if (!state.downloading)
            TextButton(
              onPressed: () {
                ref.read(updateProvider.notifier).dismiss();
                // Use root navigator to close — prevents black screen
                Navigator.of(context, rootNavigator: true).pop();
              },
              child: const Text('Later'),
            ),
          if (!state.downloading)
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(updateProvider.notifier).downloadAndInstall(),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download & Install'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
    );
  }
}
