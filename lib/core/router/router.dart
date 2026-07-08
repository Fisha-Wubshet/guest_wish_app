import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_state.dart';
import '../models/booking.dart';
import '../branch/branch_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/branch_select_screen.dart';
import '../../features/bookings/bookings_screen.dart';
import '../../features/bookings/booking_detail_screen.dart';
import '../../features/bookings/modify_booking_screen.dart';
import '../../features/operations/operations_screen.dart';
import '../../features/new_booking/new_booking_screen.dart';
import '../../features/customers/customers_screen.dart';
import '../../features/customers/customer_detail_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/items/items_screen.dart';
import '../../features/categories/categories_screen.dart';
import '../../features/staff/staff_screen.dart';
import '../../features/staff/staff_detail_screen.dart';
import '../../features/branches/branches_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/payments/payment_history_screen.dart';
import '../../features/deposits/deposits_screen.dart';
import '../../shared/shell/main_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/bookings',
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final branchState = ref.read(branchProvider);

      if (authState.isLoading || !branchState.isRestored) return null;

      final loggedIn = authState.isAuthenticated;
      final location = state.matchedLocation;

      if (!loggedIn && location != '/login') return '/login';

      if (loggedIn && location == '/login') {
        final user = authState.user!;
        if (user.isShopAdmin && branchState.activeBranch == null) {
          return '/branch-select';
        }
        return '/bookings';
      }

      if (loggedIn &&
          location != '/login' &&
          location != '/branch-select') {
        final user = authState.user!;
        if (user.isShopAdmin && branchState.activeBranch == null) {
          return '/branch-select';
        }
      }

      return null;
    },
    refreshListenable: _AppListenable(ref),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/branch-select',
        builder: (context, state) => const BranchSelectScreen(),
      ),
      GoRoute(
        path: '/new-booking',
        builder: (context, state) => const NewBookingScreen(),
      ),
      GoRoute(
        path: '/bookings/:id',
        builder: (context, state) =>
            BookingDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/bookings/:id/modify',
        builder: (context, state) {
          final booking = state.extra as Booking;
          return ModifyBookingScreen(booking: booking);
        },
      ),
      GoRoute(
        path: '/customers/:id',
        builder: (context, state) =>
            CustomerDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/items',
        builder: (context, state) => const ItemsScreen(),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/staff',
        builder: (context, state) => const StaffScreen(),
      ),
      GoRoute(
        path: '/staff/:id',
        builder: (context, state) =>
            StaffDetailScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/branches',
        builder: (context, state) => const BranchesScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/payments',
        builder: (context, state) => const PaymentHistoryScreen(),
      ),
      GoRoute(
        path: '/deposits',
        builder: (context, state) => const DepositsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/bookings',
              builder: (context, state) => const BookingsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/operations',
              builder: (context, state) => const OperationsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/customers',
              builder: (context, state) => const CustomersScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});

class _AppListenable extends ChangeNotifier {
  _AppListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
    ref.listen(branchProvider, (_, __) => notifyListeners());
  }
}
