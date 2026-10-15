import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/core/router/app_router.dart';

void main() {
  testWidgets('demo login enters dashboard without a real password', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, child) =>
              MaterialApp.router(routerConfig: ref.watch(appRouterProvider)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Masuk dengan Akun Operator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify Tenant'));
    await tester.pumpAndSettle();

    expect(find.text('Tenant Demo'), findsOneWidget);
    await tester.ensureVisible(find.text('Masuk ke Dashboard Demo'));
    await tester.tap(find.text('Masuk ke Dashboard Demo'));
    await tester.pumpAndSettle();

    expect(find.text('Tugas Lapangan Hari Ini'), findsOneWidget);
    expect(find.text('PO IN'), findsOneWidget);
    expect(find.text('SO OUT'), findsOneWidget);
  });
}
