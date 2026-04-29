import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/database/local_db.dart';
import 'core/network/api_client.dart';
import 'providers/auth_provider.dart';
import 'router.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Hive.initFlutter(); }  catch (e) { debugPrint('Hive: $e'); }
  try { await LocalDb.db; }          catch (e) { debugPrint('DB: $e'); }
  try { await ApiClient.init(); }    catch (e) { debugPrint('API: $e'); }
  runApp(const ProviderScope(child: InvoicePosApp()));
}

class InvoicePosApp extends ConsumerWidget {
  const InvoicePosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    // While restoring session from storage — show splash
    if (auth.isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _SplashScreen(),
      );
    }

    // Not logged in — show login/register flow (separate MaterialApp,
    // completely isolated from the main router — no ShellRoute involved)
    if (!auth.isAuthenticated) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.light,
        initialRoute: '/login',
        routes: {
          '/login':    (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
        },
      );
    }

    // Logged in — show the full app with its own router
    return MaterialApp.router(
      title: 'Invoice & POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFF1565C0),
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.receipt_long_rounded, size: 72, color: Colors.white),
      SizedBox(height: 24),
      Text('Invoice & POS', style: TextStyle(color: Colors.white,
          fontSize: 28, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
      SizedBox(height: 40),
      CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
    ])),
  );
}
