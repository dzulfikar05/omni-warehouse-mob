import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/omni_snackbar.dart';
import 'opname_model.dart';
import 'opname_repository.dart';

class OpnameScannerScreen extends ConsumerStatefulWidget {
  const OpnameScannerScreen({super.key, required this.sessionCode});

  final String sessionCode;

  @override
  ConsumerState<OpnameScannerScreen> createState() => _OpnameScannerScreenState();
}

class _OpnameScannerScreenState extends ConsumerState<OpnameScannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  bool _isFlashOn = false;
  bool _isAudioBeepOn = true;
  String _searchFilter = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showCountSheet(OpnameItem item, OpnameSession session) {
    int currentQty = item.physicalQty ?? (session.isBlindCount ? 0 : item.systemQty);
    final notesController = TextEditingController(text: item.notes ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 480),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${item.sku} • Lokasi: ${item.rack}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (session.isBlindCount)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.visibility_off_outlined, size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Blind Count Aktif: Hitung murni fisik di rak secara akurat.',
                            style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Text(
                          'Stok Sistem: ${item.systemQty} ${item.unit}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'JUMLAH FISIK DI RAK',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'RobotoMono',
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 32,
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.textSecondary),
                      onPressed: () {
                        if (currentQty > 0) {
                          setModalState(() => currentQty--);
                        }
                      },
                    ),
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '$currentQty ${item.unit}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'RobotoMono',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    IconButton(
                      iconSize: 32,
                      icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                      onPressed: () {
                        setModalState(() => currentQty++);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildQuickChip('0', () => setModalState(() => currentQty = 0)),
                    const SizedBox(width: 8),
                    _buildQuickChip('+5', () => setModalState(() => currentQty += 5)),
                    const SizedBox(width: 8),
                    _buildQuickChip('+10', () => setModalState(() => currentQty += 10)),
                    if (!session.isBlindCount) ...[
                      const SizedBox(width: 8),
                      _buildQuickChip('Sesuai', () => setModalState(() => currentQty = item.systemQty)),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'CATATAN TEMUAN (OPSIONAL)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'RobotoMono',
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Misal: "Ditemukan 2 unit rusak fisik di sudut rak"',
                    hintStyle: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(opnameRepositoryProvider.notifier).updateItemPhysicalCount(
                            sessionCode: session.sessionCode,
                            itemId: item.id,
                            physicalQty: currentQty,
                            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                          );
                      Navigator.of(ctx).pop();
                      OmniSnackbar.show(
                        context,
                        message: 'Fisik ${item.sku} tersimpan: $currentQty ${item.unit}',
                        icon: Icons.check_circle_rounded,
                      );
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text(
                      'Simpan Hasil Hitung Fisik',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'RobotoMono',
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  void _finishSession(OpnameSession session) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Selesaikan Hitungan Sesi?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text(
          'Total ${session.countedItems} dari ${session.totalItems} item telah selesai dihitung fisik.\n\nData akan disinkronkan ke Web untuk ditinjau oleh Manager dalam proses Rekonsiliasi & Adjustment Akuntansi.',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Lanjut Hitung', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(opnameRepositoryProvider.notifier).submitSessionForReconciliation(session.sessionCode);
              Navigator.of(ctx).pop();
              OmniSnackbar.show(
                context,
                message: 'Sesi ${session.sessionCode} terkirim ke Web untuk rekonsiliasi!',
                icon: Icons.cloud_done_rounded,
              );
              context.go('/more/opname');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ya, Kirim ke Web'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(opnameRepositoryProvider);
    final session = sessions.cast<OpnameSession?>().firstWhere(
          (s) => s?.sessionCode.toLowerCase() == widget.sessionCode.toLowerCase(),
          orElse: () => null,
        );

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sesi Tidak Ditemukan')),
        body: const Center(child: Text('Kode sesi opname tidak valid.')),
      );
    }

    final filteredItems = session.items.where((it) {
      return _searchFilter.isEmpty ||
          it.sku.toLowerCase().contains(_searchFilter.toLowerCase()) ||
          it.barcode.toLowerCase().contains(_searchFilter.toLowerCase()) ||
          it.name.toLowerCase().contains(_searchFilter.toLowerCase()) ||
          it.rack.toLowerCase().contains(_searchFilter.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                // Top Action Bar
                _buildTopBar(session),

                // Camera Viewfinder (Collapsible/Fixed)
                _buildViewfinder(session),

                // Search & Filter Row
                _buildSearchFilterBar(),

                // List of items to count
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filteredItems.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) => _buildItemTile(filteredItems[idx], session),
                  ),
                ),

                // Bottom Action Bar
                _buildBottomBar(session),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(OpnameSession session) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                onPressed: () => context.go('/more/opname'),
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.sessionCode,
                    style: const TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${session.countedItems}/${session.totalItems} Terhitung (${(session.progress * 100).toInt()}%)',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isAudioBeepOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () => setState(() => _isAudioBeepOn = !_isAudioBeepOn),
              ),
              IconButton(
                icon: Icon(
                  _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: _isFlashOn ? const Color(0xFFFBBF24) : AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () => setState(() => _isFlashOn = !_isFlashOn),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewfinder(OpnameSession session) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Laser Animation Box
          Container(
            width: 220,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 10,
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _laserAnimation,
              builder: (context, child) {
                return Stack(
                  children: [
                    Positioned(
                      top: _laserAnimation.value * 85,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          boxShadow: [
                            BoxShadow(color: Color(0xFF60A5FA), blurRadius: 6, spreadRadius: 1),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            bottom: 8,
            left: 12,
            right: 12,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: session.items.map((it) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () {
                        if (_isAudioBeepOn) HapticFeedback.mediumImpact();
                        _showCountSheet(it, session);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primaryBorder),
                        ),
                        child: Text(
                          'Scan ${it.sku}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'RobotoMono',
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchFilter = val.trim()),
          style: const TextStyle(fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'Cari SKU, nama item, atau rak...',
            hintStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
            prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildItemTile(OpnameItem item, OpnameSession session) {
    final status = item.status;
    return InkWell(
      onTap: () => _showCountSheet(item, session),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: item.physicalQty != null ? status.border : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 48,
              decoration: BoxDecoration(
                color: status.color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.sku,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'RobotoMono',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: status.bg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: status.border),
                        ),
                        child: Text(
                          status.label,
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: status.color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          item.rack,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (item.notes != null) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.note_alt_outlined, size: 12, color: AppColors.warning),
                        const SizedBox(width: 2),
                        const Text('Catatan', style: TextStyle(fontSize: 9, color: AppColors.warning)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (item.physicalQty != null) ...[
                  Text(
                    '${item.physicalQty} ${item.unit}',
                    style: const TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  if (!session.isBlindCount && item.variance != null)
                    Text(
                      item.variance == 0
                          ? 'Sesuai'
                          : item.variance! > 0
                              ? '+${item.variance}'
                              : '${item.variance}',
                      style: TextStyle(
                        fontFamily: 'RobotoMono',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: status.color,
                      ),
                    ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Hitung →',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
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

  Widget _buildBottomBar(OpnameSession session) {
    final allCounted = session.countedItems == session.totalItems;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _finishSession(session),
            icon: const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(
              allCounted ? 'Kirim Hasil Opname ke Web' : 'Selesaikan (${session.countedItems}/${session.totalItems})',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: allCounted ? AppColors.success : AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }
}
