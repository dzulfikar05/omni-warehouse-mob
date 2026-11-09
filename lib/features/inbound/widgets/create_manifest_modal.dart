import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/omni_snackbar.dart';
import '../inbound_model.dart';
import '../inbound_repository.dart';

class CreateManifestModal extends ConsumerStatefulWidget {
  const CreateManifestModal({super.key});

  @override
  ConsumerState<CreateManifestModal> createState() =>
      _CreateManifestModalState();
}

class _CreateManifestModalState extends ConsumerState<CreateManifestModal> {
  bool _isLoadingOptions = true;
  bool _isSubmitting = false;

  List<InboundSupplier> _suppliers = const [];
  List<InboundProductMaster> _products = const [];
  InboundSupplier? _selectedSupplier;
  final List<_ManifestItemDraft> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchMasterData();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.quantityController.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchMasterData() async {
    final authState = ref.read(authProvider);
    final slug = authState.tenantSlug ?? authState.tenantName ?? 'demo-tenant';

    try {
      final options = await ref
          .read(inboundDataSourceProvider)
          .getMasterOptions(slug);
      if (!mounted) return;
      setState(() {
        _suppliers = options.suppliers;
        _products = options.products;
        _isLoadingOptions = false;
        if (_products.isNotEmpty) {
          _items.add(_ManifestItemDraft(_products.first));
        }
      });
    } catch (error) {
      if (!mounted) return;
      OmniSnackbar.show(
        context,
        message: error.toString(),
        icon: Icons.error_outline_rounded,
      );
      Navigator.pop(context);
    }
  }

  void _addItemRow() {
    if (_products.isEmpty) return;
    setState(() => _items.add(_ManifestItemDraft(_products.first)));
  }

  void _removeItemRow(int index) {
    if (_items.length <= 1) return;
    final removed = _items.removeAt(index);
    removed.quantityController.dispose();
    setState(() {});
  }

  Future<void> _submitForm() async {
    if (_selectedSupplier == null) {
      OmniSnackbar.show(
        context,
        message: 'Pilih supplier terlebih dahulu.',
        icon: Icons.error_outline_rounded,
      );
      return;
    }
    if (_items.isEmpty) {
      OmniSnackbar.show(
        context,
        message: 'Tambahkan minimal satu barang.',
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    final payloadItems = <Map<String, int>>[];
    for (final item in _items) {
      final quantity = int.tryParse(item.quantityController.text.trim());
      if (quantity == null || quantity < 1) {
        OmniSnackbar.show(
          context,
          message: 'Jumlah setiap barang harus minimal 1.',
          icon: Icons.error_outline_rounded,
        );
        return;
      }
      if (item.product.id <= 0 || item.product.productId <= 0) {
        OmniSnackbar.show(
          context,
          message: 'Data SKU atau produk tidak valid. Muat ulang pilihan item.',
          icon: Icons.error_outline_rounded,
        );
        return;
      }
      payloadItems.add({
        'sku_id': item.product.id,
        'product_id': item.product.productId,
        'expected_qty': quantity,
        'po_qty': quantity,
      });
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(inboundRepositoryProvider.notifier)
          .createManifest(
            supplierId: _selectedSupplier!.id,
            items: payloadItems,
          );
      if (!mounted) return;
      Navigator.pop(context);
      OmniSnackbar.show(
        context,
        message: 'Manifes PO inbound berhasil dibuat.',
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
        child: _isLoadingOptions
            ? const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
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
                        child: const Icon(
                          Icons.note_add_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Buat Manifes Inbound PO',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Daftarkan kedatangan barang supplier',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Pilih Supplier / Pemasok'),
                          const SizedBox(height: 7),
                          DropdownButtonFormField<InboundSupplier>(
                            initialValue: _selectedSupplier,
                            isExpanded: true,
                            hint: const Text('Pilih Supplier...'),
                            items: _suppliers
                                .map(
                                  (
                                    supplier,
                                  ) => DropdownMenuItem<InboundSupplier>(
                                    value: supplier,
                                    child: Text(
                                      supplier.code.isNotEmpty &&
                                              supplier.code !=
                                                  supplier.id.toString()
                                          ? '${supplier.code} - ${supplier.name}'
                                          : supplier.name,
                                      softWrap: true,
                                      maxLines: 2,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _isSubmitting
                                ? null
                                : (value) =>
                                      setState(() => _selectedSupplier = value),
                            decoration: _inputDecoration(),
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
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Daftar Barang Acuan PO',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          const Text(
                                            'Pilih item dan jumlah unit target',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed:
                                          _isSubmitting || _products.isEmpty
                                          ? null
                                          : _addItemRow,
                                      icon: const Icon(Icons.add, size: 17),
                                      label: const Text('Tambah'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (_products.isEmpty)
                                  const Text(
                                    'Belum ada produk aktif untuk tenant ini.',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  )
                                else
                                  ..._items.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final item = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            DropdownButtonFormField<
                                              InboundProductMaster
                                            >(
                                              initialValue: item.product,
                                              isExpanded: true,
                                              items: _products
                                                  .map(
                                                    (product) =>
                                                        DropdownMenuItem<
                                                          InboundProductMaster
                                                        >(
                                                          value: product,
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text(
                                                                product.sku,
                                                                softWrap: true,
                                                                style: const TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                              Text(
                                                                product.name,
                                                                softWrap: true,
                                                                maxLines: 2,
                                                                style:
                                                                    const TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                  )
                                                  .toList(),
                                              selectedItemBuilder: (context) =>
                                                  _products
                                                      .map(
                                                        (product) => Align(
                                                          alignment: Alignment
                                                              .centerLeft,
                                                          child: Text(
                                                            product.sku,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
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
                                                          () => item.product =
                                                              value,
                                                        );
                                                      }
                                                    },
                                              decoration: _inputDecoration(
                                                hint: 'Pilih produk',
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Jumlah PO',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: TextField(
                                                        controller: item
                                                            .quantityController,
                                                        enabled: !_isSubmitting,
                                                        keyboardType:
                                                            TextInputType
                                                                .number,
                                                        inputFormatters: [
                                                          FilteringTextInputFormatter
                                                              .digitsOnly,
                                                        ],
                                                        textAlign:
                                                            TextAlign.center,
                                                        decoration:
                                                            _inputDecoration(
                                                              hint: 'Qty',
                                                            ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      tooltip: 'Hapus item',
                                                      onPressed:
                                                          _isSubmitting ||
                                                              _items.length == 1
                                                          ? null
                                                          : () =>
                                                                _removeItemRow(
                                                                  index,
                                                                ),
                                                      icon: const Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ],
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isSubmitting ||
                                  _suppliers.isEmpty ||
                                  _products.isEmpty
                              ? null
                              : _submitForm,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
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
                          label: const Text('Buat Manifes PO'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
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

class _ManifestItemDraft {
  _ManifestItemDraft(this.product)
    : quantityController = TextEditingController(text: '10');

  InboundProductMaster product;
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
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
  );
}
