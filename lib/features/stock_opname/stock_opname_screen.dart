import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'stock_opname_model.dart';
import 'stock_opname_repository.dart';

class StockOpnameScreen extends ConsumerStatefulWidget {
  const StockOpnameScreen({super.key});

  @override
  ConsumerState<StockOpnameScreen> createState() => _StockOpnameScreenState();
}

class _StockOpnameScreenState extends ConsumerState<StockOpnameScreen> {
  bool _loadingMore = false;
  String? _loadMoreError;

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() {
      _loadingMore = true;
      _loadMoreError = null;
    });
    final notifier = ref.read(stockOpnameSessionListProvider.notifier);
    await notifier.loadMore();
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      _loadMoreError = notifier.loadMoreError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionsState = ref.watch(stockOpnameSessionListProvider);
    final sessionsNotifier = ref.read(stockOpnameSessionListProvider.notifier);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Stock Opname'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Muat ulang daftar sesi',
            onPressed: sessionsNotifier.loadFirstPage,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: sessionsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ListMessage(
              message: error.toString(),
              onRetry: sessionsNotifier.loadFirstPage,
            ),
            data: (page) => page.sessions.isEmpty
                ? const _ListMessage(message: 'Belum ada sesi stock opname.')
                : RefreshIndicator(
                    onRefresh: sessionsNotifier.loadFirstPage,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          '${page.total} sesi stock opname',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...page.sessions.map(
                          (session) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _SessionCard(
                              session: session,
                              onTap: () => context.push(
                                '/more/opname/${Uri.encodeComponent(session.sessionCode)}'
                                '?session_id=${session.id}',
                              ),
                            ),
                          ),
                        ),
                        if (_loadMoreError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _loadMoreError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (page.hasMore)
                          OutlinedButton(
                            onPressed: _loadingMore ? null : _loadMore,
                            child: _loadingMore
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Muat lainnya'),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onTap});

  final StockOpnameSessionSummary session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.sessionCode,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'RobotoMono',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusChip(status: session.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${session.countedItems}/${session.totalItems} item dihitung',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: session.progress.clamp(0, 1),
                minHeight: 5,
                backgroundColor: AppColors.surfaceAlt,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            _SessionInfo(label: 'Gudang', value: _warehouseLabel),
            const SizedBox(height: 4),
            _SessionInfo(
              label: 'Lokasi',
              value: session.locationLabel.isEmpty
                  ? 'Semua lokasi'
                  : session.locationLabel,
            ),
            if (session.auditorName.isNotEmpty) ...[
              const SizedBox(height: 4),
              _SessionInfo(label: 'Auditor', value: session.auditorName),
            ],
            if (session.createdAt.isNotEmpty) ...[
              const SizedBox(height: 4),
              _SessionInfo(
                label: 'Dibuat',
                value: _formatCreatedAt(session.createdAt),
              ),
            ],
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String get _warehouseLabel => session.warehouseCode.isEmpty
      ? session.warehouseName
      : '${session.warehouseName} (${session.warehouseCode})';
}

class _SessionInfo extends StatelessWidget {
  const _SessionInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 64,
        child: Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ),
      Expanded(
        child: Text(
          value.isEmpty ? '-' : value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final color = switch (normalized) {
      'DRAFT' => AppColors.textMuted,
      'COUNTING' || 'ACTIVE' => AppColors.primary,
      'REVIEW' => AppColors.warning,
      'ADJUSTED' => AppColors.success,
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        normalized,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ListMessage extends StatelessWidget {
  const _ListMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 140),
      Icon(
        onRetry == null ? Icons.inventory_2_outlined : Icons.error_outline,
        size: 44,
        color: AppColors.textMuted,
      ),
      const SizedBox(height: 12),
      Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      if (onRetry != null) ...[
        const SizedBox(height: 14),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('Coba lagi'),
          ),
        ),
      ],
    ],
  );
}

String _formatCreatedAt(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
