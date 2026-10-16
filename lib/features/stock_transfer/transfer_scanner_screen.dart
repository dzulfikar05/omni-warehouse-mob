import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/omni_snackbar.dart';
import 'transfer_model.dart';
import 'transfer_repository.dart';

enum ScanStep {
  scanProduct,
  scanOriginRack,
  scanTargetRack,
  confirmTransfer,
}

class TransferScannerScreen extends ConsumerStatefulWidget {
  const TransferScannerScreen({super.key});

  @override
  ConsumerState<TransferScannerScreen> createState() => _TransferScannerScreenState();
}

class _TransferScannerScreenState extends ConsumerState<TransferScannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  bool _isFlashOn = false;
  bool _isAudioBeepOn = true;
  ScanStep _currentStep = ScanStep.scanProduct;

  // Selected values during scanning
  Map<String, dynamic>? _selectedProduct;
  String _originRack = '';
  String _targetRack = '';
  int _transferQty = 1;

  final List<Map<String, dynamic>> _catalog = [
    {
      'sku': 'SKU-EL-091',
      'barcode': '8991234509101',
      'name': 'Kabel Fiber Optic Drop Core 100m',
      'unit': 'Roll',
      'stock': 200,
      'defaultRack': 'RACK-A1-01',
    },
    {
      'sku': 'SKU-ME-110',
      'barcode': '8991234501101',
      'name': 'Panel MCB 3 Phase 63A Sch-Electric',
      'unit': 'Box',
      'stock': 40,
      'defaultRack': 'RACK-B1-01',
    },
    {
      'sku': 'SKU-EL-092',
      'barcode': '8991234509102',
      'name': 'Optical Distribution Point (ODP) 16P',
      'unit': 'Unit',
      'stock': 75,
      'defaultRack': 'RACK-A1-02',
    },
  ];

  final List<String> _quickRacks = [
    'RACK-A1-01',
    'RACK-A1-02',
    'RACK-B1-01',
    'RACK-B1-02',
    'RACK-A2-01',
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
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  void _onScanProduct(Map<String, dynamic> product) {
    if (_isAudioBeepOn) HapticFeedback.mediumImpact();
    setState(() {
      _selectedProduct = product;
      _originRack = product['defaultRack'] as String;
      _currentStep = ScanStep.scanOriginRack;
    });

    OmniSnackbar.show(
      context,
      message: 'Barang terdeteksi: ${product['sku']} (${product['name']})',
      icon: Icons.qr_code_scanner_rounded,
    );
  }

  void _onScanOriginRack(String rack) {
    if (_isAudioBeepOn) HapticFeedback.lightImpact();
    setState(() {
      _originRack = rack;
      _currentStep = ScanStep.scanTargetRack;
    });

    OmniSnackbar.show(
      context,
      message: 'Rak Asal terkonfirmasi: $rack',
      icon: Icons.location_on_outlined,
    );
  }

  void _onScanTargetRack(String rack) {
    if (rack.toLowerCase() == _originRack.toLowerCase()) {
      OmniSnackbar.show(
        context,
        message: 'Rak tujuan tidak boleh sama dengan rak asal!',
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    if (_isAudioBeepOn) HapticFeedback.mediumImpact();
    setState(() {
      _targetRack = rack;
      _currentStep = ScanStep.confirmTransfer;
    });
  }

  void _executeTransfer() {
    if (_selectedProduct == null || _originRack.isEmpty || _targetRack.isEmpty) return;

    final refCode = 'TRF-2026-${(1000 + DateTime.now().millisecond)}';
    final maxStock = _selectedProduct!['stock'] as int;

    final newItem = StockTransferItem(
      id: 'trf-${DateTime.now().millisecondsSinceEpoch}',
      referenceNumber: refCode,
      type: TransferType.binToBin,
      sku: _selectedProduct!['sku'] as String,
      barcode: _selectedProduct!['barcode'] as String,
      productName: _selectedProduct!['name'] as String,
      fromLocation: _originRack,
      toLocation: _targetRack,
      quantity: _transferQty,
      unit: _selectedProduct!['unit'] as String,
      status: TransferStatus.completed,
      createdAt: 'Baru saja',
      operatorName: 'Budi Santoso',
      notes: 'Dipindahkan via Rapid Scan Camera',
      availableStock: maxStock - _transferQty,
    );

    ref.read(transferRepositoryProvider.notifier).addTransfer(newItem);

    OmniSnackbar.show(
      context,
      message: 'Pindah rak $refCode berhasil dieksekusi!',
      icon: Icons.check_circle_rounded,
    );

    context.go('/more/transfer');
  }

  void _resetSteps() {
    setState(() {
      _selectedProduct = null;
      _originRack = '';
      _targetRack = '';
      _transferQty = 1;
      _currentStep = ScanStep.scanProduct;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                // Top Action Bar
                _buildTopBar(),

                // Step Progress Indicator
                _buildStepHeader(),

                // Viewfinder / Camera Simulation
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildCameraViewfinder(),
                      Positioned(
                        bottom: 12,
                        left: 16,
                        right: 16,
                        child: _buildSimulationChips(),
                      ),
                    ],
                  ),
                ),

                // Bottom Panel
                _buildBottomPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 4),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pindah Rak Cepat',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Verifikasi 3-Langkah WMS',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
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
                  color: _isAudioBeepOn ? AppColors.primary : AppColors.textSecondary,
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

  Widget _buildStepHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _buildStepNode(
            stepNumber: '1',
            label: 'Barang',
            isActive: _currentStep == ScanStep.scanProduct,
            isDone: _selectedProduct != null,
          ),
          _buildStepDivider(_selectedProduct != null),
          _buildStepNode(
            stepNumber: '2',
            label: 'Rak Asal',
            isActive: _currentStep == ScanStep.scanOriginRack,
            isDone: _originRack.isNotEmpty && _currentStep != ScanStep.scanOriginRack,
          ),
          _buildStepDivider(_targetRack.isNotEmpty || _currentStep == ScanStep.confirmTransfer),
          _buildStepNode(
            stepNumber: '3',
            label: 'Rak Tujuan',
            isActive: _currentStep == ScanStep.scanTargetRack || _currentStep == ScanStep.confirmTransfer,
            isDone: _targetRack.isNotEmpty,
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode({
    required String stepNumber,
    required String label,
    required bool isActive,
    required bool isDone,
  }) {
    Color bg = const Color(0xFFE2E8F0);
    Color textColor = AppColors.textSecondary;

    if (isDone) {
      bg = AppColors.success;
      textColor = Colors.white;
    } else if (isActive) {
      bg = AppColors.primary;
      textColor = Colors.white;
    }

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : Text(
                    stepNumber,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive || isDone ? FontWeight.w700 : FontWeight.w500,
            color: isActive
                ? AppColors.primary
                : (isDone ? AppColors.textPrimary : AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(bool isDone) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isDone ? AppColors.success : const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _buildCameraViewfinder() {
    String instruction = '';
    switch (_currentStep) {
      case ScanStep.scanProduct:
        instruction = 'Arahkan kamera ke Barcode Barang';
        break;
      case ScanStep.scanOriginRack:
        instruction = 'Scan Label Barcode Rak Asal';
        break;
      case ScanStep.scanTargetRack:
        instruction = 'Scan Label Barcode Rak Tujuan';
        break;
      case ScanStep.confirmTransfer:
        instruction = 'Verifikasi kuantitas & konfirmasi';
        break;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          color: const Color(0xFF090D16),
          width: double.infinity,
          height: double.infinity,
        ),
        // Reticle
        Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.8),
              width: 2,
            ),
          ),
          child: AnimatedBuilder(
            animation: _laserAnimation,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: _laserAnimation.value * 250,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 2,
                      decoration: const BoxDecoration(
                        color: Color(0xFF60A5FA),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF60A5FA),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
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
          top: 30,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              instruction,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimulationChips() {
    if (_currentStep == ScanStep.scanProduct) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SIMULASI SCAN BARANG:',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                fontFamily: 'RobotoMono',
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _catalog.map((prod) {
                return InkWell(
                  onTap: () => _onScanProduct(prod),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: Text(
                      '${prod['sku']} (${prod['stock']})',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'RobotoMono',
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    } else if (_currentStep == ScanStep.scanOriginRack || _currentStep == ScanStep.scanTargetRack) {
      final isTarget = _currentStep == ScanStep.scanTargetRack;
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTarget ? 'SIMULASI SCAN RAK TUJUAN:' : 'SIMULASI SCAN RAK ASAL:',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                fontFamily: 'RobotoMono',
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _quickRacks.map((rack) {
                return InkWell(
                  onTap: () => isTarget ? _onScanTargetRack(rack) : _onScanOriginRack(rack),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      rack,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'RobotoMono',
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedProduct != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedProduct!['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${_selectedProduct!['sku']} • Tersedia: ${_selectedProduct!['stock']} ${_selectedProduct!['unit']}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _resetSteps,
                  child: const Text('Reset', style: TextStyle(fontSize: 12, color: AppColors.danger)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Origin & Target Pills
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DARI RAK', style: TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                        Text(
                          _originRack.isEmpty ? 'Menunggu...' : _originRack,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFFD97706)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('KE RAK', style: TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                        Text(
                          _targetRack.isEmpty ? 'Menunggu...' : _targetRack,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _targetRack.isEmpty ? AppColors.textMuted : const Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (_currentStep == ScanStep.confirmTransfer) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Jumlah Pindah:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.textSecondary),
                      onPressed: () {
                        if (_transferQty > 1) {
                          setState(() => _transferQty--);
                        }
                      },
                    ),
                    Text(
                      '$_transferQty ${_selectedProduct!['unit']}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, fontFamily: 'RobotoMono'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                      onPressed: () {
                        final max = _selectedProduct!['stock'] as int;
                        if (_transferQty < max) {
                          setState(() => _transferQty++);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _executeTransfer,
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text(
                  'Eksekusi Pindah Rak Sekarang',
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
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Batal & Kembali', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
