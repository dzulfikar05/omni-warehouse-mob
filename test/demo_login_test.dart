import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/core/router/app_router.dart';

void main() {
  testWidgets('login route alias opens tenant verification', (tester) async {
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
    expect(find.text('Workspace Tenant ID'), findsOneWidget);
    expect(find.text('Verify Tenant'), findsOneWidget);
  });
}
