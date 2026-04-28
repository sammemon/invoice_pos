import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/sync_service.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final bool isOnline;
  final int pendingCount;
  final String? lastError;

  const SyncState({
    this.status = SyncStatus.idle,
    this.isOnline = true,
    this.pendingCount = 0,
    this.lastError,
  });

  SyncState copyWith({SyncStatus? status, bool? isOnline, int? pendingCount, String? lastError}) =>
      SyncState(
        status: status ?? this.status,
        isOnline: isOnline ?? this.isOnline,
        pendingCount: pendingCount ?? this.pendingCount,
        lastError: lastError,
      );
}

class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier() : super(const SyncState()) { _init(); }

  Future<void> _init() async {
    final result = await Connectivity().checkConnectivity();
    final online = !result.contains(ConnectivityResult.none);
    state = state.copyWith(isOnline: online);

    Connectivity().onConnectivityChanged.listen((results) async {
      final isOnline = !results.contains(ConnectivityResult.none);
      state = state.copyWith(isOnline: isOnline);
      if (isOnline) await syncNow();
    });

    await _updatePendingCount();
    if (online) await syncNow();
  }

  Future<void> _updatePendingCount() async {
    final count = await SyncService.pendingCount();
    state = state.copyWith(pendingCount: count);
  }

  Future<void> syncNow() async {
    if (state.status == SyncStatus.syncing) return;
    state = state.copyWith(status: SyncStatus.syncing);
    try {
      await SyncService.syncAll();
      await _updatePendingCount();
      state = state.copyWith(status: SyncStatus.success);
    } catch (e) {
      state = state.copyWith(status: SyncStatus.error, lastError: e.toString());
    }
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((_) => SyncNotifier());
