import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/omni_snackbar.dart';
import '../../../shared/widgets/omni_status_badge.dart';
import '../dashboard_model.dart';

class DashboardTaskSection extends StatelessWidget {
  const DashboardTaskSection({
    super.key,
    required this.tasks,
    required this.onDraftSaved,
  });

  final List<DashboardTaskItem> tasks;
  final VoidCallback onDraftSaved;

  @override
  Widget build(BuildContext context) {
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
                  const Gap(8),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '${tasks.length} Antrean Aktif',
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'RobotoMono',
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const Gap(10),

        if (tasks.isEmpty)
          const _EmptyTasksState()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            separatorBuilder: (ctx, i) => const Gap(10),
            itemBuilder: (ctx, i) {
              final task = tasks[i];
              return _TaskCard(
                task: task,
                onTapAction: () => _showTaskDetailModal(context, task),
              );
            },
          ),
      ],
    );
  }

  void _showTaskDetailModal(BuildContext context, DashboardTaskItem task) {
    final badgeVariant = _resolveBadgeVariant(task);

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
            const Gap(14),

            // Top Row: Status Badge & Code (Anti-Overflow with Expanded)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OmniStatusBadge(
                        label: task.badgeLabel,
                        variant: badgeVariant,
                      ),
                      const Gap(6),
                      Text(
                        task.code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'RobotoMono',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(8),
                IconButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                  icon: const Icon(LucideIcons.x, color: AppColors.textSecondary),
                ),
              ],
            ),
            const Gap(12),
            const Divider(color: Color(0xFFF1F5F9)),
            const Gap(8),

            _buildDetailRow('Entitas / Mitra', task.title),
            _buildDetailRow('Lokasi Kerja / Bay', task.location, isMono: true),
            _buildDetailRow(
              'Kuantitas / SKU',
              '${task.progressCurrent} / ${task.progressTotal} unit',
              isMono: true,
              isHighlight: !task.isCompleted,
            ),
            const Gap(20),

            // Action Buttons: Adaptive based on completion status
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        if (!task.isCompleted) {
                          onDraftSaved();
                          OmniSnackbar.show(
                            context,
                            message: 'Disimpan ke antrean draf lokal',
                            icon: LucideIcons.bookmarkCheck,
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceAlt,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        task.isCompleted ? 'Tutup' : 'Simpan Draf',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        if (task.route.isNotEmpty && task.route != '/dashboard') {
                          context.push(task.route);
                        } else {
                          OmniSnackbar.show(
                            context,
                            message: task.isCompleted
                                ? 'Rincian transaksi dimuat'
                                : 'Membuka modul transaksi...',
                            icon: LucideIcons.checkCircle2,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: task.isCompleted
                            ? AppColors.success
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        task.isCompleted ? 'Lihat Rincian' : 'Proses Transaksi',
                        style: const TextStyle(
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

  Widget _buildDetailRow(String label, String value,
      {bool isMono = false, bool isHighlight = false}) {
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
          const Gap(8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: isMono ? 'RobotoMono' : null,
                color: isHighlight ? AppColors.warning : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static OmniBadgeVariant _resolveBadgeVariant(DashboardTaskItem task) {
    if (task.isCompleted) {
      return OmniBadgeVariant.success; // ALWAYS GREEN FOR COMPLETED
    }
    final s = task.status.toLowerCase();
    if (s == 'receiving' || s == 'in_progress') {
      return OmniBadgeVariant.warning; // ORANGE FOR RECEIVING / UNLOADING
    }
    if (s == 'picking' || s == 'packing') {
      return OmniBadgeVariant.primary; // BLUE FOR PICKING
    }
    return OmniBadgeVariant.neutral; // NEUTRAL FOR PENDING / DRAFT
  }
}

class _EmptyTasksState extends StatelessWidget {
  const _EmptyTasksState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(
                LucideIcons.checkCheck,
                color: AppColors.success,
                size: 24,
              ),
            ),
          ),
          const Gap(12),
          const Text(
            'Semua Tugas Selesai',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Gap(4),
          const Text(
            'Tidak ada antrean pending di warehouse saat ini.\nTarik ke bawah untuk memperbarui status.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onTapAction,
  });

  final DashboardTaskItem task;
  final VoidCallback onTapAction;

  @override
  Widget build(BuildContext context) {
    final badgeVariant = DashboardTaskSection._resolveBadgeVariant(task);

    IconData typeIcon;
    Color iconColor;
    Color iconBg;
    Color iconBorder;

    if (task.isCompleted) {
      typeIcon = LucideIcons.checkCircle2;
      iconColor = AppColors.success;
      iconBg = AppColors.successLight;
      iconBorder = AppColors.successBorder;
    } else {
      switch (task.type) {
        case 'inbound':
          typeIcon = LucideIcons.arrowDownToLine;
          iconColor = AppColors.warning;
          iconBg = AppColors.warningLight;
          iconBorder = AppColors.warningBorder;
          break;
        case 'outbound':
          typeIcon = LucideIcons.arrowUpFromLine;
          iconColor = AppColors.primary;
          iconBg = AppColors.primaryLight;
          iconBorder = AppColors.primaryBorder;
          break;
        case 'transfer':
          typeIcon = LucideIcons.arrowLeftRight;
          iconColor = const Color(0xFF6366F1);
          iconBg = const Color(0xFFEEF2FF);
          iconBorder = const Color(0xFFC7D2FE);
          break;
        default:
          typeIcon = LucideIcons.clipboardCheck;
          iconColor = AppColors.success;
          iconBg = AppColors.successLight;
          iconBorder = AppColors.successBorder;
          break;
      }
    }

    final percentInt = (task.progressPercent * 100).toInt();

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
                          label: task.badgeLabel,
                          variant: badgeVariant,
                        ),
                        const Gap(8),
                        Flexible(
                          child: Text(
                            task.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'RobotoMono',
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(6),
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Gap(2),
                    Row(
                      children: [
                        const Icon(LucideIcons.mapPin,
                            size: 13, color: AppColors.textMuted),
                        const Gap(4),
                        Expanded(
                          child: Text(
                            task.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
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
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: iconBorder),
                ),
                child: Center(
                  child: Icon(typeIcon, size: 18, color: iconColor),
                ),
              ),
            ],
          ),
          const Gap(10),

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
                    const Expanded(
                      child: Text(
                        'Realisasi Lapangan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Gap(8),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'RobotoMono',
                          color: AppColors.textPrimary,
                        ),
                        children: [
                          TextSpan(
                              text:
                                  '${task.progressCurrent} / ${task.progressTotal} unit '),
                          TextSpan(
                            text: '($percentInt%)',
                            style: TextStyle(color: iconColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: task.progressPercent,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                  ),
                ),
              ],
            ),
          ),
          const Gap(10),

          // Action Button (min 44px thumb target)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: onTapAction,
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surfaceAlt,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    task.isCompleted
                        ? 'Lihat Rincian Transaksi'
                        : 'Periksa & Proses Transaksi',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: task.isCompleted
                          ? AppColors.textPrimary
                          : AppColors.primary,
                    ),
                  ),
                  const Gap(6),
                  Icon(
                    LucideIcons.arrowRight,
                    size: 14,
                    color: task.isCompleted
                        ? AppColors.textSecondary
                        : AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
