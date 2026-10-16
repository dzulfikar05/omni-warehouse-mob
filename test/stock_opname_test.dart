import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/core/theme/app_theme.dart';
import 'package:omni_warehouse_mob/features/stock_opname/opname_list_screen.dart';
import 'package:omni_warehouse_mob/features/stock_opname/opname_model.dart';
import 'package:omni_warehouse_mob/features/stock_opname/opname_repository.dart';
import 'package:omni_warehouse_mob/features/stock_opname/opname_scanner_screen.dart';

void main() {
  group('OpnameNotifier & State Management', () {
    test('initial state has active sessions and calculates stats correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sessions = container.read(opnameRepositoryProvider);
      final stats = container.read(opnameStatsProvider);

      expect(sessions.isNotEmpty, true);
      expect(stats.activeSessions, sessions.where((s) => s.status == OpnameSessionStatus.active).length);
    });

    test('updateItemPhysicalCount updates physicalQty and calculates variance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(opnameRepositoryProvider.notifier);
      final session = container.read(opnameRepositoryProvider).first;
      final targetItem = session.items.firstWhere((it) => it.physicalQty == null);

      notifier.updateItemPhysicalCount(
        sessionCode: session.sessionCode,
        itemId: targetItem.id,
        physicalQty: targetItem.systemQty,
      );

      final updatedSession = container.read(opnameRepositoryProvider.notifier).getSessionByCode(session.sessionCode)!;
      final updatedItem = updatedSession.items.firstWhere((it) => it.id == targetItem.id);

      expect(updatedItem.physicalQty, targetItem.systemQty);
      expect(updatedItem.variance, 0);
      expect(updatedItem.status, ItemOpnameStatus.match);
    });

    test('submitSessionForReconciliation marks session as reconciling', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(opnameRepositoryProvider.notifier);
      final session = container.read(opnameRepositoryProvider).first;

      notifier.submitSessionForReconciliation(session.sessionCode);

      final updated = container.read(opnameRepositoryProvider.notifier).getSessionByCode(session.sessionCode)!;
      expect(updated.status, OpnameSessionStatus.reconciling);
    });
  });

  group('OpnameListScreen Widget Tests', () {
    testWidgets('renders white header, stats summary, and session cards in primary blue theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const OpnameListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header & stats
      expect(find.text('Stock Opname & Audit Fisik'), findsOneWidget);
      expect(find.text('Sesi Aktif'), findsOneWidget);
      expect(find.text('Item Dihitung'), findsOneWidget);
      expect(find.text('Selisih Fisik'), findsOneWidget);

      // Check action buttons
      expect(find.text('Hitung Sesi Aktif'), findsOneWidget);
      expect(find.text('+ Opname Mandiri'), findsOneWidget);

      // Check cards
      expect(find.text('SOP-2026-1001'), findsOneWidget);
      expect(find.text('SOP-2026-1002'), findsOneWidget);
    });

    testWidgets('filtering by status updates visible sessions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const OpnameListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'Aktif Menghitung' chip
      await tester.tap(find.text('Aktif Menghitung'));
      await tester.pumpAndSettle();

      expect(find.text('SOP-2026-1001'), findsOneWidget);
      // Completed session should be hidden
      expect(find.text('SOP-2026-0925'), findsNothing);
    });
  });

  group('OpnameScannerScreen Widget Tests', () {
    testWidgets('renders session header, items, and opens count sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const OpnameScannerScreen(sessionCode: 'SOP-2026-1001'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check header
      expect(find.text('SOP-2026-1001'), findsOneWidget);

      // Tap on item to count
      await tester.tap(find.text('SKU-EL-091'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Modal count sheet should be open
      expect(find.text('JUMLAH FISIK DI RAK'), findsOneWidget);
      expect(find.text('Simpan Hasil Hitung Fisik'), findsOneWidget);

      // Tap save
      await tester.tap(find.text('Simpan Hasil Hitung Fisik'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Modal should be closed
      expect(find.text('JUMLAH FISIK DI RAK'), findsNothing);
    });
  });
}
