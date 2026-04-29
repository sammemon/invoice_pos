import 'package:go_router/go_router.dart';
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

/// Builds a fresh GoRouter for the authenticated shell.
/// Called by _RouterShell in main.dart — no Riverpod, no auth redirects.
GoRouter buildRouter() => GoRouter(
  initialLocation: '/dashboard',
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (_, _) => const DashboardScreen()),
        GoRoute(path: '/products',  builder: (_, _) => const ProductsScreen(),
          routes: [
            GoRoute(path: 'add',      builder: (_, _) => const AddProductScreen()),
            GoRoute(path: 'edit/:id', builder: (ctx, s) =>
                AddProductScreen(productId: s.pathParameters['id'])),
          ]),
        GoRoute(path: '/pos',         builder: (_, _) => const PosScreen()),
        GoRoute(path: '/invoice/:id', builder: (ctx, s) =>
            InvoiceScreen(saleId: s.pathParameters['id']!)),
        GoRoute(path: '/customers',   builder: (_, _) => const CustomersScreen(),
          routes: [
            GoRoute(path: ':id', builder: (ctx, s) =>
                CustomerDetailScreen(customerId: s.pathParameters['id']!)),
          ]),
        GoRoute(path: '/suppliers', builder: (_, _) => const SuppliersScreen()),
        GoRoute(path: '/expenses',  builder: (_, _) => const ExpensesScreen()),
        GoRoute(path: '/reports',   builder: (_, _) => const ReportsScreen()),
        GoRoute(path: '/settings',  builder: (_, _) => const SettingsScreen()),
      ],
    ),
  ],
);
