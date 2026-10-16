import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/features/notifications/notification_repository.dart';
import 'package:omni_warehouse_mob/features/notifications/notifications_screen.dart';

void main() {
  testWidgets('NotificationsScreen renders UI exactly matching reference design', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: NotificationsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Header Elements
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    // 2. Verify Speech Bubble Tooltip in Bright Blue (AppColors.primary)
    expect(find.text('Customize your notifications!'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    final tooltipContainer = tester.widget<Container>(
      find.ancestor(
        of: find.text('Customize your notifications!'),
        matching: find.byType(Container),
      ).first,
    );
    final decoration = tooltipContainer.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFF2563EB)); // AppColors.primary (Biru Cerah)

    // 3. Verify Section Header
    expect(find.text('Previously'), findsOneWidget);

    // 4. Verify Cards Content from Initial Mock Data
    expect(find.textContaining('Inbound PO-2026-1040'), findsWidgets);
    expect(find.textContaining('Prioritas Picking SO-2025-1102'), findsWidgets);
    expect(find.textContaining('10 mnt lalu'), findsOneWidget);
    expect(find.textContaining('1 jam lalu'), findsOneWidget);
    expect(find.textContaining('Kemarin'), findsOneWidget);

    // 5. Verify Footer Link
    expect(find.text('Missing notifications?'), findsOneWidget);
    expect(find.text('Go to historical notifications.'), findsOneWidget);
  });

  testWidgets('Tapping notification card opens detail bottom sheet and marks as read', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: NotificationsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // First item is initially unread
    final initialFirst = container.read(notificationProvider).items.first;
    expect(initialFirst.isRead, isFalse);

    // Tap the first notification card
    await tester.tap(find.textContaining('Inbound PO-2026-1040').first);
    await tester.pumpAndSettle();

    // Detail bottom sheet should open with detail metadata & action CTA
    expect(find.text('Buka Scanner Validasi PO'), findsOneWidget);
    expect(find.text('Nomor PO'), findsOneWidget);
    expect(find.text('PO-2026-1040'), findsOneWidget);
    expect(find.text('Tutup'), findsOneWidget);

    // Close detail sheet
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    // First item is now marked as read
    final updatedFirst = container.read(notificationProvider).items.first;
    expect(updatedFirst.isRead, isTrue);
  });

  testWidgets('Tapping gear icon or tooltip opens notification settings sheet', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: NotificationsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap gear settings icon
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // Settings sheet should appear
    expect(find.text('Notification Settings'), findsOneWidget);
    expect(find.text('Tugas Lapangan Baru (PO & SO)'), findsOneWidget);
    expect(find.text('Peringatan Selisih & Stok Kritis'), findsOneWidget);
    expect(find.text('Suara Notifikasi & Haptic Beep'), findsOneWidget);

    // Dismiss settings
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();

    expect(find.text('Notification Settings'), findsNothing);
  });
}
