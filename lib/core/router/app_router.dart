import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/omni_bottom_nav.dart';
import '../../features/auth/home_screen.dart';
import '../../features/auth/login_step1_screen.dart';
import '../../features/auth/login_step2_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/inbound/inbound_list_screen.dart';
import '../../features/inbound/inbound_scanner_screen.dart';
import '../../features/outbound/outbound_list_screen.dart';
import '../../features/outbound/outbound_scanner_screen.dart';
import '../../features/stock_transfer/transfer_list_screen.dart';
import '../../features/stock_transfer/transfer_form_screen.dart';
import '../../features/stock_transfer/transfer_scanner_screen.dart';
import '../../features/stock_opname/opname_list_screen.dart';
import '../../features/stock_opname/opname_scanner_screen.dart';
import '../../features/scanner/generic_scanner_screen.dart';
import '../../features/sync/sync_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../auth/auth_provider.dart';

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
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: authState.isAuthenticated ? '/dashboard' : '/splash',
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final isSplash = state.matchedLocation == '/splash';
      final isOnAuthRoute =
          state.matchedLocation.startsWith('/home') ||
          state.matchedLocation.startsWith('/login') ||
          isSplash;

      if (!isAuth && !isOnAuthRoute) return '/splash';
      if (isAuth && (state.matchedLocation == '/home' || state.matchedLocation.startsWith('/login'))) return '/dashboard';
      return null;
    },
    routes: [
      // Splash dengan fade page
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => _buildFadePage(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),

      // Auth dengan fade page
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => _buildFadePage(
          key: state.pageKey,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '/login/tenant',
        builder: (context, state) => const LoginStep1Screen(),
      ),
      GoRoute(
        path: '/login/credentials',
        builder: (context, state) => const LoginStep2Screen(),
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
                builder: (context, state) => const TransferListScreen(),
                routes: [
                  GoRoute(
                    path: 'form',
                    builder: (context, state) => const TransferFormScreen(),
                  ),
                  GoRoute(
                    path: 'scan',
                    builder: (context, state) => const TransferScannerScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: '/more/opname',
                builder: (context, state) => const OpnameListScreen(),
                routes: [
                  GoRoute(
                    path: ':session_code',
                    builder: (context, state) => OpnameScannerScreen(
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

      // Keep existing links valid while the features live under the shell.
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
