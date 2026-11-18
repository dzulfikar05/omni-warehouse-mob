import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_provider.dart';
import 'core/config/app_config.dart';
import 'core/offline/offline_db.dart';
import 'core/offline/offline_identity.dart';
import 'core/offline/sync_manager.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/inbound/inbound_repository.dart';
import 'features/outbound/outbound_repository.dart';
import 'features/stock_opname/stock_opname_repository.dart';
import 'shared/utils/connectivity_checker.dart';
import 'shared/widgets/omni_snackbar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment config (.env)
  await AppConfig.init();

  // Init offline storage
  await OfflineDb.init();

  runApp(const ProviderScope(child: OmniWarehouseApp()));
}

class OmniWarehouseApp extends ConsumerStatefulWidget {
  const OmniWarehouseApp({super.key});

  @override
  ConsumerState<OmniWarehouseApp> createState() => _OmniWarehouseAppState();
}

class _OmniWarehouseAppState extends ConsumerState<OmniWarehouseApp> {
  StreamSubscription<bool>? _connectivitySubscription;
  bool? _wasOnline;
  bool _isAutoSyncing = false;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription =
        ConnectivityChecker.instance.onlineChanges.listen(_handleConnectivity);
    ConnectivityChecker.instance.isOnline().then(_handleConnectivity);
    // Initialize auth state dari secure storage saat app start
    Future.microtask(() {
      ref.read(authProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _handleConnectivity(bool online) {
    final wasOnline = _wasOnline;
    _wasOnline = online;
    if (online && wasOnline != true) _syncOfflineQueues();
  }

  Future<void> _syncOfflineQueues() async {
    if (_isAutoSyncing ||
        !await SyncManager.instance.shouldSyncAutomatically()) {
      return;
    }
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.tenantSlug == null) return;

    final tenantSlug = auth.tenantSlug!;
    final ownerKey = offlineOwnerKey(userId: auth.userId, token: auth.token!);
    _isAutoSyncing = true;
    try {
      final result = await SyncManager.instance.syncAllQueues(
        dio: ref.read(dioProvider),
        tenantSlug: tenantSlug,
        ownerKey: ownerKey,
        authToken: auth.token!,
      );
      if (result.inboundSyncedCount > 0) {
        await ref.read(inboundRepositoryProvider.notifier).loadManifests();
      }
      if (result.outboundSyncedCount > 0) {
        await ref.read(outboundRepositoryProvider.notifier).loadManifests();
      }
      if (result.opnameSyncedCount > 0) {
        await ref
            .read(stockOpnameRepositoryProvider.notifier)
            .loadActiveSession();
      }
      if (mounted && result.failureCount > 0) {
        OmniSnackbar.show(
          context,
          message:
              '${result.syncedCount} transaksi tersinkron; ${result.failureCount} perlu dicoba ulang.',
          icon: Icons.error_outline_rounded,
        );
      }
    } on DioException catch (error) {
      if (mounted) {
        OmniSnackbar.show(
          context,
          message: error.message ?? 'Sinkronisasi otomatis gagal.',
          icon: Icons.error_outline_rounded,
        );
      }
    } catch (error) {
      if (mounted) {
        OmniSnackbar.show(
          context,
          message: 'Sinkronisasi otomatis gagal: $error',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      _isAutoSyncing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.isAuthenticated && previous?.isAuthenticated != true) {
        ConnectivityChecker.instance.isOnline().then((online) {
          if (online) _syncOfflineQueues();
        });
      }
    });
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'OmniWarehouse',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
