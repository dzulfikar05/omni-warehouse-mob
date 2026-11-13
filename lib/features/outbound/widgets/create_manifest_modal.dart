import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/omni_snackbar.dart';
import '../outbound_model.dart';
import '../outbound_repository.dart';

class CreateOutboundManifestModal extends ConsumerStatefulWidget {
  const CreateOutboundManifestModal({super.key});

  @override
  ConsumerState<CreateOutboundManifestModal> createState() =>
      _CreateOutboundManifestModalState();
}

class _CreateOutboundManifestModalState
    extends ConsumerState<CreateOutboundManifestModal> {
  final _vehicleController = TextEditingController();
  final _driverController = TextEditingController();
  final _notesController = TextEditingController();
  final List<_OutboundItemDraft> _items = [];

  List<OutboundCustomer> _customers = const [];
  List<OutboundProductMaster> _products = const [];
  OutboundCustomer? _selectedCustomer;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _vehicleController.dispose();
    _driverController.dispose();
    _notesController.dispose();
    for (final item in _items) {
      item.quantityController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final auth = ref.read(authProvider);
    try {
      final options = await ref
          .read(outboundDataSourceProvider)
          .getMasterOptions(
            auth.tenantSlug ?? auth.tenantName ?? 'demo-tenant',
          );
      if (!mounted) return;
      setState(() {
        _customers = options.customers;
        _products = options.products;
        _isLoading = false;
        if (_products.isNotEmpty && _items.isEmpty) {
          _items.add(_OutboundItemDraft(_products.first));
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  void _addItem() {
    if (_products.isEmpty || _isSubmitting) return;
    setState(() => _items.add(_OutboundItemDraft(_products.first)));
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    final removed = _items.removeAt(index);
    removed.quantityController.dispose();
    setState(() {});
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final customer = _selectedCustomer;
    if (customer == null || customer.id <= 0) {
      OmniSnackbar.show(
        context,
        message: 'Pilih customer terlebih dahulu.',
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    if (_items.isEmpty) {
      OmniSnackbar.show(
        context,
        message: 'Tambahkan minimal satu SKU.',
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    final payload = <Map<String, int>>[];
    for (final item in _items) {
      final qty = int.tryParse(item.quantityController.text.trim());
      if (item.product.skuId <= 0 || qty == null || qty < 1) {
        OmniSnackbar.show(
          context,
          message: 'SKU tidak valid dan jumlah SO harus minimal 1.',
          icon: Icons.error_outline_rounded,
        );
        return;
      }
      payload.add({'sku_id': item.product.skuId, 'so_qty': qty});
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(outboundRepositoryProvider.notifier)
          .createManifest(
            customerId: customer.id,
            items: payload,
            vehicleNo: _vehicleController.text,
            driverName: _driverController.text,
            notes: _notesController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      OmniSnackbar.show(
        context,
        message: 'Manifes SO outbound berhasil dibuat.',
        icon: Icons.check_circle_rounded,
      );
    } catch (error) {
      if (mounted) {
        OmniSnackbar.show(
          context,
          message: error.toString(),
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              )
            : _loadError != null
            ? _buildLoadError()
            : _buildForm(),
      ),
    );
  }

  Widget _buildLoadError() => SizedBox(
    height: 260,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_loadError!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _loadOptions,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Coba lagi'),
        ),
      ],
    ),
  );

  Widget _buildForm() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.borderStrong,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.outbox_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buat Manifes SO Outbound',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Registrasi pengeluaran barang & picking ke pelanggan',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Tutup',
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FieldLabel('Pilih Customer / Pelanggan'),
              const SizedBox(height: 7),
              DropdownButtonFormField<OutboundCustomer>(
                initialValue: _selectedCustomer,
                isExpanded: true,
                hint: const Text('Pilih customer...'),
                items: _customers
                    .map(
                      (customer) => DropdownMenuItem(
                        value: customer,
                        child: Text(
                          customer.code.isEmpty
                              ? customer.name
                              : '${customer.code} - ${customer.name}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _selectedCustomer = value),
                decoration: _decoration(hint: 'Pilih customer...'),
              ),
              const SizedBox(height: 14),
              const _FieldLabel('No. Kendaraan (Opsional)'),
              const SizedBox(height: 7),
              TextField(
                controller: _vehicleController,
                enabled: !_isSubmitting,
                textCapitalization: TextCapitalization.characters,
                decoration: _decoration(hint: 'Masukkan nomor kendaraan'),
              ),
              const SizedBox(height: 12),
              const _FieldLabel('Nama Driver (Opsional)'),
              const SizedBox(height: 7),
              TextField(
                controller: _driverController,
                enabled: !_isSubmitting,
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(hint: 'Masukkan nama driver'),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daftar Barang Demand SO',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Pilih SKU dan target jumlah unit yang di-pick',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isSubmitting || _products.isEmpty
                              ? null
                              : _addItem,
                          icon: const Icon(Icons.add_rounded, size: 17),
                          label: const Text('Tambah'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_products.isEmpty)
                      const Text(
                        'Tidak ada SKU tersedia di master outbound.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      )
                    else
                      ..._items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<OutboundProductMaster>(
                                  initialValue: item.product,
                                  isExpanded: true,
                                  items: _products
                                      .map(
                                        (product) => DropdownMenuItem(
                                          value: product,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                product.sku,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                product.name,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  selectedItemBuilder: (context) => _products
                                      .map(
                                        (product) => Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            product.sku,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _isSubmitting
                                      ? null
                                      : (value) {
                                          if (value != null) {
                                            setState(
                                              () => item.product = value,
                                            );
                                          }
                                        },
                                  decoration: _decoration(hint: 'Pilih SKU'),
                                ),
                                const SizedBox(height: 8),
                                _buildProductDetails(item.product),
                                const SizedBox(height: 8),
                                const _FieldLabel('Jumlah SO'),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: item.quantityController,
                                        enabled: !_isSubmitting,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        textAlign: TextAlign.center,
                                        decoration: _decoration(hint: 'Qty'),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Hapus item',
                                      onPressed:
                                          _isSubmitting || _items.length == 1
                                          ? null
                                          : () => _removeItem(index),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _FieldLabel('Catatan (Opsional)'),
              const SizedBox(height: 7),
              TextField(
                controller: _notesController,
                enabled: !_isSubmitting,
                maxLines: 2,
                decoration: _decoration(hint: 'Tambahkan catatan manifes'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Batal'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed:
                  _isSubmitting || _customers.isEmpty || _products.isEmpty
                  ? null
                  : _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.surface,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(
                _isSubmitting ? 'Membuat manifes...' : 'Buat Manifes SO',
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _buildProductDetails(OutboundProductMaster product) => Container(
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
          product.name,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'SKU: ${product.sku} · Barcode: ${product.barcode.isEmpty ? '-' : product.barcode}',
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
        Text(
          product.availableStock == null
              ? 'Satuan: ${product.unit} · Stok rak tersedia pada detail picking'
              : 'Stok tersedia: ${product.availableStock} ${product.unit}',
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    ),
  );

  InputDecoration _decoration({String? hint}) => InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
  );
}

class _OutboundItemDraft {
  _OutboundItemDraft(this.product)
    : quantityController = TextEditingController(text: '1');

  OutboundProductMaster product;
  final TextEditingController quantityController;
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
    ),
  );
}
