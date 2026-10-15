import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_warehouse_mob/features/dashboard/dashboard_screen.dart';
import 'package:omni_warehouse_mob/shared/widgets/omni_bottom_nav.dart';

void main() {
  testWidgets('dashboard shows overview and routes quick action to inbound', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
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
                  builder: (context, state) => const Scaffold(
                    body: Center(child: Text('Inbound destination')),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/scanner',
                  builder: (context, state) => const Scaffold(
                    body: Center(child: Text('Scanner destination')),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/outbound',
                  builder: (context, state) => const Scaffold(
                    body: Center(child: Text('Outbound destination')),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/more',
                  builder: (context, state) => const Scaffold(
                    body: Center(child: Text('More destination')),
                  ),
                  routes: [
                    GoRoute(
                      path: 'transfer',
                      builder: (context, state) => const Scaffold(
                        body: Center(child: Text('Transfer destination')),
                      ),
                    ),
                    GoRoute(
                      path: 'opname',
                      builder: (context, state) => const Scaffold(
                        body: Center(child: Text('Opname destination')),
                      ),
                    ),
                    GoRoute(
                      path: 'sync',
                      builder: (context, state) => const Scaffold(
                        body: Center(child: Text('Sync destination')),
                      ),
                    ),
                    GoRoute(
                      path: 'profile',
                      builder: (context, state) => const Scaffold(
                        body: Center(child: Text('Profile destination')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tugas Lapangan Hari Ini'), findsOneWidget);
    expect(find.text('Buka Kamera Scanner'), findsOneWidget);
    expect(find.text('PO IN'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsWidgets);

    await tester.tap(find.text('Inbound'));
    await tester.pumpAndSettle();

    expect(find.text('Inbound destination'), findsOneWidget);

    await tester.tap(find.text('Lainnya'));
    await tester.pumpAndSettle();

    expect(find.text('Fitur Lainnya'), findsOneWidget);
    expect(find.text('Transfer Stok'), findsOneWidget);

    await tester.tap(find.text('Transfer Stok'));
    await tester.pumpAndSettle();

    expect(find.text('Transfer destination'), findsOneWidget);
  });

  testWidgets('scanner floating action button selects scanner tab', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => OmniBottomNav(shell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/dashboard',
                  builder: (context, state) => const Scaffold(
                    body: Center(child: Text('Dashboard destination')),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/inbound',
                  builder: (context, state) => const SizedBox.shrink(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/scanner',
                  builder: (context, state) => const Scaffold(
                    body: Center(child: Text('Scanner destination')),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/outbound',
                  builder: (context, state) => const SizedBox.shrink(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/more',
                  builder: (context, state) => const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Scanner destination'), findsOneWidget);
  });
}
