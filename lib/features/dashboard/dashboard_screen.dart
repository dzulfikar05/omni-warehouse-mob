import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../core/theme/app_colors.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/offline/offline_db.dart';
import '../../core/offline/offline_identity.dart';
import '../../core/offline/sync_manager.dart';
import '../../shared/widgets/omni_app_bar.dart';
import '../../shared/widgets/omni_snackbar.dart';
import 'dashboard_repository.dart';
import '../inbound/inbound_repository.dart';
import '../outbound/outbound_repository.dart';
import '../stock_opname/stock_opname_repository.dart';
import 'widgets/dashboard_hero_scan_card.dart';
import 'widgets/dashboard_kpi_grid.dart';
import 'widgets/dashboard_shift_strip.dart';
import 'widgets/dashboard_sync_banner.dart';
import 'widgets/dashboard_task_section.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isSyncing = false;
  bool _hasSynced = false;
  int? _localOfflineQueueCount;

  int get _offlineQueueCount => _localOfflineQueueCount ?? 0;
  set _offlineQueueCount(int val) => _localOfflineQueueCount = val;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshQueueCount());
  }

  Future<void> _refreshQueueCount() async {
    final auth = ref.read(authProvider);
    if (auth.tenantSlug == null || auth.token == null) return;
    try {
      final inboundCount = await OfflineDb.countInboundQueue(
        tenantSlug: auth.tenantSlug!,
        ownerKey: offlineOwnerKey(userId: auth.userId, token: auth.token!),
      );
      final outboundCount = await OfflineDb.countOutboundQueue(
        tenantSlug: auth.tenantSlug!,
        ownerKey: offlineOwnerKey(userId: auth.userId, token: auth.token!),
      );
      final transferCount = await OfflineDb.countTransferQueue(
        tenantSlug: auth.tenantSlug!,
        ownerKey: offlineOwnerKey(userId: auth.userId, token: auth.token!),
      );
      final opnameCount = await OfflineDb.countOpnameQueue(
        tenantSlug: auth.tenantSlug!,
        ownerKey: offlineOwnerKey(userId: auth.userId, token: auth.token!),
      );
      if (mounted) {
        setState(
          () => _offlineQueueCount =
              inboundCount + outboundCount + transferCount + opnameCount,
        );
      }
    } catch (error) {
      if (mounted) {
        OmniSnackbar.show(
          context,
          message: 'Gagal membaca antrean SQLite: $error',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  Future<void> _handleSync() async {
    final auth = ref.read(authProvider);
    if (auth.tenantSlug == null || auth.token == null) return;
    setState(() => _isSyncing = true);
    try {
      final ownerKey = offlineOwnerKey(userId: auth.userId, token: auth.token!);
      final result = await SyncManager.instance.syncAllQueues(
        dio: ref.read(dioProvider),
        tenantSlug: auth.tenantSlug!,
        ownerKey: ownerKey,
        authToken: auth.token!,
      );
      if (result.syncedCount == 0 && result.failureCount == 0) {
        if (mounted) {
          setState(() => _offlineQueueCount = 0);
          OmniSnackbar.show(
            context,
            message: 'Tidak ada transaksi yang menunggu sync.',
            icon: LucideIcons.cloudCheck,
          );
        }
        return;
      }
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
      await _refreshQueueCount();
      if (!mounted) return;
      setState(() => _hasSynced = result.failureCount == 0);
      OmniSnackbar.show(
        context,
        message: result.failureCount == 0
            ? '${result.syncedCount} transaksi berhasil disinkronkan.'
            : '${result.syncedCount} berhasil, ${result.failureCount} gagal. Buka antrean untuk detail.',
        icon: result.failureCount == 0
            ? LucideIcons.cloudCheck
            : Icons.error_outline_rounded,
      );
    } catch (error) {
      if (mounted) {
        OmniSnackbar.show(
          context,
          message: 'Sinkronisasi gagal: $error',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardNotifierProvider);
    final summary = dashboardState.summary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const OmniAppBar(),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardNotifierProvider.notifier).refresh(),
        color: AppColors.primary,
        backgroundColor: Colors.white,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                // 1. Error Banner
                if (dashboardState.errorMessage != null &&
                    !dashboardState.isLoading)
                  _buildErrorBanner(dashboardState.errorMessage!),

                // 2. Mesin Offline & Sync Hub (Fitur Unggulan WMS)
                DashboardSyncBanner(
                  pendingSyncCount: _offlineQueueCount,
                  isSyncing: _isSyncing,
                  hasSynced: _hasSynced,
                  onSync: _handleSync,
                ),
                const Gap(14),

                // 3. Hero Card Barcode Scanner
                const DashboardHeroScanCard(),
                const Gap(14),

                // 4. Industrial Mini KPI Chips (2x2 Grid)
                Skeletonizer(
                  enabled: dashboardState.isLoading,
                  child: DashboardKpiGrid(kpi: summary.kpi),
                ),
                const Gap(14),

                // 5. Antrean Tugas Lapangan Hari Ini
                Skeletonizer(
                  enabled: dashboardState.isLoading,
                  child: DashboardTaskSection(tasks: summary.tasks),
                ),
                const Gap(14),

                // 6. Strip Shift & SLA Performance
                DashboardShiftStrip(shiftName: summary.shiftName),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dangerBorder),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.alertTriangle,
            color: AppColors.danger,
            size: 20,
          ),
          const Gap(10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Gap(8),
          TextButton(
            onPressed: () =>
                ref.read(dashboardNotifierProvider.notifier).refresh(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Coba Lagi',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
