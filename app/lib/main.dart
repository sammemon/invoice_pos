import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/database/local_db.dart';
import 'core/network/api_client.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Each init is isolated — one failure must never blank the whole app
  try { await Hive.initFlutter(); } catch (e) { debugPrint('Hive init error: $e'); }
  try { await LocalDb.db;         } catch (e) { debugPrint('DB init error: $e'); }
  try { await ApiClient.init();   } catch (e) { debugPrint('ApiClient init error: $e'); }

  runApp(const ProviderScope(child: InvoicePosApp()));
}

class InvoicePosApp extends ConsumerWidget {
  const InvoicePosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Invoice & POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
