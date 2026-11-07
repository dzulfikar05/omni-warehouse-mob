import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/omni_app_bar.dart';
import '../../shared/widgets/omni_snackbar.dart';
import 'dashboard_repository.dart';
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

  int get _offlineQueueCount =>
      _localOfflineQueueCount ??
      ref.read(dashboardNotifierProvider).summary.pendingSyncCount;
  set _offlineQueueCount(int val) => _localOfflineQueueCount = val;

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    await ref.read(dashboardNotifierProvider.notifier).syncOfflineQueue();
    if (mounted) {
      setState(() {
        _isSyncing = false;
        _hasSynced = true;
      });
      OmniSnackbar.show(
        context,
        message: 'Data berhasil disinkronkan ke server!',
        icon: LucideIcons.cloudCheck,
      );
    }
  }

  void _handleDraftSaved() {
    setState(() {
      _offlineQueueCount++;
      _hasSynced = false;
    });
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
                  onSimulateOfflineDraft: () {
                    _handleDraftSaved();
                    OmniSnackbar.show(
                      context,
                      message:
                          'Simulasi: 1 Transaksi tertahan di antrean lokal Isar DB',
                      icon: LucideIcons.database,
                    );
                  },
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
                  child: DashboardTaskSection(
                    tasks: summary.tasks,
                    onDraftSaved: _handleDraftSaved,
                  ),
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
