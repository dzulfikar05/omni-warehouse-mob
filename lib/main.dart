import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_provider.dart';
import 'core/offline/offline_db.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init offline storage
  await OfflineDb.init();

  runApp(
    const ProviderScope(child: OmniWarehouseApp()),
  );
}

class OmniWarehouseApp extends ConsumerStatefulWidget {
  const OmniWarehouseApp({super.key});

  @override
  ConsumerState<OmniWarehouseApp> createState() => _OmniWarehouseAppState();
}

class _OmniWarehouseAppState extends ConsumerState<OmniWarehouseApp> {
  @override
  void initState() {
    super.initState();
    // Initialize auth state dari secure storage saat app start
    Future.microtask(() {
      ref.read(authProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'OmniWarehouse',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
