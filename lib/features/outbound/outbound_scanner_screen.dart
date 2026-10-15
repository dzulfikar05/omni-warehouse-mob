import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/omni_snackbar.dart';
import 'outbound_model.dart';
import 'outbound_repository.dart';

enum OutboundExecutionMode {
  quickChecklist, // Mode Ceklis Cepat untuk UMKM
  cameraScanner,   // Mode Barcode Scanner untuk Gudang Ber-rak / Enterprise
}

class OutboundScannerScreen extends ConsumerStatefulWidget {
  const OutboundScannerScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<OutboundScannerScreen> createState() => _OutboundScannerScreenState();
}

class _OutboundScannerScreenState extends ConsumerState<OutboundScannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  OutboundExecutionMode _mode = OutboundExecutionMode.quickChecklist;
  bool _isFlashOn = false;
  bool _isAudioBeepOn = true;
  bool _isCommitting = false;

  OutboundItem? _activeScannedItem;
  int _activePickedQty = 0;
  int _activePackedQty = 0;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final order = ref.read(outboundRepositoryProvider.notifier).getOrderByCode(widget.code);
      if (order != null && order.items.isNotEmpty) {
        _selectItem(order.items.first);
      }
    });
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  void _selectItem(OutboundItem item) {
    setState(() {
      _activeScannedItem = item;
      _activePickedQty = item.pickedQty == 0 ? item.orderQty : item.pickedQty;
      _activePackedQty = item.packedQty == 0 ? item.orderQty : item.packedQty;
    });
  }

  void _simulateScanSku(String sku) {
    final order = ref.read(outboundRepositoryProvider.notifier).getOrderByCode(widget.code);
    if (order == null) return;

    final match = order.items.firstWhere(
      (it) => it.sku.toLowerCase() == sku.toLowerCase(),
      orElse: () => order.items.first,
    );

    HapticFeedback.mediumImpact();
    _selectItem(match);

    OmniSnackbar.show(
      context,
      message: 'Barcode terverifikasi: ${match.sku} (${match.fromRack})',
      icon: Icons.qr_code_scanner_rounded,
    );
  }

  void _saveCurrentItemPick() {
    if (_activeScannedItem == null) return;

    HapticFeedback.mediumImpact();
    ref.read(outboundRepositoryProvider.notifier).updateItemPickAndPack(
          orderCode: widget.code,
          itemId: _activeScannedItem!.id,
          pickedQty: _activePickedQty,
          packedQty: _activePackedQty,
        );

    OmniSnackbar.show(
      context,
      message: '${_activeScannedItem!.sku}: $_activePickedQty unit terambil & dipacking',
      icon: Icons.check_circle_rounded,
    );

    // Auto-advance
    final order = ref.read(outboundRepositoryProvider.notifier).getOrderByCode(widget.code);
    if (order != null) {
      final uncompleted = order.items.where((it) => it.id != _activeScannedItem!.id && !it.isFullyPicked);
      if (uncompleted.isNotEmpty) {
        _selectItem(uncompleted.first);
      }
    }
  }

  void _batchPickAllItems() {
    HapticFeedback.heavyImpact();
    ref.read(outboundRepositoryProvider.notifier).batchCheckAllItems(widget.code);

    OmniSnackbar.show(
      context,
      message: 'Semua item dalam pesanan berhasil diambil & dipacking!',
      icon: Icons.done_all_rounded,
    );
  }

  void _commitDispatch(OutboundOrder order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_shipping_rounded, color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Commit Dispatch',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Konfirmasi pengiriman pesanan ${order.code} untuk ${order.customer}?',
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sebanyak ${order.totalPickedUnits} unit barang akan otomatis dipotong dari stok database web.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF1E3A8A)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ya, Kirim Sekarang'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isCommitting = true);
    await Future.delayed(const Duration(milliseconds: 900));

    if (mounted) {
      ref.read(outboundRepositoryProvider.notifier).commitDispatch(widget.code);
      setState(() => _isCommitting = false);

      OmniSnackbar.show(
        context,
        message: 'Pesanan ${order.code} berhasil dikirim! Status web: DISPATCHED',
        icon: Icons.cloud_done_rounded,
      );

      context.go('/outbound');
    }
  }

  void _showManualInputDialog() {
    final barcodeController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 480),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
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
            const Text(
              'Input Manual Barcode SKU',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ketik kode SKU atau nomor barcode fisik yang tertera pada kemasan.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: barcodeController,
              autofocus: true,
              style: const TextStyle(fontFamily: 'RobotoMono', fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Contoh: SKU-ME-110...',
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_rounded, color: AppColors.primary),
                  onPressed: () {
                    final query = barcodeController.text.trim();
                    if (query.isNotEmpty) {
                      Navigator.of(ctx).pop();
                      _simulateScanSku(query);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  final query = barcodeController.text.trim();
                  if (query.isNotEmpty) {
                    Navigator.of(ctx).pop();
                    _simulateScanSku(query);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Verifikasi Barang', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(outboundRepositoryProvider);
    final order = orders.firstWhere(
      (o) => o.code.toLowerCase() == widget.code.toLowerCase(),
      orElse: () => orders.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // slate-100
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 6,
            left: 12,
            right: 12,
            bottom: 8,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.go('/outbound'),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          order.code,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'RobotoMono',
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: order.status.bg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            order.status.label,
                            style: TextStyle(
                              color: order.status.color,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'RobotoMono',
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${order.customer} • ${order.expedition}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              if (_mode == OutboundExecutionMode.cameraScanner) ...[
                IconButton(
                  onPressed: () {
                    setState(() => _isFlashOn = !_isFlashOn);
                    OmniSnackbar.show(
                      context,
                      message: _isFlashOn ? 'Senter kamera aktif' : 'Senter kamera mati',
                      icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    );
                  },
                  icon: Icon(
                    _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    color: _isFlashOn ? const Color(0xFFFACC15) : Colors.white70,
                    size: 18,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _isAudioBeepOn = !_isAudioBeepOn),
                  icon: Icon(
                    _isAudioBeepOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    color: _isAudioBeepOn ? const Color(0xFF38BDF8) : Colors.white70,
                    size: 18,
                  ),
                ),
              ],
              // Mode switcher toggle button in top bar
              InkWell(
                onTap: () {
                  setState(() {
                    _mode = _mode == OutboundExecutionMode.quickChecklist
                        ? OutboundExecutionMode.cameraScanner
                        : OutboundExecutionMode.quickChecklist;
                  });
                  HapticFeedback.selectionClick();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: _mode == OutboundExecutionMode.quickChecklist
                        ? const Color(0xFF1E293B)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _mode == OutboundExecutionMode.quickChecklist
                          ? const Color(0xFF334155)
                          : AppColors.primary,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _mode == OutboundExecutionMode.quickChecklist
                            ? Icons.checklist_rounded
                            : Icons.camera_alt_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _mode == OutboundExecutionMode.quickChecklist ? 'Ceklis' : 'Scanner',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              // Overall Progress Strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFF1E293B),
                child: Row(
                  children: [
                    const Icon(Icons.outbox_rounded, size: 16, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                order.waveId ?? 'Progres Pengambilan (Picking)',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${order.totalPickedUnits} / ${order.totalOrderUnits} Units (${(order.progressPercentage * 100).toInt()}%)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'RobotoMono',
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: order.progressPercentage,
                              minHeight: 5,
                              backgroundColor: const Color(0xFF334155),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                order.isFullyPicked ? AppColors.success : const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Viewport Content: Mode Ceklis vs Mode Scanner
              Expanded(
                child: _mode == OutboundExecutionMode.quickChecklist
                    ? _buildQuickChecklistView(order)
                    : _buildCameraScannerView(order),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. TAMPILAN MODE CEKLIS CEPAT (UMKM FRIENDLY)
  Widget _buildQuickChecklistView(OutboundOrder order) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        // Action banner: Ambil Semua Sekaligus
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode Cepat UMKM',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Tarik barang dari penyimpanan tanpa harus scan kamera.',
                      style: TextStyle(fontSize: 10, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _batchPickAllItems,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '✓ Ambil Semua',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Section Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'DAFTAR ITEM YANG PERLU DIAMBIL',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'RobotoMono',
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '${order.items.length} SKU',
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'RobotoMono',
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Items List
        for (final item in order.items) ...[
          _buildChecklistItemCard(order, item),
          const SizedBox(height: 8),
        ],

        const SizedBox(height: 14),

        // Commit Dispatch CTA
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isCommitting ? null : () => _commitDispatch(order),
            icon: _isCommitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.local_shipping_rounded, size: 18),
            label: Text(
              _isCommitting ? 'Menyimpan ke Server...' : 'Commit Dispatch & Selesai',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistItemCard(OutboundOrder order, OutboundItem item) {
    final isDone = item.isFullyPicked;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone ? const Color(0xFFBBF7D0) : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Checkbox Icon
          InkWell(
            onTap: () {
              final newQty = isDone ? 0 : item.orderQty;
              ref.read(outboundRepositoryProvider.notifier).updateItemPickAndPack(
                    orderCode: order.code,
                    itemId: item.id,
                    pickedQty: newQty,
                    packedQty: newQty,
                  );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDone ? AppColors.success : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDone ? AppColors.success : const Color(0xFFCBD5E1),
                ),
              ),
              child: Icon(
                isDone ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
                color: isDone ? Colors.white : AppColors.textMuted,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.sku,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'RobotoMono',
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.fromRack,
                        style: const TextStyle(
                          fontSize: 9,
                          fontFamily: 'RobotoMono',
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),

          // Stepper / Quantity Counter
          Row(
            children: [
              _buildSmallStepperBtn(
                icon: Icons.remove_rounded,
                onTap: () {
                  if (item.pickedQty > 0) {
                    ref.read(outboundRepositoryProvider.notifier).updateItemPickAndPack(
                          orderCode: order.code,
                          itemId: item.id,
                          pickedQty: item.pickedQty - 1,
                          packedQty: item.packedQty - 1,
                        );
                  }
                },
              ),
              const SizedBox(width: 6),
              Text(
                '${item.pickedQty}/${item.orderQty}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'RobotoMono',
                  color: isDone ? const Color(0xFF166534) : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              _buildSmallStepperBtn(
                icon: Icons.add_rounded,
                onTap: () {
                  if (item.pickedQty < item.orderQty) {
                    ref.read(outboundRepositoryProvider.notifier).updateItemPickAndPack(
                          orderCode: order.code,
                          itemId: item.id,
                          pickedQty: item.pickedQty + 1,
                          packedQty: item.packedQty + 1,
                        );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. TAMPILAN MODE CAMERA SCANNER (ENTERPRISE / GUDANG BESAR)
  Widget _buildCameraScannerView(OutboundOrder order) {
    return Column(
      children: [
        // Camera Viewfinder
        Expanded(
          flex: 3,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF020617)],
                    radius: 0.9,
                  ),
                ),
              ),

              // Reticle
              Container(
                width: 240,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5), width: 1.5),
                ),
                child: Stack(
                  children: [
                    // Animated Laser Line
                    AnimatedBuilder(
                      animation: _laserAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: _laserAnimation.value * 150,
                          left: 6,
                          right: 6,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    Center(
                      child: Icon(
                        Icons.filter_center_focus_rounded,
                        size: 32,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                ),
              ),

              // Instruction pill
              Positioned(
                bottom: 44,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _activeScannedItem != null
                        ? 'Lokasi: ${_activeScannedItem!.fromRack} • Scan Barcode SKU'
                        : 'Arahkan kamera ke Barcode Barang',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),

              // Simulation Bar
              Positioned(
                bottom: 6,
                left: 12,
                right: 12,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text(
                        'SIMULASI: ',
                        style: TextStyle(
                          fontSize: 9,
                          fontFamily: 'RobotoMono',
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      for (final item in order.items) ...[
                        InkWell(
                          onTap: () => _simulateScanSku(item.sku),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF38BDF8)),
                            ),
                            child: Text(
                              '${item.sku} (${item.fromRack})',
                              style: const TextStyle(
                                fontSize: 10,
                                fontFamily: 'RobotoMono',
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom Inspection & Pick Form
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -4)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_activeScannedItem != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _activeScannedItem!.sku,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'RobotoMono',
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Rak: ${_activeScannedItem!.fromRack}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'RobotoMono',
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _activeScannedItem!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Target Order', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        Text(
                          '${_activeScannedItem!.orderQty} ${_activeScannedItem!.unit}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'RobotoMono',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Steppers: Picked vs Packed
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Picked Qty (Terambil)',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSmallStepperBtn(
                                  icon: Icons.remove_rounded,
                                  onTap: () {
                                    if (_activePickedQty > 0) {
                                      setState(() => _activePickedQty--);
                                    }
                                  },
                                ),
                                Text(
                                  '$_activePickedQty',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'RobotoMono',
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                _buildSmallStepperBtn(
                                  icon: Icons.add_rounded,
                                  onTap: () {
                                    if (_activePickedQty < _activeScannedItem!.orderQty) {
                                      setState(() => _activePickedQty++);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Packed Qty (Dipacking)',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF5B21B6)),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSmallStepperBtn(
                                  icon: Icons.remove_rounded,
                                  onTap: () {
                                    if (_activePackedQty > 0) {
                                      setState(() => _activePackedQty--);
                                    }
                                  },
                                ),
                                Text(
                                  '$_activePackedQty',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'RobotoMono',
                                    color: Color(0xFF5B21B6),
                                  ),
                                ),
                                _buildSmallStepperBtn(
                                  icon: Icons.add_rounded,
                                  onTap: () {
                                    if (_activePackedQty < _activeScannedItem!.orderQty) {
                                      setState(() => _activePackedQty++);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Primary Save Item Button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _saveCurrentItemPick,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text(
                    'Simpan & Lanjut Item Berikutnya',
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
              const SizedBox(height: 8),

              // Secondary Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showManualInputDialog,
                      icon: const Icon(Icons.keyboard_outlined, size: 16),
                      label: const Text('Input Manual', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isCommitting ? null : () => _commitDispatch(order),
                      icon: _isCommitting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.local_shipping_rounded, size: 16),
                      label: Text(
                        _isCommitting ? 'Menyimpan...' : 'Commit Dispatch',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallStepperBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Icon(icon, size: 15, color: AppColors.textPrimary),
      ),
    );
  }
}
