import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/omni_app_bar.dart';
import 'outbound_model.dart';
import 'outbound_repository.dart';
import 'widgets/create_manifest_modal.dart';

class OutboundListScreen extends ConsumerStatefulWidget {
  const OutboundListScreen({super.key});

  @override
  ConsumerState<OutboundListScreen> createState() => _OutboundListScreenState();
}

class _OutboundListScreenState extends ConsumerState<OutboundListScreen> {
  String _searchQuery = '';
  OutboundStatus? _selectedStatusFilter;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadManifests());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadManifests() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      await ref.read(outboundRepositoryProvider.notifier).loadManifests();
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateManifestModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (context) => const CreateOutboundManifestModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(outboundRepositoryProvider);
    final stats = ref.watch(outboundStatsProvider);
    final query = _searchQuery.toLowerCase();
    final filteredOrders = orders.where((order) {
      final matchesSearch =
          query.isEmpty ||
          order.code.toLowerCase().contains(query) ||
          order.customer.toLowerCase().contains(query) ||
          (order.vehicleNo?.toLowerCase().contains(query) ?? false) ||
          (order.driverName?.toLowerCase().contains(query) ?? false) ||
          (order.trackingNumber?.toLowerCase().contains(query) ?? false);
      final matchesStatus =
          _selectedStatusFilter == null ||
          order.status == _selectedStatusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const OmniAppBar(),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          child: RefreshIndicator(
            onRefresh: _loadManifests,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              children: [
                _buildSummaryCard(stats),
                const SizedBox(height: 14),
                _buildSearchBar(),
                const SizedBox(height: 10),
                _buildFilterChips(),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showCreateManifestModal,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Buat Manifes SO'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'DAFTAR MANIFES OUTBOUND',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'RobotoMono',
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${filteredOrders.length} Manifes',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'RobotoMono',
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_isLoading && orders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_loadError != null && orders.isEmpty)
                  _buildLoadError()
                else if (filteredOrders.isEmpty)
                  _buildEmptyState(hasAnyOrders: orders.isNotEmpty)
                else
                  ...filteredOrders.map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildManifestCard(order),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(OutboundStats stats) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.outbox_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Menu Outbound',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Picking dan pengiriman pesanan pelanggan',
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
        const SizedBox(height: 14),
        Row(
          children: [
            _buildStatPill(
              'Total Manifes',
              '${stats.todayTotal}',
              AppColors.primary,
            ),
            _buildStatPill(
              'Dalam Proses',
              '${stats.picking}',
              AppColors.warning,
            ),
            _buildStatPill('Selesai', '${stats.dispatched}', AppColors.success),
          ],
        ),
      ],
    ),
  );

  Widget _buildStatPill(String label, String value, Color valueColor) =>
      Expanded(
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ],
        ),
      );

  Widget _buildSearchBar() => Container(
    height: 44,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Cari No. SO, Customer, Kendaraan...',
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: AppColors.textMuted,
        ),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(Icons.clear_rounded, size: 18),
              ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    ),
  );

  Widget _buildFilterChips() {
    final filters = <(OutboundStatus?, String)>[
      (null, 'Semua'),
      (OutboundStatus.readyToPick, 'SIAP PICKING'),
      (OutboundStatus.picking, 'PICKING'),
      (OutboundStatus.packing, 'PACKING'),
      (OutboundStatus.dispatched, 'DISPATCHED'),
      (OutboundStatus.hold, 'HOLD'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedStatusFilter == filter.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.$2),
              selected: isSelected,
              onSelected: (_) =>
                  setState(() => _selectedStatusFilter = filter.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildManifestCard(OutboundOrder order) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                order.code,
                softWrap: true,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'RobotoMono',
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusBadge(order.status),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Customer: ${order.customer}',
          softWrap: true,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.description_outlined,
              size: 15,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                order.vehicleNo?.isNotEmpty == true
                    ? 'SO Manifest · ${order.vehicleNo}'
                    : 'SO Manifest',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              '${order.totalSkuCount} SKU · ${order.totalOrderUnits} unit',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Progres Picking',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            Text(
              '${order.totalProcessedUnits}/${order.totalOrderUnits} unit',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: order.progressPercentage,
            minHeight: 6,
            backgroundColor: AppColors.surfaceAlt,
            valueColor: AlwaysStoppedAnimation<Color>(order.status.color),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go('/outbound/${order.code}'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Buka Manifes'),
          ),
        ),
      ],
    ),
  );

  Widget _buildStatusBadge(OutboundStatus status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: status.bg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      status.label,
      style: TextStyle(
        color: status.color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _buildLoadError() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Text(
          _loadError!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _loadManifests,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Coba lagi'),
        ),
      ],
    ),
  );

  Widget _buildEmptyState({required bool hasAnyOrders}) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.inventory_2_outlined,
          size: 42,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: 12),
        Text(
          hasAnyOrders
              ? 'Tidak ada manifes outbound yang cocok.'
              : 'Belum ada manifes outbound.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (hasAnyOrders) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedStatusFilter = null;
              });
            },
            child: const Text('Reset Filter'),
          ),
        ],
      ],
    ),
  );
}
