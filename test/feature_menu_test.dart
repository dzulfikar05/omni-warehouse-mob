import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_warehouse_mob/shared/widgets/omni_feature_menu.dart';

void main() {
  testWidgets('feature menu searches and selects on a phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? selectedLocation;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showOmniFeatureMenu(
                    context,
                    onSelect: (location) => selectedLocation = location,
                  ),
                  child: const Text('Open menu'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();

    expect(find.text('Fitur Lainnya'), findsOneWidget);
    expect(find.text('Transfer Stok'), findsOneWidget);
    expect(find.text('Stock Opname'), findsOneWidget);
    expect(find.text('Sinkronisasi Isar'), findsOneWidget);

    await tester.tap(find.text('Transfer Stok'));
    await tester.pumpAndSettle();

    expect(selectedLocation, '/more/transfer');
  });
}
