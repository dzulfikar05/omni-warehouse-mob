import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/omni_snackbar.dart';
import 'transfer_transaction_model.dart';
import 'transfer_transaction_repository.dart';

class TransferTransactionFormScreen extends ConsumerStatefulWidget {
  const TransferTransactionFormScreen({super.key, this.transaction});

  final TransferTransaction? transaction;

  @override
  ConsumerState<TransferTransactionFormScreen> createState() =>
      _TransferTransactionFormScreenState();
}

class _TransferTransactionFormScreenState
    extends ConsumerState<TransferTransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final List<_TransferFormRow> _rows = [];
  TransferMasterOptions? _options;
  String? _loadError;
  String? _submitError;
  bool _isLoading = true;
  bool _isSubmitting = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.transaction?.notes ?? '';
    _rows.addAll(
      widget.transaction?.items.map(_TransferFormRow.fromTransaction) ??
          [_TransferFormRow()],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOptions());
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final slug = ref.read(authProvider).tenantSlug;
      if (slug == null || slug.isEmpty) {
        throw Exception('Tenant belum dipilih. Silakan login kembali.');
      }
      final options = await ref
          .read(transferTransactionRepositoryProvider)
          .getOptions(slug);
      if (!mounted) return;
      setState(() {
        _options = options;
        _isLoading = false;
        for (final row in _rows) {
          if (!options.skus.any((sku) => sku.id == row.skuId)) {
            row.skuId = null;
          }
          if (!options.locations.any(
            (location) => location.id == row.fromLocationId,
          )) {
            row.fromLocationId = null;
          }
          if (!options.locations.any(
            (location) => location.id == row.toLocationId,
          )) {
            row.toLocationId = null;
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  void _addRow() {
    setState(() => _rows.add(_TransferFormRow()));
  }

  void _removeRow(int index) {
    if (_rows.length == 1) return;
    setState(() {
      _rows.removeAt(index).dispose();
    });
  }

  Future<void> _selectExpiryDate(_TransferFormRow row) async {
    final today = DateTime.now();
    final initial = DateTime.tryParse(row.expiryDateController.text) ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 20),
    );
    if (picked != null) {
      row.expiryDateController.text =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (_options == null || !_formKey.currentState!.validate()) return;
    for (var index = 0; index < _rows.length; index++) {
      final row = _rows[index];
      if (row.fromLocationId != null &&
          row.fromLocationId == row.toLocationId) {
        setState(() => _submitError =
            'Lokasi asal dan tujuan item ${index + 1} harus berbeda.');
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      final slug = ref.read(authProvider).tenantSlug!;
      final items = _rows.map((row) {
        final item = <String, dynamic>{
          'sku_id': row.skuId!,
          'from_location_id': row.fromLocationId!,
          'to_location_id': row.toLocationId!,
          'quantity': int.parse(row.quantityController.text),
        };
        if (_isEditing && row.batchNumberController.text.trim().isNotEmpty) {
          item['batch_number'] = row.batchNumberController.text.trim();
        }
        if (_isEditing && row.expiryDateController.text.trim().isNotEmpty) {
          item['expiry_date'] = row.expiryDateController.text.trim();
        }
        return item;
      }).toList();
      final repository = ref.read(transferTransactionRepositoryProvider);
      if (_isEditing) {
        await repository.updateTransaction(
          slug,
          widget.transaction!.code,
          items: items,
          notes: _notesController.text.trim(),
        );
      } else {
        await repository.createTransaction(
          slug,
          items: items,
          notes: _notesController.text.trim(),
        );
      }
      if (!mounted) return;
      OmniSnackbar.show(
        context,
        message: _isEditing
            ? 'Draft mutasi berhasil diperbarui.'
            : 'Transaksi mutasi stok berhasil dibuat.',
        icon: Icons.check_circle_rounded,
      );
      context.pop(true);
    } catch (error) {
      if (mounted) setState(() => _submitError = error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const emptyOptions = TransferMasterOptions(
      warehouses: [],
      locations: [],
      skus: [],
    );
    final options = _options ?? emptyOptions;
    final totalUnits = _rows.fold<int>(
      0,
      (sum, row) => sum + (int.tryParse(row.quantityController.text) ?? 0),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Ubah Draft Mutasi' : 'Buat Mutasi Stok'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                if (_isLoading) ...[
                  _buildLoadingBanner(),
                  const SizedBox(height: 12),
                ] else if (_loadError != null) ...[
                  _buildLoadError(),
                  const SizedBox(height: 12),
                ] else if (options.skus.isEmpty ||
                    options.locations.isEmpty) ...[
                  _buildEmptyMasterBanner(options),
                  const SizedBox(height: 12),
                ],
                _buildIntro(options),
                const SizedBox(height: 14),
                ...List.generate(
                  _rows.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildItemCard(index, options),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Tambah baris item mutasi'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    side: const BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildNotesCard(),
                if (_submitError != null) ...[
                  const SizedBox(height: 12),
                  _buildErrorBanner(_submitError!),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Align(
          heightFactor: 1,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_rows.length} item · $totalUnits unit',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ||
                            _options == null ||
                            _options!.skus.isEmpty ||
                            _options!.locations.isEmpty
                        ? null
                        : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.swap_horiz_rounded, size: 19),
                    label: Text(
                      _isSubmitting
                          ? 'Memproses...'
                          : _isEditing
                          ? 'Simpan perubahan'
                          : 'Proses mutasi batch',
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
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
      ),
    );
  }

  Widget _buildIntro(TransferMasterOptions options) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(11),
          ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                color: AppColors.primary,
              ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing
                    ? 'Perbarui draft transfer'
                    : 'Mutasi beberapa item sekaligus',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${options.skus.length} SKU · ${options.locations.length} lokasi tersedia',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildItemCard(int index, TransferMasterOptions options) {
    final row = _rows[index];
    TransferSku? selectedSku;
    for (final sku in options.skus) {
      if (sku.id == row.skuId) {
        selectedSku = sku;
        break;
      }
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 25,
                height: 25,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'ITEM MUTASI',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              if (_rows.length > 1)
                IconButton(
                  onPressed: () => _removeRow(index),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          _buildSkuDropdown(row, options.skus),
          if (selectedSku != null) ...[
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selectedSku.name} · SKU ${selectedSku.code}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Barcode: ${selectedSku.barcode.isEmpty ? '-' : selectedSku.barcode}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  if (selectedSku.availableStock != null)
                    Text(
                      'Total stok tersedia: ${selectedSku.availableStock} ${selectedSku.unit}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 11),
          _buildLocationDropdown(
            row: row,
            isOrigin: true,
            locations: options.locations,
          ),
          const SizedBox(height: 10),
          _buildLocationDropdown(
            row: row,
            isOrigin: false,
            locations: options.locations,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: row.quantityController,
            keyboardType: TextInputType.number,
            decoration: _inputDecoration('Qty unit', Icons.numbers_rounded),
            validator: (value) {
              final quantity = int.tryParse(value?.trim() ?? '');
              if (quantity == null || quantity < 1) return 'Qty minimal 1';
              final stock = selectedSku?.availableStock;
              if (stock != null && quantity > stock) {
                return 'Stok tersedia hanya $stock';
              }
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: row.batchNumberController,
              decoration: _inputDecoration(
                'Batch / lot (opsional)',
                Icons.inventory_2_outlined,
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 5),
            TextFormField(
              controller: row.expiryDateController,
              readOnly: true,
              onTap: () => _selectExpiryDate(row),
              decoration: _inputDecoration(
                'Tanggal kedaluwarsa (opsional)',
                Icons.calendar_today_rounded,
              ).copyWith(
                    suffixIcon: const Icon(Icons.date_range_rounded, size: 18),
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSkuDropdown(_TransferFormRow row, List<TransferSku> skus) {
    return DropdownButtonFormField<int>(
      initialValue: row.skuId,
      isExpanded: true,
      decoration:
          _inputDecoration('Pilih SKU / produk', Icons.inventory_2_outlined),
      items: skus
          .map(
            (sku) => DropdownMenuItem<int>(
              value: sku.id,
              child: Text(
                sku.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged:
          skus.isEmpty ? null : (value) => setState(() => row.skuId = value),
      validator: (value) => value == null ? 'Pilih SKU terlebih dahulu' : null,
    );
  }

  Widget _buildLocationDropdown({
    required _TransferFormRow row,
    required bool isOrigin,
    required List<TransferLocation> locations,
  }) {
    final value = isOrigin ? row.fromLocationId : row.toLocationId;
    final selectedLocation = locations
        .where((location) => location.id == value)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          initialValue: value,
          isExpanded: true,
          decoration: _inputDecoration(
            isOrigin ? 'Rak asal (Origin)' : 'Rak tujuan (Destination)',
            isOrigin ? Icons.output_rounded : Icons.input_rounded,
          ),
          items: locations
              .map(
                (location) => DropdownMenuItem<int>(
                  value: location.id,
                  child: Text(
                    location.warehouseName == null
                        ? location.name
                        : '${location.name} · ${location.warehouseName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: locations.isEmpty
              ? null
              : (value) => setState(() {
                  if (isOrigin) {
                    row.fromLocationId = value;
                  } else {
                    row.toLocationId = value;
                  }
                }),
          validator: (value) => value == null ? 'Pilih lokasi' : null,
        ),
        if (selectedLocation?.stockQuantity != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 3),
            child: Text(
              'Stok saat ini di rak: ${selectedLocation!.stockQuantity}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotesCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: TextFormField(
      controller: _notesController,
      maxLines: 3,
      maxLength: 2000,
      decoration: _inputDecoration(
        'Catatan mutasi (opsional)',
        Icons.notes_rounded,
      ).copyWith(
            alignLabelWithHint: true,
            hintText: 'Catatan untuk dokumen mutasi',
          ),
    ),
  );

  InputDecoration _inputDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );

  Widget _buildLoadingBanner() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primaryLight,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.primaryBorder),
    ),
    child: const Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Memuat data SKU dan lokasi...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _buildLoadError() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.dangerLight,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.dangerBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildErrorBanner(_loadError ?? 'Gagal memuat opsi mutasi.'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loadOptions,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Coba muat ulang'),
        ),
      ],
    ),
  );

  Widget _buildEmptyMasterBanner(TransferMasterOptions options) {
    final missing = [
      if (options.skus.isEmpty) 'SKU',
      if (options.locations.isEmpty) 'lokasi',
    ].join(' dan ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warningBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Data $missing belum tersedia. Muat ulang atau hubungi admin.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          IconButton(
            onPressed: _loadOptions,
            tooltip: 'Muat ulang',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh_rounded, size: 19),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.dangerLight,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.dangerBorder),
    ),
    child: Text(
      message,
      style: const TextStyle(color: AppColors.danger, fontSize: 12),
    ),
  );
}

class _TransferFormRow {
  _TransferFormRow({
    this.skuId,
    this.fromLocationId,
    this.toLocationId,
    String quantity = '1',
    String batchNumber = '',
    String expiryDate = '',
  }) : quantityController = TextEditingController(text: quantity),
       batchNumberController = TextEditingController(text: batchNumber),
       expiryDateController = TextEditingController(text: expiryDate);

  int? skuId;
  int? fromLocationId;
  int? toLocationId;
  final TextEditingController quantityController;
  final TextEditingController batchNumberController;
  final TextEditingController expiryDateController;

  factory _TransferFormRow.fromTransaction(TransferTransactionLine line) =>
      _TransferFormRow(
        skuId: line.skuId > 0 ? line.skuId : null,
        fromLocationId: line.fromLocationId,
        toLocationId: line.toLocationId,
        quantity: line.quantity.toString(),
        batchNumber: line.batchNumber ?? '',
        expiryDate: line.expiryDate ?? '',
      );

  void dispose() {
    quantityController.dispose();
    batchNumberController.dispose();
    expiryDateController.dispose();
  }
}
