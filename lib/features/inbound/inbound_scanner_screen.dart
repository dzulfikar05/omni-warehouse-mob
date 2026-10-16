import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/omni_snackbar.dart';
import 'inbound_model.dart';
import 'inbound_repository.dart';

class InboundScannerScreen extends ConsumerStatefulWidget {
  const InboundScannerScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<InboundScannerScreen> createState() => _InboundScannerScreenState();
}

class _InboundScannerScreenState extends ConsumerState<InboundScannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  bool _isFlashOn = false;
  bool _isAudioBeepOn = true;
  bool _isCommitting = false;

  InboundItem? _activeScannedItem;
  int _activeGoodQty = 0;
  int _activeDamagedQty = 0;
  String _activeTargetRack = 'RACK-A1-01';

  final List<String> _availableRacks = [
    'RACK-A1-01',
    'RACK-A1-02',
    'RACK-A2-01',
    'RACK-B1-01',
    'RACK-B1-02',
    'STAGING-S01',
  ];

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
      final manifest = ref.read(inboundRepositoryProvider.notifier).getManifestByCode(widget.code);
      if (manifest != null && manifest.items.isNotEmpty) {
        // Pre-select first item for immediate inspection
        _selectItem(manifest.items.first);
      }
    });
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  void _selectItem(InboundItem item) {
    setState(() {
      _activeScannedItem = item;
      _activeGoodQty = item.goodQty == 0 ? 1 : item.goodQty;
      _activeDamagedQty = item.damagedQty;
      _activeTargetRack = item.targetRack ?? 'RACK-A1-01';
    });
  }

  void _simulateScanSku(String sku) {
    final manifest = ref.read(inboundRepositoryProvider.notifier).getManifestByCode(widget.code);
    if (manifest == null) return;

    final match = manifest.items.firstWhere(
      (it) => it.sku.toLowerCase() == sku.toLowerCase(),
      orElse: () => manifest.items.first,
    );

    HapticFeedback.mediumImpact();
    _selectItem(match);

    OmniSnackbar.show(
      context,
      message: 'Barcode terdeteksi: ${match.sku} - ${match.name}',
      icon: Icons.qr_code_scanner_rounded,
    );
  }

  void _simulateScanRack(String rack) {
    HapticFeedback.lightImpact();
    setState(() {
      _activeTargetRack = rack;
    });

    OmniSnackbar.show(
      context,
      message: 'Barcode Rak terverifikasi: $rack',
      icon: Icons.place_rounded,
    );
  }

  void _saveCurrentItemTally() {
    if (_activeScannedItem == null) return;

    HapticFeedback.mediumImpact();
    ref.read(inboundRepositoryProvider.notifier).updateItemTally(
          manifestCode: widget.code,
          itemId: _activeScannedItem!.id,
          goodQty: _activeGoodQty,
          damagedQty: _activeDamagedQty,
          targetRack: _activeTargetRack,
        );

    OmniSnackbar.show(
      context,
      message: '${_activeScannedItem!.sku} disimpan: $_activeGoodQty Good, $_activeDamagedQty Rusak ke $_activeTargetRack',
      icon: Icons.check_circle_rounded,
    );

    // Auto-advance to next item if available
    final manifest = ref.read(inboundRepositoryProvider.notifier).getManifestByCode(widget.code);
    if (manifest != null) {
      final uncompleted = manifest.items.where((it) => it.id != _activeScannedItem!.id && !it.isCompleted);
      if (uncompleted.isNotEmpty) {
        _selectItem(uncompleted.first);
      }
    }
  }

  void _commitInbound(InboundManifest manifest) async {
    final hasDamaged = manifest.items.any((it) => it.damagedQty > 0);

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
              child: const Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Commit Penerimaan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah seluruh muatan ${manifest.code} (${manifest.scannedUnits} unit) telah tuntas diverifikasi fisik?',
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            if (hasDamaged)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.dangerBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ditemukan ${manifest.damagedUnits} unit barang rusak. Data akan otomatis masuk ke Karantina di web Laravel.',
                        style: const TextStyle(fontSize: 11, color: AppColors.danger),
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
            child: const Text('Ya, Commit Inbound'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isCommitting = true);
    await Future.delayed(const Duration(milliseconds: 900));

    if (mounted) {
      ref.read(inboundRepositoryProvider.notifier).commitManifest(widget.code);
      setState(() => _isCommitting = false);

      OmniSnackbar.show(
        context,
        message: 'Manifes ${manifest.code} berhasil di-commit! Stok bertambah di database.',
        icon: Icons.cloud_done_rounded,
      );

      context.go('/inbound');
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
              'Input Manual Barcode / SKU',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gunakan jika barcode fisik pada kemasan barang robek atau pudar.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: barcodeController,
              autofocus: true,
              style: const TextStyle(fontFamily: 'RobotoMono', fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Ketik SKU atau Barcode EAN-13...',
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
                child: const Text('Verifikasi & Masukkan Item', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manifests = ref.watch(inboundRepositoryProvider);
    final manifest = manifests.firstWhere(
      (m) => m.code.toLowerCase() == widget.code.toLowerCase(),
      orElse: () => manifests.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Clean light slate-100
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
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.go('/inbound'),
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 20),
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
                          manifest.code,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'RobotoMono',
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: manifest.status.bg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            manifest.status.label,
                            style: TextStyle(
                              color: manifest.status.color,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'RobotoMono',
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      manifest.supplier,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Flashlight toggle
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
                  color: _isFlashOn ? const Color(0xFFFACC15) : AppColors.textSecondary,
                  size: 20,
                ),
              ),
              // Audio Beeper toggle
              IconButton(
                onPressed: () {
                  setState(() => _isAudioBeepOn = !_isAudioBeepOn);
                },
                icon: Icon(
                  _isAudioBeepOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: _isAudioBeepOn ? AppColors.primary : AppColors.textSecondary,
                  size: 20,
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
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_turned_in_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Progres Validasi Koli',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${manifest.scannedUnits} / ${manifest.totalUnits} Units (${(manifest.progressPercentage * 100).toInt()}%)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'RobotoMono',
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: manifest.progressPercentage,
                              minHeight: 5,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                manifest.isFullyCompleted ? AppColors.success : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Viewfinder Scanner & Quick Simulator
              Expanded(
                flex: 3,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Simulated Camera Feed Background
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF020617)],
                          radius: 0.9,
                        ),
                      ),
                    ),

                    // Reticle Box
                    Container(
                      width: 240,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
                      ),
                      child: Stack(
                        children: [
                          // Corner Accents
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: AppColors.primary, width: 3.5),
                                  left: BorderSide(color: AppColors.primary, width: 3.5),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: AppColors.primary, width: 3.5),
                                  right: BorderSide(color: AppColors.primary, width: 3.5),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: AppColors.primary, width: 3.5),
                                  left: BorderSide(color: AppColors.primary, width: 3.5),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: AppColors.primary, width: 3.5),
                                  right: BorderSide(color: AppColors.primary, width: 3.5),
                                ),
                              ),
                            ),
                          ),

                          // Animated Sweeping Laser Line (Blue Laser)
                          AnimatedBuilder(
                            animation: _laserAnimation,
                            builder: (context, child) {
                              return Positioned(
                                top: _laserAnimation.value * 150,
                                left: 6,
                                right: 6,
                                child: Container(
                                  height: 2,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF60A5FA),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFF60A5FA),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          // Center Crosshair
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

                    // Top status pill in Viewfinder
                    Positioned(
                      top: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.primaryBorder),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt_outlined, size: 12, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              'AUTO-FOCUS READY',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontFamily: 'RobotoMono',
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom instruction pill
                    Positioned(
                      bottom: 46,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text(
                          'Arahkan kamera ke Barcode Koli / SKU',
                          style: TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),

                    // Quick Simulation Bar for easy testing on Windows/Mobile
                    Positioned(
                      bottom: 6,
                      left: 12,
                      right: 12,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text(
                              'SIMULASI SCAN: ',
                              style: TextStyle(
                                fontSize: 9,
                                fontFamily: 'RobotoMono',
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(width: 6),
                            for (final item in manifest.items) ...[
                              InkWell(
                                onTap: () => _simulateScanSku(item.sku),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.primaryBorder),
                                  ),
                                  child: Text(
                                    item.sku,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontFamily: 'RobotoMono',
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            InkWell(
                              onTap: () => _simulateScanRack('RACK-A1-02'),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.primaryBorder),
                                ),
                                child: const Text(
                                  'Rak A1-02',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'RobotoMono',
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Inspection & Putaway Workspace (White Bottom Card)
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_activeScannedItem != null) ...[
                      // SKU Header
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
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _activeScannedItem!.category,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
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
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Target PO', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                              Text(
                                '${_activeScannedItem!.expectedQty} ${_activeScannedItem!.unit}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'RobotoMono',
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Steppers Row: Good Qty vs Damaged Qty
                      Row(
                        children: [
                          // Good Qty Stepper
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Kondisi Bagus (Good)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildStepperBtn(
                                        icon: Icons.remove_rounded,
                                        onTap: () {
                                          if (_activeGoodQty > 0) {
                                            HapticFeedback.selectionClick();
                                            setState(() => _activeGoodQty--);
                                          }
                                        },
                                      ),
                                      Text(
                                        '$_activeGoodQty',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'RobotoMono',
                                          color: Color(0xFF166534),
                                        ),
                                      ),
                                      _buildStepperBtn(
                                        icon: Icons.add_rounded,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() => _activeGoodQty++);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Damaged Qty Stepper
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFECDD3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Barang Rusak (Damaged)',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF9F1239),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildStepperBtn(
                                        icon: Icons.remove_rounded,
                                        onTap: () {
                                          if (_activeDamagedQty > 0) {
                                            HapticFeedback.selectionClick();
                                            setState(() => _activeDamagedQty--);
                                          }
                                        },
                                      ),
                                      Text(
                                        '$_activeDamagedQty',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'RobotoMono',
                                          color: Color(0xFF9F1239),
                                        ),
                                      ),
                                      _buildStepperBtn(
                                        icon: Icons.add_rounded,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() => _activeDamagedQty++);
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
                      const SizedBox(height: 10),

                      // Target Rack Selector Strip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.place_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            const Text(
                              'Lokasi Rak Alokasi:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                            const Spacer(),
                            DropdownButton<String>(
                              value: _availableRacks.contains(_activeTargetRack) ? _activeTargetRack : _availableRacks.first,
                              underline: const SizedBox(),
                              isDense: true,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'RobotoMono',
                                color: AppColors.primary,
                              ),
                              items: _availableRacks.map((rack) {
                                return DropdownMenuItem(
                                  value: rack,
                                  child: Text(rack),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _activeTargetRack = val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Primary Save & Advance Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _saveCurrentItemTally,
                        icon: const Icon(Icons.save_rounded, size: 18),
                        label: const Text(
                          'Simpan & Lanjut Rak Alokasi',
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
                    const SizedBox(height: 8),

                    // Dual Secondary Actions: Input Manual Barcode & Commit Inbound
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showManualInputDialog,
                            icon: const Icon(Icons.keyboard_outlined, size: 16),
                            label: const Text(
                              'Input Manual',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isCommitting ? null : () => _commitInbound(manifest),
                            icon: _isCommitting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.cloud_upload_outlined, size: 16),
                            label: Text(
                              _isCommitting ? 'Menyimpan...' : 'Commit Selesai',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepperBtn({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }
}
