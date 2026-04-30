import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/update_service.dart';

class UpdateState {
  final UpdateResult? available;
  final bool checking;
  final bool downloading;
  final double progress;         // 0.0 – 1.0
  final bool dismissed;

  const UpdateState({
    this.available,
    this.checking  = false,
    this.downloading = false,
    this.progress  = 0,
    this.dismissed = false,
  });

  bool get hasUpdate => available != null && !dismissed;

  UpdateState copyWith({
    UpdateResult? available,
    bool? checking,
    bool? downloading,
    double? progress,
    bool? dismissed,
  }) => UpdateState(
    available:   available   ?? this.available,
    checking:    checking    ?? this.checking,
    downloading: downloading ?? this.downloading,
    progress:    progress    ?? this.progress,
    dismissed:   dismissed   ?? this.dismissed,
  );
}

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier() : super(const UpdateState());

  Future<void> checkForUpdate() async {
    state = state.copyWith(checking: true);
    final result = await UpdateService.silentCheck();
    state = state.copyWith(checking: false, available: result);
  }

  Future<void> downloadAndInstall() async {
    final url = state.available?.downloadUrl;
    if (url == null) return;
    state = state.copyWith(downloading: true, progress: 0);
    try {
      await UpdateService.downloadAndInstall(url, onProgress: (received, total) {
        if (total > 0) state = state.copyWith(progress: received / total);
      });
    } catch (e) {
      // Reset so the dialog shows the error and the button is clickable again
      state = state.copyWith(downloading: false);
      debugPrint('Update failed: $e');
      rethrow;
    }
  }

  void dismiss() => state = state.copyWith(dismissed: true);
}

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>(
  (_) => UpdateNotifier(),
);
