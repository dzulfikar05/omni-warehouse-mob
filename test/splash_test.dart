import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_warehouse_mob/features/splash/splash_screen.dart';

void main() {
  testWidgets('SplashScreen renders clean logo on bright blue and navigates on tap', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Home Destination')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // Initial frame
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);

    // Forward through entrance animation
    await tester.pump(const Duration(milliseconds: 2200));

    expect(find.text('OmniWarehouse'), findsOneWidget);
    expect(find.text('WMS ENTERPRISE'), findsOneWidget);

    // Tap to proceed
    await tester.tap(find.byType(SplashScreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Home Destination'), findsOneWidget);
  });
}
