import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/omni_snackbar.dart';
import 'transfer_model.dart';
import 'transfer_repository.dart';

class TransferFormScreen extends ConsumerStatefulWidget {
  const TransferFormScreen({super.key});

  @override
  ConsumerState<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends ConsumerState<TransferFormScreen> {
  TransferType _selectedType = TransferType.binToBin;

  final List<Map<String, dynamic>> _catalogProducts = [
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
      'sku': 'SKU-NT-008',
      'barcode': '8991234503011',
      'name': 'Patch Cord SC/UPC-SC/APC 3M Simplex',
      'unit': 'Koli',
      'stock': 80,
      'defaultRack': 'Gudang Belakang',
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

  late Map<String, dynamic> _selectedProduct;
  final TextEditingController _fromLocationController = TextEditingController();
  final TextEditingController _toLocationController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  final TextEditingController _notesController = TextEditingController();

  final List<String> _warehouseList = [
    'Gudang Utama Malang',
    'Cabang Surabaya Rungkut',
    'Cabang Sidoarjo Kota',
    'Toko Cabang Dinoyo',
  ];

  String _selectedFromWarehouse = 'Gudang Utama Malang';
  String _selectedToWarehouse = 'Cabang Surabaya Rungkut';

  @override
  void initState() {
    super.initState();
    _selectedProduct = _catalogProducts.first;
    _updateLocationDefaults();
  }

  @override
  void dispose() {
    _fromLocationController.dispose();
    _toLocationController.dispose();
    _qtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateLocationDefaults() {
    switch (_selectedType) {
      case TransferType.binToBin:
        _fromLocationController.text = _selectedProduct['defaultRack'] as String;
        _toLocationController.text = 'RACK-B1-02';
        break;
      case TransferType.interWarehouse:
        _fromLocationController.text = _selectedFromWarehouse;
        _toLocationController.text = _selectedToWarehouse;
        break;
      case TransferType.replenishment:
        _fromLocationController.text = 'Gudang Belakang (Simpan)';
        _toLocationController.text = 'Display Etalase Depan (Kasir)';
        break;
    }
  }

  void _submitTransfer() {
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    final maxStock = _selectedProduct['stock'] as int;

    if (qty <= 0) {
      OmniSnackbar.show(
        context,
        message: 'Jumlah transfer harus lebih dari 0',
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    if (qty > maxStock) {
      OmniSnackbar.show(
        context,
        message: 'Jumlah transfer ($qty) melebihi stok yang tersedia ($maxStock)',
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    final fromLoc = _selectedType == TransferType.interWarehouse
        ? _selectedFromWarehouse
        : _fromLocationController.text.trim();
    final toLoc = _selectedType == TransferType.interWarehouse
        ? _selectedToWarehouse
        : _toLocationController.text.trim();

    if (fromLoc.toLowerCase() == toLoc.toLowerCase()) {
      OmniSnackbar.show(
        context,
        message: 'Lokasi tujuan tidak boleh sama dengan lokasi asal!',
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    final prefix = _selectedType == TransferType.replenishment ? 'REP' : 'TRF';
    final randomSuffix = (1000 + DateTime.now().millisecond).toString();
    final refNumber = '$prefix-2026-$randomSuffix';

    final newItem = StockTransferItem(
      id: 'trf-${DateTime.now().millisecondsSinceEpoch}',
      referenceNumber: refNumber,
      type: _selectedType,
      sku: _selectedProduct['sku'] as String,
      barcode: _selectedProduct['barcode'] as String,
      productName: _selectedProduct['name'] as String,
      fromLocation: fromLoc,
      toLocation: toLoc,
      quantity: qty,
      unit: _selectedProduct['unit'] as String,
      status: _selectedType == TransferType.interWarehouse
          ? TransferStatus.inTransit
          : TransferStatus.completed,
      createdAt: 'Baru saja',
      operatorName: 'Budi Santoso',
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      availableStock: maxStock - qty,
    );

    ref.read(transferRepositoryProvider.notifier).addTransfer(newItem);

    OmniSnackbar.show(
      context,
      message: 'Mutasi $refNumber berhasil dibuat & dicatat!',
      icon: Icons.check_circle_rounded,
    );

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final maxStock = _selectedProduct['stock'] as int;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Buat Mutasi Stok',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Segmented Type Selector
              _buildTypeSelector(),
              const SizedBox(height: 16),

              // Product Selector Card
              _buildProductSelectorCard(),
              const SizedBox(height: 14),

              // Origin & Destination Card
              _buildLocationCard(),
              const SizedBox(height: 14),

              // Quantity Stepper Card
              _buildQuantityCard(maxStock),
              const SizedBox(height: 14),

              // Notes Card
              _buildNotesCard(),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        constraints: const BoxConstraints(maxWidth: 480),
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
              onPressed: _submitTransfer,
              icon: const Icon(Icons.check_rounded, size: 20),
              label: Text(
                _selectedType == TransferType.interWarehouse
                    ? 'Kirim Mutasi Antar Cabang'
                    : 'Konfirmasi Mutasi Stok',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedType.color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTypeTab(
            type: TransferType.binToBin,
            title: 'Pindah Rak',
            subtitle: 'Bin-to-Bin',
          ),
          _buildTypeTab(
            type: TransferType.interWarehouse,
            title: 'Kirim Cabang',
            subtitle: 'In-Transit',
          ),
          _buildTypeTab(
            type: TransferType.replenishment,
            title: 'Display Toko',
            subtitle: 'UMKM Fast',
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab({
    required TransferType type,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = type;
            _updateLocationDefaults();
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? type.color : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductSelectorCard() {
    return Container(
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
            'PILIH PRODUK',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFamily: 'RobotoMono',
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: _selectedProduct,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            selectedItemBuilder: (context) {
              return _catalogProducts.map((p) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${p['sku']} - ${p['name']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              }).toList();
            },
            items: _catalogProducts.map((p) {
              return DropdownMenuItem<Map<String, dynamic>>(
                value: p,
                child: Text(
                  '${p['sku']} • ${p['name']} (${p['stock']} ${p['unit']})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedProduct = val;
                  _updateLocationDefaults();
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sync_alt_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text(
                'RUTE PERPINDAHAN STOK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'RobotoMono',
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Origin
          const Text(
            'Lokasi Asal (Dari):',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          if (_selectedType == TransferType.interWarehouse)
            DropdownButtonFormField<String>(
              initialValue: _selectedFromWarehouse,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              items: _warehouseList
                  .map((w) => DropdownMenuItem(value: w, child: Text(w, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedFromWarehouse = val);
              },
            )
          else
            TextField(
              controller: _fromLocationController,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

          const SizedBox(height: 14),

          // Destination
          const Text(
            'Lokasi Tujuan (Ke):',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          if (_selectedType == TransferType.interWarehouse)
            DropdownButtonFormField<String>(
              initialValue: _selectedToWarehouse,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              items: _warehouseList
                  .map((w) => DropdownMenuItem(value: w, child: Text(w, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedToWarehouse = val);
              },
            )
          else
            TextField(
              controller: _toLocationController,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                prefixIcon: const Icon(Icons.flag_outlined, size: 18, color: AppColors.primary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        ],
      ),
    );
  }

  Widget _buildQuantityCard(int maxStock) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'JUMLAH MUTASI',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'RobotoMono',
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Tersedia: $maxStock ${_selectedProduct['unit']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'RobotoMono',
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStepButton(
                icon: Icons.remove_rounded,
                onTap: () {
                  final cur = int.tryParse(_qtyController.text) ?? 1;
                  if (cur > 1) {
                    setState(() => _qtyController.text = '${cur - 1}');
                  }
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'RobotoMono',
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    suffixText: _selectedProduct['unit'] as String,
                    suffixStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
              ),
              const SizedBox(width: 10),
              _buildStepButton(
                icon: Icons.add_rounded,
                onTap: () {
                  final cur = int.tryParse(_qtyController.text) ?? 0;
                  if (cur < maxStock) {
                    setState(() => _qtyController.text = '${cur + 1}');
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildQuickQtyChip('+5', 5, maxStock),
              const SizedBox(width: 6),
              _buildQuickQtyChip('+10', 10, maxStock),
              const SizedBox(width: 6),
              _buildQuickQtyChip('MAX', maxStock, maxStock),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildQuickQtyChip(String label, int value, int maxStock) {
    return InkWell(
      onTap: () {
        if (label == 'MAX') {
          setState(() => _qtyController.text = '$maxStock');
        } else {
          final cur = int.tryParse(_qtyController.text) ?? 0;
          final next = (cur + value).clamp(1, maxStock);
          setState(() => _qtyController.text = '$next');
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            fontFamily: 'RobotoMono',
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
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
            'CATATAN / NOMOR SURAT JALAN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFamily: 'RobotoMono',
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Opsional: misal "Via ekspedisi Lalamove" atau "Pindah etalase kasir"',
              hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
        ],
      ),
    );
  }
}
