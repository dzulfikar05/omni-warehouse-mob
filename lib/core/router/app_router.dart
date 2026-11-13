import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_provider.dart';
import '../../features/auth/auth_model.dart';
import '../../features/auth/home_screen.dart';
import '../../features/auth/login_step1_screen.dart';
import '../../features/auth/login_step2_screen.dart';

// Import Feature Screens
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/inbound/inbound_list_screen.dart';
import '../../features/inbound/inbound_scanner_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/outbound/outbound_list_screen.dart';
import '../../features/outbound/outbound_scanner_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/scanner/generic_scanner_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/stock_opname/stock_opname_screen.dart';
import '../../features/stock_opname/stock_opname_scanner_screen.dart';
import '../../features/stock_transfer/transfer_scanner_screen.dart';
import '../../features/stock_transfer/transfer_transaction_form_screen.dart';
import '../../features/stock_transfer/transfer_transactions_screen.dart';
import '../../features/stock_transfer/transfer_transaction_model.dart';
import '../../features/sync/sync_screen.dart';
import '../../shared/widgets/omni_bottom_nav.dart';

CustomTransitionPage<void> _buildFadePage({
  required LocalKey key,
  required Widget child,
  Duration duration = const Duration(milliseconds: 550),
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        ),
        child: child,
      );
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _RouterRefreshListenable();
  ref.listen(authProvider, (previous, next) {
    refreshListenable.refresh();
  });
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final isAuth = ref.read(authProvider).isAuthenticated;
      final isOnAuthRoute =
          state.matchedLocation == '/splash' ||
          state.matchedLocation == '/home' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation.startsWith('/login/');

      if (isAuth && isOnAuthRoute) {
        return '/dashboard';
      }
      if (!isAuth && state.matchedLocation == '/home') {
        return '/login/tenant';
      }
      if (!isAuth && !isOnAuthRoute) return '/splash';
      return null;
    },
    routes: [
      // Splash dengan fade page
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) =>
            _buildFadePage(key: state.pageKey, child: const SplashScreen()),
      ),

      // Auth dengan fade page
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) =>
            _buildFadePage(key: state.pageKey, child: const HomeScreen()),
      ),

      // =======================================================================
      // AUTHENTICATION ROUTES (PENANGANAN REDIRECT & EXTRA PAYLOAD)
      // =======================================================================

      // Alias /login -> Mengarah langsung ke Step 1 (Mencegah GoException)
      GoRoute(path: '/login', redirect: (context, state) => '/login/tenant'),

      // Step 1: Verification Workspace Tenant
      GoRoute(
        path: '/login/tenant',
        builder: (context, state) => const LoginStep1Screen(),
      ),

      // Step 2: Credentials Login (MELEWATKAN EXTRA PAYLOAD TENANT INFO)
      GoRoute(
        path: '/login/credentials',
        builder: (context, state) {
          final tenantInfo = state.extra as TenantInfo?;
          return LoginStep2Screen(tenantInfo: tenantInfo);
        },
      ),

      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => _buildFadePage(
          key: state.pageKey,
          child: const NotificationsScreen(),
        ),
      ),

      // Main shell dengan bottom nav
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => OmniBottomNav(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inbound',
                builder: (context, state) => const InboundListScreen(),
                routes: [
                  GoRoute(
                    path: ':code',
                    builder: (context, state) => InboundScannerScreen(
                      code: state.pathParameters['code']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/scanner',
                builder: (context, state) => const GenericScannerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/outbound',
                builder: (context, state) => const OutboundListScreen(),
                routes: [
                  GoRoute(
                    path: ':code',
                    builder: (context, state) => OutboundScannerScreen(
                      code: state.pathParameters['code']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more/transfer',
                builder: (context, state) => const TransferTransactionsScreen(),
                routes: [
                  GoRoute(
                    path: 'form',
                    builder: (context, state) => TransferTransactionFormScreen(
                      transaction: state.extra as TransferTransaction?,
                    ),
                  ),
                  GoRoute(
                    path: 'scan',
                    builder: (context, state) => const TransferScannerScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: '/more/opname',
                builder: (context, state) => const StockOpnameScreen(),
                routes: [
                  GoRoute(
                    path: ':session_code',
                    builder: (context, state) => StockOpnameScannerScreen(
                      sessionCode: state.pathParameters['session_code']!,
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/more/sync',
                builder: (context, state) => const SyncScreen(),
              ),
              GoRoute(
                path: '/more/profile',
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Legacy Route Redirects
      GoRoute(
        path: '/transfer',
        redirect: (context, state) => '/more/transfer',
      ),
      GoRoute(
        path: '/transfer/form',
        redirect: (context, state) => '/more/transfer/form',
      ),
      GoRoute(path: '/opname', redirect: (context, state) => '/more/opname'),
      GoRoute(
        path: '/opname/:session_code',
        redirect: (context, state) =>
            '/more/opname/${state.pathParameters['session_code']}',
      ),
      GoRoute(path: '/sync', redirect: (context, state) => '/more/sync'),
      GoRoute(path: '/profile', redirect: (context, state) => '/more/profile'),
      GoRoute(
        path: '/profile/edit',
        redirect: (context, state) => '/more/profile/edit',
      ),
    ],
  );
});

class _RouterRefreshListenable extends ChangeNotifier {
  void refresh() => notifyListeners();
}
