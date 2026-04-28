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
      final loggedIn = ref.read(authProvider).isAuthenticated;
      final onAuth = state.matchedLocation == '/login' ||
                     state.matchedLocation == '/register';
      if (!loggedIn && !onAuth) return '/login';
      if (loggedIn && onAuth) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login',    builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/',         redirect: (_, _) => '/dashboard'),
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

  // Dispose router when provider is disposed
  ref.onDispose(router.dispose);
  return router;
});
