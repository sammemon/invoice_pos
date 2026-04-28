import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/products/products_screen.dart';
import 'screens/products/add_product_screen.dart';
import 'screens/pos/pos_screen.dart';
import 'screens/pos/invoice_screen.dart';
import 'screens/customers/customers_screen.dart';
import 'screens/customers/customer_detail_screen.dart';
import 'screens/suppliers/suppliers_screen.dart';
import 'screens/expenses/expenses_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'widgets/common/main_shell.dart';

// Router is created once — auth changes are handled via refreshListenable
// This prevents the black screen that occurs when GoRouter is recreated
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.read(authProvider.notifier);

  final router = GoRouter(
    initialLocation: '/',
    // ValueNotifier<int> implements Listenable — GoRouter re-evaluates
    // redirect every time routerListenable increments (on auth change)
    refreshListenable: authNotifier.routerListenable,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      // Wait for session restore — show splash, don't redirect yet
      if (auth.isLoading) return '/splash';
      final loggedIn = auth.isAuthenticated;
      final onAuth   = state.matchedLocation == '/login' ||
                       state.matchedLocation == '/register';
      if (state.matchedLocation == '/splash') {
        return loggedIn ? '/dashboard' : '/login';
      }
      if (!loggedIn && !onAuth) return '/login';
      if (loggedIn && onAuth)   return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/splash',   builder: (_, _) => const _SplashScreen()),
      GoRoute(path: '/login',    builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/',         redirect: (_, _) => '/splash'),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/products',  builder: (_, _) => const ProductsScreen(),
            routes: [
              GoRoute(path: 'add',      builder: (_, _) => const AddProductScreen()),
              GoRoute(path: 'edit/:id', builder: (ctx, s) => AddProductScreen(
                  productId: s.pathParameters['id'])),
            ]),
          GoRoute(path: '/pos',         builder: (_, _) => const PosScreen()),
          GoRoute(path: '/invoice/:id', builder: (ctx, s) => InvoiceScreen(
              saleId: s.pathParameters['id']!)),
          GoRoute(path: '/customers',   builder: (_, _) => const CustomersScreen(),
            routes: [
              GoRoute(path: ':id', builder: (ctx, s) => CustomerDetailScreen(
                  customerId: s.pathParameters['id']!)),
            ]),
          GoRoute(path: '/suppliers', builder: (_, _) => const SuppliersScreen()),
          GoRoute(path: '/expenses',  builder: (_, _) => const ExpensesScreen()),
          GoRoute(path: '/reports',   builder: (_, _) => const ReportsScreen()),
          GoRoute(path: '/settings',  builder: (_, _) => const SettingsScreen()),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

// Shown while AuthNotifier restores the session from secure storage
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFF1565C0),
    body: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long_rounded, size: 72, color: Colors.white),
        SizedBox(height: 24),
        Text('Invoice & POS', style: TextStyle(color: Colors.white,
            fontSize: 28, fontWeight: FontWeight.bold)),
        SizedBox(height: 40),
        CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
      ]),
    ),
  );
}
