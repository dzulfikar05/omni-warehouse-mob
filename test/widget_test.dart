import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omni_warehouse_mob/features/auth/home_screen.dart';
import 'package:omni_warehouse_mob/features/auth/login_step1_screen.dart';
import 'package:omni_warehouse_mob/features/auth/login_step2_screen.dart';

void main() {
  testWidgets('home screen shows intro and CTA', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('OmniWarehouse Ecosystem'), findsOneWidget);
    expect(find.text('Aplikasi Handheld WMS'), findsOneWidget);
    expect(find.text('Masuk dengan Akun Operator'), findsOneWidget);
  });

  testWidgets('tenant screen shows tenant form fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginStep1Screen()));

    expect(find.text('Login Operator Gudang'), findsOneWidget);
    expect(find.text('Workspace Tenant ID'), findsOneWidget);
    expect(find.text('Verify Tenant'), findsOneWidget);
  });

  testWidgets('credentials screen shows login fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginStep2Screen()));

    expect(find.text('Login Operator Gudang'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Masuk ke Dashboard Demo'), findsOneWidget);
  });
}
