import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_warehouse_mob/features/dashboard/dashboard_repository.dart';
import 'package:omni_warehouse_mob/features/dashboard/dashboard_screen.dart';
import 'package:omni_warehouse_mob/shared/widgets/omni_bottom_nav.dart';

void main() {
  test('dashboard reads the global summary endpoint response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://wms.test/api'));
    RequestOptions? request;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              data: {
                'status': 'success',
                'message': 'ok',
                'data': {
                  'kpi': {
                    'active_inbound_count': 4,
                    'active_outbound_count': 2,
                    'pending_transfer_count': 3,
                    'active_opname_count': 1,
                    'offline_queue_count': 0,
                  },
                  'tasks': [
                    {
                      'id': '31',
                      'type': 'inbound',
                      'status': 'receiving',
                      'badge_label': 'RECEIVING',
                      'code': 'PO-123',
                      'title': 'Supplier A',
                      'subtitle': '2 SKU • Dock Bay 1',
                      'progress_current': 2,
                      'progress_total': 5,
                      'location': 'Dock Bay 1',
                      'route': '/inbound/PO-123',
                    },
                  ],
                  'is_online': true,
                  'pending_sync_count': 0,
                },
              },
            ),
          );
        },
      ),
    );

    final summary = await ApiDashboardRepository(dio).getSummary();

    expect(request?.path, '/dashboard/summary');
    expect(summary.kpi.activeInboundCount, 4);
    expect(summary.kpi.pendingTransferCount, 3);
    expect(summary.tasks.single.progressTotal, 5);
    expect(summary.toJson(), isNot(contains('shift_name')));
  });

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
      ProviderScope(
        overrides: [
          dashboardDataSourceProvider.overrideWithValue(
            MockDashboardRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('Buka Kamera Scanner'), findsOneWidget);
    expect(find.text('INBOUND AKTIF'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsWidgets);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Tugas Lapangan Hari Ini'), findsOneWidget);

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

  testWidgets('scanner button offers quick access to inbound, outbound, scan', (
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

    await tester.tap(find.byTooltip('Akses cepat'));
    await tester.pumpAndSettle();

    expect(find.text('Akses Cepat'), findsOneWidget);
    await tester.tap(find.text('Daftar Inbound'));
    await tester.pumpAndSettle();
    expect(find.text('Inbound destination'), findsOneWidget);

    await tester.tap(find.byTooltip('Akses cepat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daftar Outbound'));
    await tester.pumpAndSettle();
    expect(find.text('Outbound destination'), findsOneWidget);

    await tester.tap(find.byTooltip('Akses cepat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka Scanner'));
    await tester.pumpAndSettle();
    expect(find.text('Scanner destination'), findsOneWidget);
  });
}
