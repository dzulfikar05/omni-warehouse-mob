import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'stock_opname_model.dart';
import 'stock_opname_repository.dart';

class StockOpnameScreen extends ConsumerWidget {
  const StockOpnameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(stockOpnameRepositoryProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Stock Opname'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Muat ulang sesi',
            onPressed: () => ref
                .read(stockOpnameRepositoryProvider.notifier)
                .loadActiveSession(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: sessionState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _MessageState(
              icon: Icons.error_outline_rounded,
              message: error.toString(),
              actionLabel: 'Coba lagi',
              onAction: () => ref
                  .read(stockOpnameRepositoryProvider.notifier)
                  .loadActiveSession(),
            ),
            data: (session) => session == null
                ? const _MessageState(
                    icon: Icons.inventory_2_outlined,
                    message: 'Tidak ada sesi stock opname aktif.',
                  )
                : _ActiveSessionView(session: session),
          ),
        ),
      ),
    );
  }
}

class _ActiveSessionView extends StatelessWidget {
  const _ActiveSessionView({required this.session});

  final StockOpnameSession session;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _SessionHeader(session: session),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryBorder),
        ),
        child: const Row(
          children: [
            Icon(Icons.visibility_off_outlined, color: AppColors.primary),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Blind count aktif. Stok sistem disembunyikan saat penghitungan.',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Text(
        'ITEM OPNAME (${session.items.length})',
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
      const SizedBox(height: 8),
      if (session.items.isEmpty)
        const _EmptyItemsCard()
      else
        ...session.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _OpnameItemTile(item: item),
          ),
        ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: session.isInReview
            ? null
            : () => context.push('/more/opname/${session.sessionCode}'),
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Mulai hitung dengan scanner'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: AppColors.primary,
        ),
      ),
    ],
  );
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session});

  final StockOpnameSession session;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SESI OPNAME AKTIF',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          session.sessionCode,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'RobotoMono',
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _InfoLine(label: 'Gudang', value: session.warehouse),
        const SizedBox(height: 5),
        _InfoLine(label: 'Zona', value: session.zone),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                '${session.countedItems}/${session.items.length} item dihitung',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${(session.progress * 100).round()}%',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: session.progress,
            minHeight: 6,
            backgroundColor: AppColors.surfaceAlt,
            color: AppColors.primary,
          ),
        ),
      ],
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 62,
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ),
      Expanded(
        child: Text(
          value.isEmpty ? '-' : value,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _OpnameItemTile extends StatelessWidget {
  const _OpnameItemTile({required this.item});

  final StockOpnameItem item;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.inventory_2_outlined,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.sku,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'RobotoMono',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.name,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Rak: ${item.targetRack.isEmpty ? '-' : item.targetRack}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Text(
          item.physicalQty == null ? 'Belum dihitung' : '${item.physicalQty}',
          style: TextStyle(
            color: item.physicalQty == null
                ? AppColors.textMuted
                : AppColors.success,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _EmptyItemsCard extends StatelessWidget {
  const _EmptyItemsCard();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Text(
        'Belum ada SKU pada sesi ini.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}
