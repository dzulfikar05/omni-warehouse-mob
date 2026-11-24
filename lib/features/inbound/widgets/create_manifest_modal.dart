import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/auth/auth_provider.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/offline/offline_db.dart';
import '../../../core/offline/offline_identity.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/omni_snackbar.dart';
import '../inbound_local_id.dart';
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
  bool _usingCachedOptions = false;

  List<InboundSupplier> _suppliers = const [];
  List<InboundProductMaster> _products = const [];
  List<String> _availableRacks = const [];
  InboundSupplier? _selectedSupplier;
  final List<_ManifestItemDraft> _items = [];
  final String _localUuid = generateInboundLocalId();

  @override
  void initState() {
    super.initState();
    _fetchMasterData();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.quantityController.dispose();
      item.goodQtyController.dispose();
      item.damagedQtyController.dispose();
      item.damageNoteController.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchMasterData() async {
    final authState = ref.read(authProvider);
    final slug = authState.tenantSlug ?? authState.tenantName ?? 'demo-tenant';
    final ownerKey = offlineOwnerKey(
      userId: authState.userId,
      token: authState.token ?? 'unauthenticated',
    );

    try {
      final options =
          await ref.read(inboundDataSourceProvider).getMasterOptions(slug);
      try {
        await OfflineDb.cacheInboundOptions(
          tenantSlug: slug,
          ownerKey: ownerKey,
          options: {
            'suppliers': options.suppliers
                .map((supplier) => {
                      'id': supplier.id,
                      'code': supplier.code,
                      'name': supplier.name,
                    })
                .toList(),
            'products': options.products
                .map((product) => {
                      'id': product.productId,
                      'sku_id': product.id,
                      'sku': product.sku,
                      'barcode': product.barcode,
                      'name': product.name,
                      'unit': product.unit,
                      'available_stock': product.availableStock,
                    })
                .toList(),
            'available_racks': options.availableRacks,
          },
        );
      } catch (error) {
        if (mounted) {
          OmniSnackbar.show(
            context,
            message:
                'Master data online tersedia, tetapi cache lokal gagal: $error',
            icon: Icons.warning_amber_rounded,
          );
        }
      }
      if (!mounted) return;
      setState(() {
        _suppliers = options.suppliers;
        _products = options.products;
        _availableRacks = options.availableRacks;
        _isLoadingOptions = false;
        if (_products.isNotEmpty) {
          _items.add(_ManifestItemDraft(_products.first));
        }
      });
    } on NetworkException {
      try {
        final cached = await OfflineDb.getCachedInboundOptions(
          tenantSlug: slug,
          ownerKey: ownerKey,
        );
        if (!mounted) return;
        if (cached == null) {
          _showOptionsError('Master data belum pernah dimuat saat online.');
          return;
        }
        final suppliers = (cached['suppliers'] as List? ?? const [])
            .map((item) => InboundSupplier.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList();
        final products = (cached['products'] as List? ?? const [])
            .map((item) => InboundProductMaster.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList();
        setState(() {
          _suppliers = suppliers;
          _products = products;
          _availableRacks = (cached['available_racks'] as List? ?? const [])
              .map((item) => item.toString())
              .toList();
          _usingCachedOptions = true;
          _isLoadingOptions = false;
          if (_products.isNotEmpty) {
            _items.add(_ManifestItemDraft(_products.first));
          }
        });
      } catch (error) {
        _showOptionsError('Gagal membaca master data lokal: $error');
      }
    } catch (error) {
      _showOptionsError(error.toString());
    }
  }

  void _showOptionsError(String message) {
    if (!mounted) return;
    OmniSnackbar.show(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
    );
    Navigator.pop(context);
  }

  void _addItemRow() {
    if (_products.isEmpty) return;
    setState(() => _items.add(_ManifestItemDraft(_products.first)));
  }

  void _removeItemRow(int index) {
    if (_items.length <= 1) return;
    final removed = _items.removeAt(index);
    removed.quantityController.dispose();
    removed.goodQtyController.dispose();
    removed.damagedQtyController.dispose();
    removed.damageNoteController.dispose();
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

    final offlineItems = <Map<String, dynamic>>[];
    final onlineItems = <Map<String, dynamic>>[];
    final metadataItems = <Map<String, dynamic>>[];
    for (final item in _items) {
      final quantity = int.tryParse(item.quantityController.text.trim());
      final goodQty = int.tryParse(item.goodQtyController.text.trim());
      final damagedQty = int.tryParse(item.damagedQtyController.text.trim());
      if (quantity == null || quantity < 1) {
        OmniSnackbar.show(
          context,
          message: 'Jumlah setiap barang harus minimal 1.',
          icon: Icons.error_outline_rounded,
        );
        return;
      }
      if (goodQty == null ||
          damagedQty == null ||
          goodQty < 0 ||
          damagedQty < 0) {
        OmniSnackbar.show(
          context,
          message: 'Jumlah baik dan rusak harus berupa angka nol atau lebih.',
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
      final targetRack = item.targetRack;
      final damageNote = item.damageNoteController.text.trim();
      offlineItems.add({
        'sku_id': item.product.id,
        'po_qty': quantity,
        'good_qty': goodQty,
        'damaged_qty': damagedQty,
        'target_rack': targetRack,
        'damage_note': damageNote.isEmpty ? null : damageNote,
      });
      onlineItems.add({
        'product_id': item.product.productId,
        'sku_id': item.product.id,
        'expected_qty': quantity,
        'po_qty': quantity,
        'good_qty': goodQty,
        'damaged_qty': damagedQty,
        'target_rack': targetRack,
        'damage_note': damageNote.isEmpty ? null : damageNote,
      });
      metadataItems.add({
        ...offlineItems.last,
        'sku': item.product.sku,
        'barcode': item.product.barcode,
        'name': item.product.name,
      });
    }

    setState(() => _isSubmitting = true);
    try {
      var savedOffline = false;
      try {
        await ref.read(inboundRepositoryProvider.notifier).createManifest(
              localUuid: _localUuid,
              supplierId: _selectedSupplier!.id,
              items: onlineItems,
            );
      } on NetworkException {
        await ref.read(inboundRepositoryProvider.notifier).queueOfflineManifest(
          localUuid: _localUuid,
          offlinePayload: {
            'local_uuid': _localUuid,
            'supplier_id': _selectedSupplier!.id,
            'should_commit': false,
            'items': offlineItems,
          },
          metadata: {
            'supplier_id': _selectedSupplier!.id,
            'supplier_name': _selectedSupplier!.name,
            'items': metadataItems,
          },
        );
        savedOffline = true;
      }
      await ref.read(inboundRepositoryProvider.notifier).loadManifests();
      if (!mounted) return;
      Navigator.pop(context);
      OmniSnackbar.show(
        context,
        message: savedOffline
            ? 'Tidak ada jaringan. Manifes inbound disimpan di perangkat dan akan dikirim saat jaringan tersedia.'
            : 'Manifes PO inbound berhasil dibuat.',
        icon: savedOffline
            ? Icons.cloud_off_rounded
            : Icons.check_circle_rounded,
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
                        onPressed:
                            _isSubmitting ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_usingCachedOptions)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Offline: master data tersimpan di perangkat. Isi jumlah diterima agar transaksi siap disinkronkan.',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                        ),
                      ),
                    ),
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
                                  ) =>
                                      DropdownMenuItem<InboundSupplier>(
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
                                                InboundProductMaster>(
                                              initialValue: item.product,
                                              isExpanded: true,
                                              items: _products
                                                  .map(
                                                    (product) => DropdownMenuItem<
                                                        InboundProductMaster>(
                                                      value: product,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            product.sku,
                                                            softWrap: true,
                                                            style:
                                                                const TextStyle(
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
                                                              fontSize: 11,
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
                                            _buildProductDetails(item.product),
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
                                                      onPressed: _isSubmitting ||
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
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child:
                                                          _buildQuantityField(
                                                        'Qty baik',
                                                        item.goodQtyController,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child:
                                                          _buildQuantityField(
                                                        'Qty rusak',
                                                        item.damagedQtyController,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                DropdownButtonFormField<String>(
                                                  initialValue:
                                                      _availableRacks.contains(
                                                    item.targetRack,
                                                  )
                                                          ? item.targetRack
                                                          : null,
                                                  isExpanded: true,
                                                  decoration: _inputDecoration(
                                                    hint:
                                                        'Rak tujuan (opsional)',
                                                  ),
                                                  items: _availableRacks
                                                      .map(
                                                        (rack) =>
                                                            DropdownMenuItem<
                                                                String>(
                                                          value: rack,
                                                          child: Text(rack),
                                                        ),
                                                      )
                                                      .toList(),
                                                  onChanged: _isSubmitting
                                                      ? null
                                                      : (rack) => setState(
                                                            () =>
                                                                item.targetRack =
                                                                    rack,
                                                          ),
                                                ),
                                                const SizedBox(height: 8),
                                                TextField(
                                                  controller:
                                                      item.damageNoteController,
                                                  enabled: !_isSubmitting,
                                                  maxLength: 500,
                                                  decoration: _inputDecoration(
                                                    hint:
                                                        'Catatan barang rusak',
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
                          onPressed: _isSubmitting ||
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

  Widget _buildProductDetails(InboundProductMaster product) => Container(
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
              style:
                  const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
            Text(
              'Satuan: ${product.unit}'
              '${product.availableStock == null ? '' : ' · Stok saat ini: ${product.availableStock} ${product.unit}'}',
              style:
                  const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      );

  Widget _buildQuantityField(
    String label,
    TextEditingController controller,
  ) =>
      TextField(
        controller: controller,
        enabled: !_isSubmitting,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: _inputDecoration(hint: label),
      );

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
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
      : quantityController = TextEditingController(text: '10'),
        goodQtyController = TextEditingController(text: '0'),
        damagedQtyController = TextEditingController(text: '0'),
        damageNoteController = TextEditingController();

  InboundProductMaster product;
  final TextEditingController quantityController;
  final TextEditingController goodQtyController;
  final TextEditingController damagedQtyController;
  final TextEditingController damageNoteController;
  String? targetRack;
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
