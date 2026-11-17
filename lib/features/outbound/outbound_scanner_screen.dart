import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/omni_snackbar.dart';
import 'outbound_model.dart';
import 'outbound_repository.dart';
import 'widgets/outbound_barcode_scanner.dart';

class OutboundScannerScreen extends ConsumerStatefulWidget {
  const OutboundScannerScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<OutboundScannerScreen> createState() =>
      _OutboundScannerScreenState();
}

class _OutboundScannerScreenState extends ConsumerState<OutboundScannerScreen> {
  final _barcodeController = TextEditingController();
  final _goodQtyController = TextEditingController(text: '0');
  final _damagedQtyController = TextEditingController(text: '0');
  final _damageNoteController = TextEditingController();

  OutboundManifestDetail? _detail;
  OutboundItem? _selectedItem;
  int? _selectedSourceRackId;
  bool _isLoading = true;
  bool _isScanning = false;
  bool _isCameraScannerOpen = false;
  bool _isSaving = false;
  bool _isUpdatingStatus = false;
  bool _isCommitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _goodQtyController.dispose();
    _damagedQtyController.dispose();
    _damageNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final detail = await ref
          .read(outboundRepositoryProvider.notifier)
          .loadManifestDetail(widget.code);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
      if (_selectedItem != null) {
        final refreshed = detail.items
            .where((item) => item.id == _selectedItem!.id)
            .firstOrNull;
        if (refreshed != null) _selectItem(refreshed);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _selectItem(OutboundItem item) {
    setState(() {
      _selectedItem = item;
      _goodQtyController.text = item.pickedQty.toString();
      _damagedQtyController.text = item.damagedQty.toString();
      _damageNoteController.text = item.notes ?? '';
      _selectedSourceRackId = item.sourceRackId;
    });
    _openItemPickingSheet(item);
  }

  OutboundItem? _findItemByCode(String code) {
    if (_detail == null) return null;
    final clean = code.trim().toLowerCase();
    for (final item in _detail!.items) {
      if (item.barcode.trim().toLowerCase() == clean ||
          item.sku.trim().toLowerCase() == clean) {
        return item;
      }
    }
    return null;
  }

  Future<void> _handleBarcodeSubmit([String? value]) async {
    if (_isScanning) return;
    final barcode = (value ?? _barcodeController.text).trim();
    if (barcode.isEmpty) {
      OmniSnackbar.show(
        context,
        message: 'Masukkan atau scan barcode/SKU terlebih dahulu.',
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    final matched = _findItemByCode(barcode);
    if (matched != null) {
      _barcodeController.clear();
      HapticFeedback.mediumImpact();
      _selectItem(matched);
      return;
    }

    // Jika belum ada di list lokal, coba panggil API verifyBarcode backend
    setState(() => _isScanning = true);
    try {
      await ref
          .read(outboundRepositoryProvider.notifier)
          .verifyBarcode(widget.code, barcode);
      final detail = await ref
          .read(outboundRepositoryProvider.notifier)
          .loadManifestDetail(widget.code);
      if (!mounted) return;

      setState(() => _detail = detail);
      final refreshedMatch = _findItemByCode(barcode);
      _barcodeController.clear();
      HapticFeedback.mediumImpact();

      if (refreshedMatch != null) {
        _selectItem(refreshedMatch);
      } else {
        OmniSnackbar.show(
          context,
          message: 'Barcode berhasil diverifikasi (+1 unit).',
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (error) {
      if (mounted) {
        OmniSnackbar.show(
          context,
          message: error.toString(),
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _openCameraScanner() async {
    if (_isScanning || _isCameraScannerOpen) return;

    setState(() => _isCameraScannerOpen = true);
    String? scannedCode;
    try {
      scannedCode = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => const OutboundBarcodeScannerScreen(),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCameraScannerOpen = false);
    }

    if (scannedCode != null && scannedCode.trim().isNotEmpty && mounted) {
      _barcodeController.text = scannedCode;
      await _handleBarcodeSubmit(scannedCode);
    }
  }

  Future<void> _savePickingData({
    required OutboundItem item,
    required int goodQty,
    required int damagedQty,
    required int? sourceRackId,
    String? damageNote,
  }) async {
    final itemId = int.tryParse(item.id);
    if (itemId == null) return;

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(outboundRepositoryProvider.notifier);
      await notifier.savePicking(
        manifestCode: widget.code,
        itemId: itemId,
        goodQty: goodQty,
        damagedQty: damagedQty,
        sourceRackId: sourceRackId,
        damageNote: damageNote,
      );
      if (!mounted) return;

      final updatedOrder = notifier.getOrderByCode(widget.code);
      if (updatedOrder != null) {
        final refreshedItem = updatedOrder.items
            .where((candidate) => candidate.id == item.id)
            .firstOrNull;
        setState(() {
          _detail = OutboundManifestDetail(
            manifest: updatedOrder,
            items: updatedOrder.items,
            locations: _detail?.locations ?? const [],
          );
        });
        if (refreshedItem != null) {
          _selectedItem = refreshedItem;
        }
      }
      HapticFeedback.mediumImpact();
      OmniSnackbar.show(
        context,
        message:
            'Hasil picking ${item.sku.isEmpty ? item.barcode : item.sku} ($goodQty unit) berhasil disimpan.',
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _openItemPickingSheet(OutboundItem item) {
    final order = _detail!.manifest;
    final canEdit =
        order.status != OutboundStatus.dispatched &&
        order.status != OutboundStatus.hold;

    final initialGoodQty = item.pickedQty > 0
        ? item.pickedQty
        : (item.orderQty - item.damagedQty > 0
              ? item.orderQty - item.damagedQty
              : item.orderQty);

    final goodQtyCtrl = TextEditingController(text: initialGoodQty.toString());
    final damagedQtyCtrl = TextEditingController(
      text: item.damagedQty.toString(),
    );
    final damageNoteCtrl = TextEditingController(text: item.notes ?? '');
    final rackCode = item.fromRack.isNotEmpty &&
            item.fromRack != 'Belum Dialokasi' &&
            item.fromRack != 'Belum dialokasikan'
        ? item.fromRack
        : (_rackById(item.sourceRackId)?.rackCode ?? 'Belum dialokasikan');
    final hasValidRack = rackCode != 'Belum dialokasikan' &&
        rackCode != 'Belum Dialokasi' &&
        rackCode.isNotEmpty;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void updateGoodQty(int delta) {
              final val = (int.tryParse(goodQtyCtrl.text.trim()) ?? 0) + delta;
              if (val >= 0) {
                goodQtyCtrl.text = val.toString();
                setSheetState(() {});
              }
            }

            void updateDamagedQty(int delta) {
              final val =
                  (int.tryParse(damagedQtyCtrl.text.trim()) ?? 0) + delta;
              if (val >= 0) {
                damagedQtyCtrl.text = val.toString();
                setSheetState(() {});
              }
            }

            final isComplete =
                ((int.tryParse(goodQtyCtrl.text.trim()) ?? 0) +
                    (int.tryParse(damagedQtyCtrl.text.trim()) ?? 0)) >=
                item.orderQty;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(top: 4, bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.outbox_rounded,
                              color: AppColors.primary,
                              size: 20,
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
                                        item.sku.isEmpty
                                            ? item.barcode
                                            : item.sku,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'RobotoMono',
                                          color: AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isComplete
                                            ? AppColors.successLight
                                            : AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isComplete
                                              ? AppColors.successBorder
                                              : AppColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        'Pesanan: ${item.orderQty} unit',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isComplete
                                              ? AppColors.success
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // 2 Quantity Inputs with Steppers
                      Row(
                        children: [
                          Expanded(
                            child: _quantityStepper(
                              label: 'Jumlah Picked (Baik)',
                              controller: goodQtyCtrl,
                              enabled: canEdit,
                              onMinus: () => updateGoodQty(-1),
                              onPlus: () => updateGoodQty(1),
                              prefixIcon: Icons.check_circle_outline_rounded,
                              iconColor: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _quantityStepper(
                              label: 'Rusak / Batal di Rak',
                              controller: damagedQtyCtrl,
                              enabled: canEdit,
                              onMinus: () => updateDamagedQty(-1),
                              onPlus: () => updateDamagedQty(1),
                              prefixIcon: Icons.warning_amber_rounded,
                              iconColor: AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Read-only Source Rack Info Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: hasValidRack
                              ? AppColors.primaryLight.withOpacity(0.4)
                              : AppColors.warningLight.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasValidRack
                                ? AppColors.primaryBorder
                                : AppColors.warningBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: hasValidRack
                                    ? AppColors.primary
                                    : AppColors.warning,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.shelves,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'LOKASI RAK PENGAMBILAN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                      color: hasValidRack
                                          ? AppColors.primary
                                          : AppColors.warning,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    rackCode,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'RobotoMono',
                                      color: hasValidRack
                                          ? AppColors.textPrimary
                                          : AppColors.warning,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hasValidRack
                                        ? 'Ambil barang langsung dari rak ini sesuai alokasi sistem'
                                        : 'Rak belum dialokasikan di sistem',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Damage / Condition Note
                      TextField(
                        controller: damageNoteCtrl,
                        enabled: canEdit,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Catatan kondisi / kerusakan (opsional)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Save Picking Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: canEdit && !_isSaving
                              ? () async {
                                  final goodQty =
                                      int.tryParse(goodQtyCtrl.text.trim()) ??
                                      0;
                                  final damagedQty =
                                      int.tryParse(
                                        damagedQtyCtrl.text.trim(),
                                      ) ??
                                      0;

                                  Navigator.pop(sheetContext);
                                  await _savePickingData(
                                    item: item,
                                    goodQty: goodQty,
                                    damagedQty: damagedQty,
                                    sourceRackId: item.sourceRackId,
                                    damageNote:
                                        damageNoteCtrl.text.trim().isEmpty
                                        ? null
                                        : damageNoteCtrl.text.trim(),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 18,
                                ),
                          label: Text(
                            _isSaving ? 'Menyimpan...' : 'Simpan Hasil Picking',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _changeHoldStatus(OutboundOrder order) async {
    String? reason;
    if (order.status != OutboundStatus.hold) {
      final reasonController = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hold sesi outbound'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Alasan hold (opsional)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, reasonController.text),
              child: const Text('Hold'),
            ),
          ],
        ),
      );
      reasonController.dispose();
      if (reason == null || !mounted) return;
    }

    setState(() => _isUpdatingStatus = true);
    try {
      final notifier = ref.read(outboundRepositoryProvider.notifier);
      if (order.status == OutboundStatus.hold) {
        await notifier.resumeManifest(widget.code);
      } else {
        await notifier.holdManifest(widget.code, reason: reason);
      }
      await _loadDetail(showLoading: false);
      if (mounted) {
        OmniSnackbar.show(
          context,
          message: order.status == OutboundStatus.hold
              ? 'Sesi outbound dilanjutkan.'
              : 'Sesi outbound ditahan.',
          icon: Icons.check_circle_rounded,
        );
      }
    } catch (error) {
      if (mounted) {
        OmniSnackbar.show(
          context,
          message: error.toString(),
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _commitOutbound(OutboundOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Commit outbound'),
        content: Text(
          'Selesaikan picking manifes ${order.code} untuk ${order.customer}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Potong Stok & Commit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCommitting = true);
    try {
      await ref
          .read(outboundRepositoryProvider.notifier)
          .commitOutboundApi(widget.code);
      if (!mounted) return;
      OmniSnackbar.show(
        context,
        message: 'Manifes ${order.code} berhasil di-commit.',
        icon: Icons.check_circle_rounded,
      );
      context.go('/outbound');
    } catch (error) {
      if (mounted) {
        OmniSnackbar.show(
          context,
          message: error.toString(),
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _isCommitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.code)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final detail = _detail;
    if (detail == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.code)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.danger,
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Manifes outbound tidak ditemukan.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loadDetail,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final order = detail.manifest;
    final items = detail.items;
    final totalUnits = items.fold<int>(0, (sum, item) => sum + item.orderQty);
    final goodUnits = items.fold<int>(0, (sum, item) => sum + item.pickedQty);
    final damagedUnits = items.fold<int>(
      0,
      (sum, item) => sum + item.damagedQty,
    );
    final processedUnits = goodUnits + damagedUnits;
    final progress = totalUnits == 0 ? 0.0 : processedUnits / totalUnits;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Workspace Picking'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loadDetail,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadDetail(showLoading: false),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildManifestHeader(order),
            const SizedBox(height: 12),
            _buildScanCard(order),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    'Total SKU',
                    '${items.length} ($totalUnits unit)',
                    Icons.inventory_2_outlined,
                    AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetric(
                    'Picked (Baik)',
                    '$goodUnits unit',
                    Icons.check_circle_outline_rounded,
                    AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetric(
                    'Batal / Rusak',
                    '$damagedUnits unit',
                    Icons.warning_amber_rounded,
                    AppColors.warning,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetric(
                    'Progress Picking',
                    '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    Icons.local_shipping_outlined,
                    AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildItemsCard(items, order),
          ],
        ),
      ),
    );
  }

  Widget _buildManifestHeader(OutboundOrder order) {
    final isHeld = order.status == OutboundStatus.hold;
    final canEdit = order.status != OutboundStatus.dispatched;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.code.replaceAll('-', '-\u200B'),
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'RobotoMono',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Customer: ${order.customer}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(order.status),
            ],
          ),
          const Divider(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: !canEdit || _isUpdatingStatus
                    ? null
                    : () => _changeHoldStatus(order),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 50),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                icon: _isUpdatingStatus
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isHeld
                            ? Icons.play_arrow_rounded
                            : Icons.pause_circle_outline_rounded,
                        size: 17,
                      ),
                label: Text(isHeld ? 'Lanjutkan' : 'Hold Session'),
              ),
              ElevatedButton.icon(
                onPressed:
                    !canEdit || isHeld || _isCommitting || _isUpdatingStatus
                    ? null
                    : () => _commitOutbound(order),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(48, 50),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                icon: _isCommitting
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.surface,
                        ),
                      )
                    : const Icon(Icons.done_all_rounded, size: 17),
                label: const Text('Potong Stok & Commit'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScanCard(OutboundOrder order) {
    final canScan =
        order.status != OutboundStatus.dispatched &&
        order.status != OutboundStatus.hold;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.qr_code_scanner_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Scan Barcode / Cari SKU Picking',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Auto-Focus Item',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Tembak dengan laser PDA, buka kamera, atau ketik SKU jika barcode rusak.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcodeController,
                  enabled: canScan && !_isScanning,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _handleBarcodeSubmit(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'RobotoMono',
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Scan barcode / ketik SKU...',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'RobotoMono',
                      fontWeight: FontWeight.normal,
                    ),
                    prefixIcon: IconButton(
                      icon: const Icon(
                        Icons.camera_alt_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      tooltip: 'Buka Kamera Scanner',
                      onPressed:
                          canScan && !_isScanning && !_isCameraScannerOpen
                          ? _openCameraScanner
                          : null,
                    ),
                    suffixIcon: _barcodeController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () =>
                                setState(() => _barcodeController.clear()),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: canScan && !_isScanning
                    ? () => _handleBarcodeSubmit()
                    : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(48, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isScanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search_rounded, size: 18),
                label: const Text(
                  'Buka',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String title, String value, IconData icon, Color color) =>
      _card(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(icon, size: 19, color: color),
          ],
        ),
      );

  Widget _buildItemsCard(List<OutboundItem> items, OutboundOrder order) =>
      _card(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Detail Item Picking & Source Rack',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                'Semua (${items.length})',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (_detail!.locations.any(
          (location) => location.stockQuantity != null,
        ))
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stok per rak',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _detail!.locations
                      .where((location) => location.stockQuantity != null)
                      .map(
                        (location) => Chip(
                          label: Text(
                            '${location.rackCode} · ${location.stockQuantity} unit',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'Manifes ini belum memiliki item.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          )
        else
          ...items.map((item) => _buildItemRow(item, order)),
      ],
    ),
  );

  Widget _buildItemRow(OutboundItem item, OutboundOrder order) {
    final canEdit =
        order.status != OutboundStatus.dispatched &&
        order.status != OutboundStatus.hold;
    final isInvalidQty = item.orderQty <= 0;
    final isDone = item.orderQty > 0 && item.totalProcessedQty >= item.orderQty;
    final hasDamage = item.damagedQty > 0;
    final selected = _selectedItem?.id == item.id;
    final sourceRack = _rackById(item.sourceRackId)?.rackCode ?? item.fromRack;
    final hasValidRack =
        sourceRack.isNotEmpty &&
        sourceRack != 'Belum Dialokasi' &&
        sourceRack != 'Belum dialokasikan';

    return InkWell(
      onTap: canEdit ? () => _selectItem(item) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryLight.withValues(alpha: 0.4)
              : (isDone ? const Color(0xFFF0FDF4) : AppColors.surface),
          border: const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.sku.isEmpty ? item.barcode : item.sku,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontFamily: 'RobotoMono',
                            fontSize: 12,
                            color: isDone
                                ? const Color(0xFF166534)
                                : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDone) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: AppColors.success,
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  isInvalidQty
                      ? '0/0 unit'
                      : '${item.totalProcessedQty}/${item.orderQty} unit',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'RobotoMono',
                    fontWeight: FontWeight.w700,
                    color: isInvalidQty
                        ? AppColors.danger
                        : (isDone
                              ? AppColors.success
                              : (item.totalProcessedQty > 0
                                    ? AppColors.warning
                                    : AppColors.textSecondary)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              item.name,
              softWrap: true,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Builder(
              builder: (context) {
                final String rackText = hasValidRack
                    ? '📍 Rak Sumber: $sourceRack'
                    : '⚠️ Belum dialokasikan';
                final Color rackBg = hasValidRack
                    ? AppColors.primaryLight
                    : AppColors.warningLight;
                final Color rackFg =
                    hasValidRack ? AppColors.primary : AppColors.warning;

                final String statusText;
                final Color statusBg;
                final Color statusFg;

                if (isInvalidQty) {
                  statusText = '⚠️ Order 0 Unit (Data Invalid)';
                  statusBg = const Color(0xFFFEF2F2);
                  statusFg = AppColors.danger;
                } else if (isDone) {
                  statusText = 'Lengkap Dipick (100%)';
                  statusBg = AppColors.successLight;
                  statusFg = AppColors.success;
                } else if (item.totalProcessedQty > 0) {
                  statusText =
                      'Dipick: ${item.totalProcessedQty}/${item.orderQty} unit';
                  statusBg = AppColors.warningLight;
                  statusFg = AppColors.warning;
                } else {
                  statusText = 'Menunggu picking';
                  statusBg = AppColors.surfaceAlt;
                  statusFg = AppColors.textMuted;
                }

                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _tag(rackText, rackBg, rackFg),
                    _tag(statusText, statusBg, statusFg),
                    if (hasDamage)
                      _tag(
                        '${item.damagedQty} Batal/Rusak di Rak',
                        const Color(0xFFFEF2F2),
                        AppColors.danger,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantityStepper({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    IconData? prefixIcon,
    Color? iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (prefixIcon != null) ...[
              Icon(
                prefixIcon,
                size: 14,
                color: iconColor ?? AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: enabled ? AppColors.surfaceAlt : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 46),
                color: AppColors.textSecondary,
                onPressed: enabled ? onMinus : null,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'RobotoMono',
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 46),
                color: AppColors.primary,
                onPressed: enabled ? onPlus : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  OutboundLocation? _rackById(int? rackId) {
    if (rackId == null) return null;
    return _detail?.locations
        .where((location) => location.id == rackId)
        .firstOrNull;
  }

  Widget _statusBadge(OutboundStatus status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: status.bg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      status.label,
      style: TextStyle(
        color: status.color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _tag(String label, Color background, Color foreground) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
    padding: padding ?? const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

extension _OutboundFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
