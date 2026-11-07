import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../dashboard_model.dart';

class DashboardKpiGrid extends StatelessWidget {
  const DashboardKpiGrid({
    super.key,
    required this.kpi,
  });

  final DashboardKpi kpi;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'PO IN',
                value: kpi.activeInboundCount.toString(),
                subtext: 'Barang Masuk',
                icon: LucideIcons.arrowDownToLine,
                color: AppColors.warning,
                onTap: () => context.go('/inbound'),
              ),
            ),
            const Gap(8),
            Expanded(
              child: _KpiCard(
                title: 'SO OUT',
                value: kpi.activeOutboundCount.toString(),
                subtext: 'Siap Pick & Kirim',
                icon: LucideIcons.arrowUpFromLine,
                color: AppColors.primary,
                onTap: () => context.go('/outbound'),
              ),
            ),
          ],
        ),
        const Gap(8),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                title: 'MUTASI RAK',
                value: kpi.pendingTransferCount.toString(),
                subtext: 'Transfer Lokasi',
                icon: LucideIcons.arrowLeftRight,
                color: const Color(0xFF6366F1),
                onTap: () => context.push('/more/transfer'),
              ),
            ),
            const Gap(8),
            Expanded(
              child: _KpiCard(
                title: 'STOK OPNAME',
                value: kpi.activeOpnameCount.toString(),
                subtext: 'Audit Siklus Fisik',
                icon: LucideIcons.clipboardCheck,
                color: AppColors.success,
                onTap: () => context.push('/more/opname'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtext,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtext;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
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
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'RobotoMono',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Icon(icon, size: 13, color: color),
                  ),
                ),
              ],
            ),
            const Gap(6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFamily: 'RobotoMono',
                color: color,
                height: 1.1,
              ),
            ),
            const Gap(3),
            Text(
              subtext,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

