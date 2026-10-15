import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/omni_app_bar.dart';
import '../../shared/widgets/omni_snackbar.dart';
import '../../shared/widgets/omni_status_badge.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _offlineQueueCount = 3;
  bool _isSyncing = false;
  bool _hasSynced = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const OmniAppBar(),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              // 1. Offline Queue Notice / Isar Local Cache Strip
              _buildSyncBanner(),
              const SizedBox(height: 14),

              // 2. Hero Card Scan-Centric (CTA Utama Operator Lantai Gudang)
              _buildHeroScanCard(context),
              const SizedBox(height: 14),

              // 3. Industrial Mini KPI Chips (4 Grid Taktikal)
              _buildMiniKpiGrid(),
              const SizedBox(height: 14),

              // 4. Daftar Tugas Lapangan Hari Ini (Actionable Tasks)
              _buildTasksSection(context),
              const SizedBox(height: 14),

              // 5. Shift & SLA Performance Strip
              _buildShiftPerformanceStrip(),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Offline Queue Notice / Isar Local Cache Strip
  Widget _buildSyncBanner() {
    if (_hasSynced && _offlineQueueCount == 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.successBorder),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.successBorder),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sinkronisasi Isar Selesai',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Semua data terkirim ke backend Laravel',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const OmniStatusBadge(
              label: 'TERVERIFIKASI',
              variant: OmniBadgeVariant.success,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warningBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warningBorder),
            ),
            child: const Icon(
              Icons.cloud_sync_rounded,
              color: AppColors.warning,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => context.push('/more/sync'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              const Text(
                                'Antrean Isar Offline',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDE68A),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$_offlineQueueCount PENDING',
                                  style: const TextStyle(
                                    color: Color(0xFF78350F),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'RobotoMono',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '$_offlineQueueCount data transaksi • Ketuk untuk detail',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
          ),
          InkWell(
            onTap: _isSyncing
                ? null
                : () async {
                    setState(() => _isSyncing = true);
                    await Future.delayed(const Duration(milliseconds: 900));
                    if (mounted) {
                      setState(() {
                        _isSyncing = false;
                        _hasSynced = true;
                        _offlineQueueCount = 0;
                      });
                      OmniSnackbar.show(
                        context,
                        message: '3 Berkas berhasil disinkronkan ke server!',
                        icon: Icons.cloud_done_rounded,
                      );
                    }
                  },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSyncing)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.sync_rounded, size: 15, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    _isSyncing ? 'Syncing...' : 'Sync',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Hero Card Scan-Centric (CTA Utama Operator Lantai Gudang)
  Widget _buildHeroScanCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E40AF),
            AppColors.primary,
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Watermark Icon
          Positioned(
            right: 8,
            top: 4,
            child: Icon(
              Icons.qr_code_scanner_rounded,
              size: 96,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Badge & Version
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF34D399),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'GENERIC SCANNER READY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'RobotoMono',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'v2.4-mobile',
                      style: TextStyle(
                        color: Color(0xFFDBEAFE),
                        fontSize: 11,
                        fontFamily: 'RobotoMono',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Heading & Subtitle
                const Text(
                  'Pindai Barcode Transaksi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Arahkan scanner ke Dokumen PO, SO Outbound, Pallet, atau Rak',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 14),

                // Thumb-Friendly CTA (52px height sesuai guide)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => context.go('/scanner'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.center_focus_strong_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Buka Kamera Scanner',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. Industrial Mini KPI Chips (4 Grid Taktikal)
  Widget _buildMiniKpiGrid() {
    return Row(
      children: [
        _buildKpiCard(
          title: 'PO IN',
          value: '4',
          subtext: '1 Recv',
          icon: Icons.inbox_rounded,
          color: AppColors.warning,
        ),
        const SizedBox(width: 8),
        _buildKpiCard(
          title: 'SO OUT',
          value: '8',
          subtext: 'Siap Pick',
          icon: Icons.outbox_rounded,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        _buildKpiCard(
          title: 'DEFISIT',
          value: '2',
          subtext: 'Cek Fisik',
          icon: Icons.warning_rounded,
          color: AppColors.danger,
          isDangerSubtext: true,
        ),
        const SizedBox(width: 8),
        _buildKpiCard(
          title: 'ISAR DB',
          value: _offlineQueueCount.toString(),
          subtext: 'Pending',
          icon: Icons.sync_rounded,
          color: AppColors.warning,
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    bool isDangerSubtext = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'RobotoMono',
                    color: AppColors.textSecondary,
                  ),
                ),
                Icon(icon, size: 14, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFamily: 'RobotoMono',
                color: color,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtext,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isDangerSubtext ? FontWeight.w700 : FontWeight.w500,
                color: isDangerSubtext ? AppColors.danger : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 4. Daftar Tugas Lapangan Hari Ini (Actionable Tasks)
  Widget _buildTasksSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tugas Lapangan Hari Ini',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                '4 Antrean Aktif',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'RobotoMono',
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // TASK 1: INBOUND RECEIVING
        _buildTaskCard(
          badgeLabel: 'RECEIVING',
          badgeVariant: OmniBadgeVariant.warning,
          code: 'PO-2025-0891',
          title: 'PT Indah Logistik Mandiri',
          subtitle: 'Inbound Pallet • Dock Bay 04',
          subIcon: Icons.warehouse_outlined,
          rightIcon: Icons.inbox_rounded,
          rightIconColor: AppColors.warning,
          rightIconBg: AppColors.warningLight,
          rightIconBorder: AppColors.warningBorder,
          progressTitle: 'Progres Bongkar Muat',
          progressCount: '170 / 250 unit',
          progressPercent: 0.68,
          progressColor: AppColors.warning,
          buttonText: 'Lokasi Scan PO & Putaway',
          onAction: () {
            _showTaskDetailModal(
              context,
              typeBadge: 'INBOUND PUTAWAY',
              code: 'PO-2025-0891',
              target: 'PT Indah Logistik Mandiri',
              location: 'Dock Bay 04',
              progress: '170 / 250 unit',
            );
          },
        ),
        const SizedBox(height: 10),

        // TASK 2: OUTBOUND PICKING
        _buildTaskCard(
          badgeLabel: 'PICKING',
          badgeVariant: OmniBadgeVariant.primary,
          code: 'SO-2025-1102',
          title: 'Toko Berkah Retail Jaya',
          subtitle: 'Dispatch Reguler • Staging S-01',
          subIcon: Icons.local_shipping_outlined,
          rightIcon: Icons.outbox_rounded,
          rightIconColor: AppColors.primary,
          rightIconBg: AppColors.primaryLight,
          rightIconBorder: AppColors.primaryBorder,
          progressTitle: 'Pengambilan SKU',
          progressCount: '15 / 50 SKU',
          progressPercent: 0.30,
          progressColor: AppColors.primary,
          buttonText: 'Pick & Konfirmasi Item',
          onAction: () {
            _showTaskDetailModal(
              context,
              typeBadge: 'OUTBOUND PICKING',
              code: 'SO-2025-1102',
              target: 'Toko Berkah Retail Jaya',
              location: 'Staging S-01',
              progress: '15 / 50 SKU',
            );
          },
        ),
      ],
    );
  }

  Widget _buildTaskCard({
    required String badgeLabel,
    required OmniBadgeVariant badgeVariant,
    required String code,
    required String title,
    required String subtitle,
    required IconData subIcon,
    required IconData rightIcon,
    required Color rightIconColor,
    required Color rightIconBg,
    required Color rightIconBorder,
    required String progressTitle,
    required String progressCount,
    required double progressPercent,
    required Color progressColor,
    required String buttonText,
    required VoidCallback onAction,
  }) {
    final percentInt = (progressPercent * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        OmniStatusBadge(
                          label: badgeLabel,
                          variant: badgeVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          code,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'RobotoMono',
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(subIcon, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: rightIconBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: rightIconBorder),
                ),
                child: Icon(rightIcon, size: 18, color: rightIconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        progressTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'RobotoMono',
                          color: AppColors.textPrimary,
                        ),
                        children: [
                          TextSpan(text: '$progressCount '),
                          TextSpan(
                            text: '($percentInt%)',
                            style: TextStyle(color: progressColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Action Button (height 44)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surfaceAlt,
                side: const BorderSide(color: AppColors.border),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 5. Shift & SLA Performance Strip
  Widget _buildShiftPerformanceStrip() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Shift 1 Pagi (08:00 - 16:00)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.successBorder),
                      ),
                      child: const Text(
                        'Sisa 3j 45m',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'RobotoMono',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'SLA Dispatch Lapangan 94% • On-Track',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Task Execution Detail BottomSheet/Modal
  void _showTaskDetailModal(
    BuildContext context, {
    required String typeBadge,
    required String code,
    required String target,
    required String location,
    required String progress,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OmniStatusBadge(
                      label: typeBadge,
                      variant: typeBadge.contains('PUTAWAY') || typeBadge.contains('RECEIVING')
                          ? OmniBadgeVariant.warning
                          : OmniBadgeVariant.primary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'RobotoMono',
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),

            _buildDetailRow('Entitas Transaksi', target),
            _buildDetailRow('Lokasi Kerja / Bay', location, isMono: true),
            _buildDetailRow('Unit / Qty Terverifikasi', progress, isMono: true, isHighlight: true),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        setState(() {
                          _offlineQueueCount++;
                          _hasSynced = false;
                        });
                        OmniSnackbar.show(
                          context,
                          message: 'Tersimpan di antrean Isar lokal (Offline Ready)',
                          icon: Icons.save_outlined,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceAlt,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Simpan ke Isar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        OmniSnackbar.show(
                          context,
                          message: 'Transaksi berhasil dikonfirmasi ke DB!',
                          icon: Icons.verified_rounded,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Komit Transaksi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMono = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: isMono ? 'RobotoMono' : null,
              color: isHighlight ? AppColors.warning : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
