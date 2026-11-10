import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/omni_app_bar.dart';
import '../../shared/widgets/omni_snackbar.dart';
import 'transfer_transaction_model.dart';
import 'transfer_transaction_repository.dart';

class TransferTransactionsScreen extends ConsumerStatefulWidget {
  const TransferTransactionsScreen({super.key});

  @override
  ConsumerState<TransferTransactionsScreen> createState() =>
      _TransferTransactionsScreenState();
}

class _TransferTransactionsScreenState
    extends ConsumerState<TransferTransactionsScreen> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<TransferTransaction> _transactions = const [];
  TransferTransactionStats? _stats;
  String? _loadError;
  String? _statusFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _isLoading = true;
  bool _isActionRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTransactions());
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      _loadTransactions,
    );
  }

  Future<void> _loadTransactions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final slug = ref.read(authProvider).tenantSlug;
      if (slug == null || slug.isEmpty) {
        throw Exception('Tenant belum dipilih. Silakan login kembali.');
      }
      final filters = <String, dynamic>{
        if (_searchController.text.trim().isNotEmpty)
          'search': _searchController.text.trim(),
        if (_statusFilter != null) 'status': _statusFilter,
        if (_dateFrom != null) 'date_from': _formatDate(_dateFrom!),
        if (_dateTo != null) 'date_to': _formatDate(_dateTo!),
      };
      final result = await ref
          .read(transferTransactionRepositoryProvider)
          .getTransactions(slug, filters: filters);
      if (!mounted) return;
      setState(() {
        _transactions = result.transactions;
        _stats = result.stats;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _openForm([TransferTransaction? transaction]) async {
    final didSave = await context.push<bool>(
      '/more/transfer/form',
      extra: transaction,
    );
    if (didSave == true) await _loadTransactions();
  }

  Future<void> _openDetails(TransferTransaction transaction) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (context) => _TransferDetailSheet(
        transaction: transaction,
        onEdit: transaction.isEditable
            ? () {
                Navigator.of(context).pop();
                _openForm(transaction);
              }
            : null,
        onCancel: transaction.canCancel
            ? () {
                Navigator.of(context).pop();
                _confirmCancel(transaction);
              }
            : null,
      ),
    );
  }

  Future<void> _confirmCancel(TransferTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan mutasi?'),
        content: Text(
          'Transaksi ${transaction.code} akan dibatalkan. Jika stok sudah berpindah, backend akan membalikkan pergerakan stok.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Batalkan transaksi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isActionRunning = true);
    try {
      final slug = ref.read(authProvider).tenantSlug;
      if (slug == null || slug.isEmpty) {
        throw Exception('Tenant belum dipilih. Silakan login kembali.');
      }
      await ref
          .read(transferTransactionRepositoryProvider)
          .cancelTransaction(slug, transaction.code);
      await _loadTransactions();
      if (mounted) {
        OmniSnackbar.show(
          context,
          message: 'Mutasi ${transaction.code} berhasil dibatalkan.',
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (error) {
      if (mounted) {
        OmniSnackbar.show(
          context,
          message: error.toString(),
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _dateFrom == null
          ? null
          : DateTimeRange(
              start: _dateFrom!,
              end: _dateTo ?? _dateFrom!,
            ),
    );
    if (range == null) return;
    setState(() {
      _dateFrom = range.start;
      _dateTo = range.end;
    });
    await _loadTransactions();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _statusFilter = null;
      _dateFrom = null;
      _dateTo = null;
    });
    _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats ??
        const TransferTransactionStats(
          total: 0,
          inProgress: 0,
          completed: 0,
          totalUnits: 0,
        );
    final hasDateFilter = _dateFrom != null || _dateTo != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const OmniAppBar(),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          child: RefreshIndicator(
            onRefresh: _loadTransactions,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                _buildHeader(),
                const SizedBox(height: 14),
                _buildStats(stats),
                const SizedBox(height: 14),
                _buildSearch(),
                const SizedBox(height: 10),
                _buildStatusFilters(),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(
                    hasDateFilter
                        ? '${_formatDate(_dateFrom!)} — ${_formatDate(_dateTo ?? _dateFrom!)}'
                        : 'Filter rentang tanggal',
                  ),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
                if (_statusFilter != null || hasDateFilter) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Reset filter'),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Buat Mutasi Stok'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'RIWAYAT MUTASI & TRANSFER',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Text(
                      '${_transactions.length} transaksi',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_isLoading && _transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_loadError != null && _transactions.isEmpty)
                  _buildLoadError()
                else if (_transactions.isEmpty)
                  _buildEmptyState()
                else
                  ..._transactions.map(
                    (transaction) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildTransactionCard(transaction),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _isActionRunning
          ? const FloatingActionButton(
              onPressed: null,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : null,
    );
  }

  Widget _buildHeader() => Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: const Icon(
              Icons.swap_horiz_rounded,
              color: AppColors.primary,
              size: 23,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mutasi & Transfer Stok',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Pindahkan stok antar rak dan gudang',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildStats(TransferTransactionStats stats) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Total transaksi',
                  stats.total,
                  Icons.swap_horiz_rounded,
                  AppColors.primary,
                  AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  'Dalam proses',
                  stats.inProgress,
                  Icons.schedule_rounded,
                  AppColors.warning,
                  AppColors.warningLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  'Selesai',
                  stats.completed,
                  Icons.check_circle_outline_rounded,
                  AppColors.success,
                  AppColors.successLight,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  'Total unit',
                  stats.totalUnits,
                  Icons.inventory_2_outlined,
                  const Color(0xFF7C3AED),
                  const Color(0xFFF5F3FF),
                ),
              ),
            ],
          ),
        ],
      );

  Widget _statCard(
    String title,
    int value,
    IconData icon,
    Color color,
    Color background,
  ) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 33,
              height: 33,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$value',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildSearch() => TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Cari kode, SKU, atau lokasi...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: _searchController.clear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      );

  Widget _buildStatusFilters() {
    const statuses = <String?, String>{
      null: 'Semua',
      'pending': 'Pending',
      'in_transit': 'Dalam perjalanan',
      'completed': 'Selesai',
      'cancelled': 'Dibatalkan',
      'draft': 'Draft',
    };
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: statuses.entries.map((entry) {
          final selected = _statusFilter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (_) {
                setState(() => _statusFilter = entry.key);
                _loadTransactions();
              },
              backgroundColor: Colors.white,
              selectedColor: AppColors.primaryLight,
              labelStyle: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color: selected ? AppColors.primaryBorder : AppColors.border,
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionCard(TransferTransaction transaction) {
    final statusStyle = _statusStyle(transaction.status);
    final previewLines = transaction.items.take(2).toList();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _openDetails(transaction),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      transaction.code.isEmpty
                          ? 'Mutasi stok'
                          : transaction.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusBadge(transaction.status, statusStyle),
                ],
              ),
              const SizedBox(height: 10),
              if (previewLines.isEmpty)
                Text(
                  '${transaction.totalItems} SKU · ${transaction.units} unit',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                )
              else
                ...previewLines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            line.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '×${line.quantity}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (transaction.items.length > 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '+ ${transaction.items.length - 2} item lainnya',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Divider(height: 12, color: AppColors.border),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      transaction.createdAt.isEmpty
                          ? 'Waktu tidak tersedia'
                          : transaction.createdAt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Text(
                    '${transaction.totalItems} SKU · ${transaction.units} unit',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadError() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.dangerBorder),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppColors.danger, size: 28),
            const SizedBox(height: 8),
            Text(
              _loadError ?? 'Gagal memuat transaksi.',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loadTransactions,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );

  Widget _buildEmptyState() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: AppColors.textMuted,
              size: 34,
            ),
            SizedBox(height: 9),
            Text(
              'Belum ada transaksi mutasi',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Buat mutasi stok untuk memindahkan barang antar lokasi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      );

  _TransferStatusStyle _statusStyle(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const _TransferStatusStyle(
          color: AppColors.success,
          background: AppColors.successLight,
          border: AppColors.successBorder,
        );
      case 'in_transit':
        return const _TransferStatusStyle(
          color: AppColors.warning,
          background: AppColors.warningLight,
          border: AppColors.warningBorder,
        );
      case 'cancelled':
      case 'canceled':
        return const _TransferStatusStyle(
          color: AppColors.danger,
          background: AppColors.dangerLight,
          border: AppColors.dangerBorder,
        );
      case 'draft':
        return const _TransferStatusStyle(
          color: AppColors.textSecondary,
          background: AppColors.surfaceAlt,
          border: AppColors.border,
        );
      default:
        return const _TransferStatusStyle(
          color: AppColors.primary,
          background: AppColors.primaryLight,
          border: AppColors.primaryBorder,
        );
    }
  }

  Widget _statusBadge(
    String status,
    _TransferStatusStyle style,
  ) {
    final normalizedStatus = status.toLowerCase();
    final String label;
    if (normalizedStatus == 'in_transit') {
      label = 'Dalam perjalanan';
    } else if (normalizedStatus == 'completed') {
      label = 'Selesai';
    } else if (normalizedStatus == 'cancelled' ||
        normalizedStatus == 'canceled') {
      label = 'Dibatalkan';
    } else if (normalizedStatus == 'draft') {
      label = 'Draft';
    } else if (normalizedStatus == 'pending') {
      label = 'Pending';
    } else {
      label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        border: Border.all(color: style.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: style.color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TransferDetailSheet extends StatelessWidget {
  const _TransferDetailSheet({
    required this.transaction,
    this.onEdit,
    this.onCancel,
  });

  final TransferTransaction transaction;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _detailStatusStyle(transaction.status);
    return SafeArea(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.code,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${transaction.createdAt} · ${transaction.creator.isEmpty ? 'Operator' : transaction.creator}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusStyle.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusStyle.border),
                  ),
                  child: Text(
                    transaction.status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: statusStyle.color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _detailSummary(
                    'Total item mutasi',
                    '${transaction.totalItems} SKU',
                    Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _detailSummary(
                    'Total quantity',
                    '${transaction.units} unit',
                    Icons.numbers_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Rincian pergerakan stok (${transaction.items.length})',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: transaction.items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Rincian item tidak disertakan pada respons daftar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: transaction.items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final item = transaction.items[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.productName,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${item.quantity} ${item.unit}',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              if (item.sku.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.sku,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 7),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.fromLocation.isEmpty
                                          ? 'Rak asal'
                                          : item.fromLocation,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 15,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      item.toLocation.isEmpty
                                          ? 'Rak tujuan'
                                          : item.toLocation,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (item.batchNumber != null ||
                                  item.expiryDate != null) ...[
                                const SizedBox(height: 5),
                                Text(
                                  [
                                    if (item.batchNumber != null)
                                      'Batch ${item.batchNumber}',
                                    if (item.expiryDate != null)
                                      'Kedaluwarsa ${item.expiryDate}',
                                  ].join(' · '),
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (transaction.notes != null &&
                transaction.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Catatan: ${transaction.notes}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup'),
                  ),
                ),
                if (onEdit != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Ubah draft'),
                    ),
                  ),
                ],
                if (onCancel != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Batalkan'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailSummary(String label, String value, IconData icon) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: AppColors.textMuted),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  _TransferStatusStyle _detailStatusStyle(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const _TransferStatusStyle(
          color: AppColors.success,
          background: AppColors.successLight,
          border: AppColors.successBorder,
        );
      case 'cancelled':
      case 'canceled':
        return const _TransferStatusStyle(
          color: AppColors.danger,
          background: AppColors.dangerLight,
          border: AppColors.dangerBorder,
        );
      case 'in_transit':
        return const _TransferStatusStyle(
          color: AppColors.warning,
          background: AppColors.warningLight,
          border: AppColors.warningBorder,
        );
      default:
        return const _TransferStatusStyle(
          color: AppColors.primary,
          background: AppColors.primaryLight,
          border: AppColors.primaryBorder,
        );
    }
  }
}

class _TransferStatusStyle {
  const _TransferStatusStyle({
    required this.color,
    required this.background,
    required this.border,
  });

  final Color color;
  final Color background;
  final Color border;
}
