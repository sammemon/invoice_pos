import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/dashboard_model.dart';

class DashboardNotifier extends StateNotifier<AsyncValue<DashboardModel>> {
  DashboardNotifier() : super(const AsyncValue.loading()) { fetch(); }

  Future<void> fetch() async {
    state = const AsyncValue.loading();
    try {
      final res = await ApiClient.instance.get('/reports/dashboard');
      state = AsyncValue.data(DashboardModel.fromJson(res.data['data']));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, AsyncValue<DashboardModel>>((_) => DashboardNotifier());
