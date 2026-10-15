import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/omni_app_bar.dart';
import '../../shared/widgets/omni_snackbar.dart';
import 'inbound_model.dart';
import 'inbound_repository.dart';

class InboundListScreen extends ConsumerStatefulWidget {
  const InboundListScreen({super.key});

  @override
  ConsumerState<InboundListScreen> createState() => _InboundListScreenState();
}

class _InboundListScreenState extends ConsumerState<InboundListScreen> {
  String _searchQuery = '';
  InboundStatus? _selectedStatusFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAdhocInboundDialog() {
    final codeController = TextEditingController(
      text: 'IN-ADHOC-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
    );
    final supplierController = TextEditingController();
    final qtyController = TextEditingController(text: '50');
    final rackController = TextEditingController(text: 'RACK-A1-01');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 480),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Penerimaan Ad-hoc (Tanpa PO)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Mode Cepat UMKM / Kiriman Bebas Non-PO',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'KODE TRANSAKSI',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'RobotoMono',
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: codeController,
                readOnly: true,
                style: const TextStyle(
                  fontFamily: 'RobotoMono',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFEFF6FF),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primaryBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primaryBorder),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'NAMA SUPPLIER / TOKO ASAL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'RobotoMono',
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: supplierController,
                decoration: InputDecoration(
                  hintText: 'Contoh: Toko Grosir Elektronik Jaya',
                  hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ESTIMASI QTY (UNIT)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'RobotoMono',
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RAK TUJUAN DEFAULT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'RobotoMono',
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: rackController,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: AppColors.textMuted),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Harga modal (HPP) disinkronkan otomatis dari master produk web untuk menjaga akurasi akuntansi.',
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final supplier = supplierController.text.trim().isEmpty
                        ? 'Vendor Ad-hoc'
                        : supplierController.text.trim();
                    final qty = int.tryParse(qtyController.text.trim()) ?? 50;

                    final newManifest = InboundManifest(
                      code: codeController.text.trim(),
                      supplier: supplier,
                      warehouse: 'Gudang Utama Malang',
                      dockBay: 'Staging Area',
                      totalUnits: qty,
                      status: InboundStatus.receiving,
                      startedAt: 'Baru saja',
                      isAdhoc: true,
                      items: [
                        InboundItem(
                          id: 'adhoc-01',
                          sku: 'SKU-GENERIC',
                          barcode: '899999900001',
                          name: 'Barang Campur Masuk (Ad-hoc)',
                          expectedQty: qty,
                          targetRack: rackController.text.trim(),
                        ),
                      ],
                    );

                    ref.read(inboundRepositoryProvider.notifier).addAdhocManifest(newManifest);
                    Navigator.of(ctx).pop();
                    OmniSnackbar.show(
                      context,
                      message: 'Sesi Ad-hoc ${newManifest.code} berhasil dibuat!',
                      icon: Icons.check_circle_rounded,
                    );
                    context.go('/inbound/${newManifest.code}');
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text(
                    'Mulai Scan Barang Masuk →',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manifests = ref.watch(inboundRepositoryProvider);
    final stats = ref.watch(inboundStatsProvider);

    final filteredManifests = manifests.where((m) {
      final matchesSearch = _searchQuery.isEmpty ||
          m.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.supplier.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (m.truckPlate?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      final matchesStatus = _selectedStatusFilter == null || m.status == _selectedStatusFilter;

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // slate-100
      appBar: const OmniAppBar(),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              // Summary / Hero Card
              _buildSummaryCard(stats),
              const SizedBox(height: 14),

              // Search Bar
              _buildSearchBar(),
              const SizedBox(height: 10),

              // Filter Chips
              _buildFilterChips(),
              const SizedBox(height: 14),

              // Action Buttons Row: Quick Scan PO + Ad-hoc Inbound
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: () {
                        // Quick scan Surat Jalan/PO Barcode
                        context.go('/scanner');
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner_rounded, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Scan Surat Jalan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: _showAdhocInboundDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryBorder),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              '+ Ad-hoc',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'DAFTAR MANIFES INBOUND',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'RobotoMono',
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
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

              // List of PO Cards
              if (filteredManifests.isEmpty)
                _buildEmptyState()
              else
                ...filteredManifests.map((manifest) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildManifestCard(manifest),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(InboundStats stats) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: const Icon(
                  Icons.move_to_inbox_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Menu Inbound',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Penerimaan & Validasi Fisik Barang Masuk',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                _buildStatPill('PO Hari Ini', '${stats.todayTotal}', const Color(0xFF004AC6)),
                Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                _buildStatPill('Dalam Proses', '${stats.inProgress}', const Color(0xFFD97706)),
                Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                _buildStatPill('Selesai', '${stats.completed}', const Color(0xFF059669)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Cari No. PO, Supplier, Plat Truk...',
          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      (null, 'Semua'),
      (InboundStatus.receiving, 'RECEIVING'),
      (InboundStatus.draft, 'DRAFT'),
      (InboundStatus.closed, 'CLOSED'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedStatusFilter == filter.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _selectedStatusFilter = filter.$1),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  filter.$2,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: filter.$1 != null ? 'RobotoMono' : null,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildManifestCard(InboundManifest manifest) {
    Color accentColor;
    switch (manifest.status) {
      case InboundStatus.receiving:
        accentColor = const Color(0xFFF59E0B);
        break;
      case InboundStatus.draft:
        accentColor = AppColors.primary;
        break;
      case InboundStatus.closed:
        accentColor = AppColors.success;
        break;
      case InboundStatus.hold:
        accentColor = AppColors.danger;
        break;
    }

    final isReceiving = manifest.status == InboundStatus.receiving;
    final isClosed = manifest.status == InboundStatus.closed;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Vertical Color Bar
              Container(
                width: 5,
                color: accentColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: PO Code & Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                manifest.code,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'RobotoMono',
                                  color: Color(0xFF0B1C30),
                                ),
                              ),
                              if (manifest.isAdhoc) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: const Text(
                                    'AD-HOC',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'RobotoMono',
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: manifest.status.bg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: manifest.status.border),
                            ),
                            child: Text(
                              manifest.status.label,
                              style: TextStyle(
                                color: manifest.status.color,
                                fontSize: 10,
                                fontFamily: 'RobotoMono',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Supplier & Dock Bay
                      Row(
                        children: [
                          const Icon(Icons.business_rounded, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              manifest.supplier,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              manifest.dockBay,
                              style: const TextStyle(
                                fontSize: 10,
                                fontFamily: 'RobotoMono',
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Unit Pill Strip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF4FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF004AC6)),
                            const SizedBox(width: 6),
                            Text(
                              '${manifest.totalUnits} Units Total',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF004AC6),
                              ),
                            ),
                            const Spacer(),
                            if (manifest.truckPlate != null)
                              Text(
                                'Truk: ${manifest.truckPlate}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'RobotoMono',
                                  color: Color(0xFF434655),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Progress Bar & Counter
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pemeriksaan Barcode:',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${manifest.scannedUnits} / ${manifest.totalUnits} SKU',
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'RobotoMono',
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: manifest.progressPercentage,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isClosed
                                ? AppColors.success
                                : (isReceiving ? const Color(0xFFF59E0B) : AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Footer Row: Timestamp & CTA Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                isClosed
                                    ? 'Selesai: ${manifest.completedAt ?? 'Tuntas'}'
                                    : (manifest.startedAt != null
                                        ? 'Mulai: ${manifest.startedAt}'
                                        : 'Siap Dibongkar'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              context.go('/inbound/${manifest.code}');
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 34,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isClosed ? const Color(0xFFF1F5F9) : AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                                border: isClosed ? Border.all(color: AppColors.border) : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isClosed
                                        ? Icons.visibility_outlined
                                        : (isReceiving
                                            ? Icons.qr_code_scanner_rounded
                                            : Icons.play_arrow_rounded),
                                    size: 15,
                                    color: isClosed ? AppColors.textPrimary : Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isClosed
                                        ? 'Lihat Detail'
                                        : (isReceiving ? 'Lanjut Scan PO' : 'Mulai Scan'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isClosed ? AppColors.textPrimary : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            'Tidak Ada Manifes Inbound Ditemukan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Coba ubah kata kunci pencarian atau sesuaikan filter status.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedStatusFilter = null;
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reset Filter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceAlt,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
