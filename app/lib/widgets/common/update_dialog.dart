import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/update_provider.dart';
import '../../services/update_service.dart';
import '../../core/theme/app_theme.dart';

/// Drop this widget anywhere in the tree after login.
/// It auto-checks for updates and shows a dialog when one is found.
class UpdateChecker extends ConsumerStatefulWidget {
  final Widget child;
  const UpdateChecker({super.key, required this.child});

  @override
  ConsumerState<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends ConsumerState<UpdateChecker> {
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    // Delay slightly so the UI renders first
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) ref.read(updateProvider.notifier).checkForUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    final update = ref.watch(updateProvider);

    // Show dialog once when update becomes available
    if (update.hasUpdate && !_dialogShown) {
      _dialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showUpdateDialog(context, update.available!);
      });
    }

    return widget.child;
  }

  void _showUpdateDialog(BuildContext context, UpdateResult result) {
    showDialog(
      context: context,
      barrierDismissible: !result.isForceUpdate,
      builder: (_) => const _UpdateDialogContent(),
    ).then((_) => _dialogShown = false);
  }
}

class _UpdateDialogContent extends ConsumerWidget {
  const _UpdateDialogContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateProvider);
    final result = update.available;
    if (result == null) return const SizedBox.shrink();

    return PopScope(
      canPop: !result.isForceUpdate,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.system_update_rounded, color: AppTheme.primary),
          const SizedBox(width: 10),
          const Text('Update Available'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Version ${result.latestVersion} is ready to install.',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (result.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(result.releaseNotes, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
          if (update.downloading) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: update.progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              update.progress > 0
                ? 'Downloading... ${(update.progress * 100).toStringAsFixed(0)}%'
                : 'Starting download...',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ]),
        actions: [
          if (!result.isForceUpdate && !update.downloading)
            TextButton(
              onPressed: () {
                ref.read(updateProvider.notifier).dismiss();
                Navigator.pop(context);
              },
              child: const Text('Later'),
            ),
          if (!update.downloading)
            ElevatedButton.icon(
              onPressed: () => ref.read(updateProvider.notifier).downloadAndInstall(),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download & Install'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}
