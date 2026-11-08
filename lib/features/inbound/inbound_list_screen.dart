import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/omni_app_bar.dart';
import '../../shared/widgets/omni_snackbar.dart';
import 'inbound_model.dart';
import 'inbound_repository.dart';
import 'widgets/create_manifest_modal.dart';

class InboundListScreen extends ConsumerStatefulWidget {
  const InboundListScreen({super.key});

  @override
  ConsumerState<InboundListScreen> createState() => _InboundListScreenState();
}

class _InboundListScreenState extends ConsumerState<InboundListScreen> {
  String _searchQuery = '';
  InboundStatus? _selectedStatusFilter;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadManifests();
    });
  }

  Future<void> _loadManifests() async {
    try {
      await ref.read(inboundRepositoryProvider.notifier).loadManifests();
    } catch (error) {
      if (mounted) {
        OmniSnackbar.show(
          context,
          message: error.toString(),
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateManifestModal({bool isAdhoc = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateManifestModal(initialIsAdhoc: isAdhoc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manifests = ref.watch(inboundRepositoryProvider);
    final stats = ref.watch(inboundStatsProvider);

    final filteredManifests = manifests.where((m) {
      final matchesSearch = _searchQuery.isEmpty ||
          m.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.supplierName.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus =
          _selectedStatusFilter == null || m.status == _selectedStatusFilter;

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
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _showCreateManifestModal(isAdhoc: true),
                        icon: const Icon(Icons.bolt_rounded),
                        label: const Text('Inbound Ad-hoc'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primaryBorder,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: ElevatedButton.icon(
                        onPressed: _showCreateManifestModal,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('PO Manifest'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'DAFTAR MANIFES INBOUND',
                        softWrap: true,
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
                      '${filteredManifests.length} Manifes',
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
                if (_isLoading && filteredManifests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filteredManifests.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'Belum ada manifes inbound.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                else
                  ...filteredManifests.map(
                    (manifest) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildManifestCard(manifest),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(InboundStats stats) {
    return Container(
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
              Icon(Icons.move_to_inbox_rounded,
                  color: AppColors.primary, size: 20),
              SizedBox(width: 10),
              Text(
                'Menu Inbound',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatPill(
                'Total Manifes',
                '${stats.todayTotal}',
                AppColors.primary,
              ),
              _buildStatPill(
                'Pending',
                '${stats.inProgress}',
                AppColors.warning,
              ),
              _buildStatPill(
                'Selesai',
                '${stats.completed}',
                AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Cari No. PO, Supplier...',
          prefixIcon:
              Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
  }

  Widget _buildFilterChips() {
    final filters = <MapEntry<InboundStatus?, String>>[
      const MapEntry(null, 'Semua'),
      const MapEntry(InboundStatus.receiving, 'RECEIVING'),
      const MapEntry(InboundStatus.draft, 'DRAFT'),
      const MapEntry(InboundStatus.closed, 'CLOSED'),
      const MapEntry(InboundStatus.hold, 'HOLD'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedStatusFilter == filter.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.value),
              selected: isSelected,
              onSelected: (_) =>
                  setState(() => _selectedStatusFilter = filter.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildManifestCard(InboundManifest manifest) {
    return Container(
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
                  manifest.code,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'RobotoMono',
                    color: AppColors.textPrimary,
                  ),
                  softWrap: true,
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(manifest.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Supplier: ${manifest.supplierName}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            softWrap: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                manifest.isAdhoc
                    ? Icons.bolt_rounded
                    : Icons.description_outlined,
                size: 15,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  manifest.isAdhoc ? 'Inbound Ad-hoc' : 'PO Manifest',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '${manifest.totalSkus} SKU · ${manifest.totalUnits} unit',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/inbound/${manifest.code}'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Buka Manifes',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(InboundStatus status) => Container(
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
}
