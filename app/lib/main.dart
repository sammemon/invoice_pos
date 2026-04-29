import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/database/local_db.dart';
import 'core/network/api_client.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { await Hive.initFlutter(); } catch (e) { debugPrint('Hive: $e'); }
  try { await LocalDb.db;         } catch (e) { debugPrint('DB: $e'); }
  try { await ApiClient.init();   } catch (e) { debugPrint('API: $e'); }
  runApp(const ProviderScope(child: InvoicePosApp()));
}

class InvoicePosApp extends StatelessWidget {
  const InvoicePosApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Single MaterialApp — no switching between router/non-router variants.
    // _AuthGate inside decides what to show without replacing the MaterialApp.
    return MaterialApp(
      title: 'Invoice & POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      home: const _AuthGate(),
    );
  }
}

/// Watches auth state and swaps screens without replacing MaterialApp.
/// AnimatedSwitcher gives a smooth fade — no black frame ever.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    Widget screen;
    if (auth.isLoading) {
      screen = const _SplashScreen(key: ValueKey('splash'));
    } else if (!auth.isAuthenticated) {
      screen = const _LoginFlow(key: ValueKey('login'));
    } else {
      screen = _RouterShell(key: const ValueKey('main'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: screen,
    );
  }
}

/// Login + Register as simple Navigator screens — no GoRouter involved.
class _LoginFlow extends StatefulWidget {
  const _LoginFlow({super.key});
  @override
  State<_LoginFlow> createState() => _LoginFlowState();
}

class _LoginFlowState extends State<_LoginFlow> {
  @override
  Widget build(BuildContext context) => Navigator(
    onGenerateRoute: (settings) {
      switch (settings.name) {
        case '/register':
          return MaterialPageRoute(builder: (_) => const RegisterScreen());
        default:
          return MaterialPageRoute(builder: (_) => const LoginScreen());
      }
    },
  );
}

/// Main authenticated app — embeds GoRouter without needing MaterialApp.router.
class _RouterShell extends StatefulWidget {
  const _RouterShell({super.key});
  @override
  State<_RouterShell> createState() => _RouterShellState();
}

class _RouterShellState extends State<_RouterShell> {
  late final _router = buildRouter();

  @override
  Widget build(BuildContext context) => Router(
    routerDelegate:        _router.routerDelegate,
    routeInformationParser:  _router.routeInformationParser,
    routeInformationProvider: _router.routeInformationProvider,
    backButtonDispatcher:  RootBackButtonDispatcher(),
  );

  @override
  void dispose() { _router.dispose(); super.dispose(); }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFF1565C0),
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.receipt_long_rounded, size: 72, color: Colors.white),
      SizedBox(height: 24),
      Text('Invoice & POS',
          style: TextStyle(color: Colors.white, fontSize: 28,
              fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
      SizedBox(height: 40),
      CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
    ])),
  );
}
