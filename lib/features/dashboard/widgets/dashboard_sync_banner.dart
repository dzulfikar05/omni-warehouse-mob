import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';

class DashboardSyncBanner extends StatelessWidget {
  const DashboardSyncBanner({
    super.key,
    required this.pendingSyncCount,
    required this.isSyncing,
    required this.hasSynced,
    required this.onSync,
    this.onSimulateOfflineDraft,
  });

  final int pendingSyncCount;
  final bool isSyncing;
  final bool hasSynced;
  final VoidCallback onSync;
  final VoidCallback? onSimulateOfflineDraft;

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingSyncCount > 0 && !hasSynced;

    final bgColor = hasPending ? AppColors.warningLight : AppColors.surface;
    final borderColor = hasPending ? AppColors.warningBorder : AppColors.border;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
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
          // 1. Squircle Status Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: hasPending
                  ? AppColors.warning.withValues(alpha: 0.15)
                  : AppColors.successLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasPending
                    ? AppColors.warningBorder
                    : AppColors.successBorder,
              ),
            ),
            child: Center(
              child: Icon(
                hasPending ? LucideIcons.cloudAlert : LucideIcons.database,
                size: 18,
                color: hasPending ? AppColors.warning : AppColors.success,
              ),
            ),
          ),
          const Gap(10),

          // 2. Center Content: Tappable area leading to /more/sync
          Expanded(
            child: InkWell(
              onTap: () => context.push('/more/sync'),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            hasPending
                                ? 'Antrean Isar Offline'
                                : 'Mesin Offline Isar DB',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Gap(6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: hasPending
                                ? const Color(0xFFFEF3C7)
                                : AppColors.successLight,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: hasPending
                                  ? const Color(0xFFFDE68A)
                                  : AppColors.successBorder,
                            ),
                          ),
                          child: Text(
                            hasPending
                                ? '$pendingSyncCount PENDING'
                                : 'AKTIF',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'RobotoMono',
                              color: hasPending
                                  ? const Color(0xFF92400E)
                                  : AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hasPending
                                ? '$pendingSyncCount transaksi tertahan • Ketuk detail'
                                : 'Database lokal sinkron • Ketuk antrean',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const Icon(
                          LucideIcons.chevronRight,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Gap(8),

          // 3. Compact 40px Touch-Target Sync Button
          InkWell(
            onTap: isSyncing ? null : onSync,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: hasPending ? AppColors.warning : AppColors.primary,
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
                  if (isSyncing)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(
                      LucideIcons.refreshCw,
                      size: 14,
                      color: Colors.white,
                    ),
                  const Gap(6),
                  Text(
                    isSyncing ? 'Sync...' : 'Sync',
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

          // 4. Quick Demo Simulation Button (optional)
          if (onSimulateOfflineDraft != null) ...[
            const Gap(6),
            InkWell(
              onTap: onSimulateOfflineDraft,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 40,
                width: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.plus,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
