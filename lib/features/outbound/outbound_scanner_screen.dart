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
  }

  Future<void> _verifyBarcode([String? value]) async {
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

    setState(() => _isScanning = true);
    try {
      await ref
          .read(outboundRepositoryProvider.notifier)
          .verifyBarcode(widget.code, barcode);
      final detail = await ref
          .read(outboundRepositoryProvider.notifier)
          .loadManifestDetail(widget.code);
      if (!mounted) return;

      final normalized = barcode.toLowerCase();
      final matched = detail.items
          .where(
            (item) =>
                item.sku.toLowerCase() == normalized ||
                item.barcode.toLowerCase() == normalized,
          )
          .firstOrNull;
      setState(() => _detail = detail);
      if (matched != null) {
        _selectItem(matched);
        HapticFeedback.mediumImpact();
        OmniSnackbar.show(
          context,
          message: 'Barcode terverifikasi: ${matched.sku}',
          icon: Icons.check_circle_rounded,
        );
      }
      _barcodeController.clear();
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
      await _verifyBarcode(scannedCode);
    }
  }

  Future<void> _savePicking() async {
    final item = _selectedItem;
    if (item == null || _isSaving) return;

    final goodQty = int.tryParse(_goodQtyController.text.trim());
    final damagedQty = int.tryParse(_damagedQtyController.text.trim());
    if (goodQty == null ||
        damagedQty == null ||
        goodQty < 0 ||
        damagedQty < 0) {
      OmniSnackbar.show(
        context,
        message: 'Jumlah picking harus berupa angka nol atau lebih.',
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    final sourceRackId = _selectedSourceRackId ?? item.sourceRackId;
    if ((_detail?.locations.isNotEmpty ?? false) && sourceRackId == null) {
      OmniSnackbar.show(
        context,
        message: 'Pilih rak asal untuk item ini.',
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    final itemId = int.tryParse(item.id);
    if (itemId == null) {
      OmniSnackbar.show(
        context,
        message: 'ID item outbound tidak valid.',
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(outboundRepositoryProvider.notifier);
      await notifier.savePicking(
        manifestCode: widget.code,
        itemId: itemId,
        goodQty: goodQty,
        damagedQty: damagedQty,
        sourceRackId: sourceRackId,
        damageNote: _damageNoteController.text.trim().isEmpty
            ? null
            : _damageNoteController.text.trim(),
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
        if (refreshedItem != null) _selectItem(refreshedItem);
      }
      HapticFeedback.mediumImpact();
      OmniSnackbar.show(
        context,
        message: 'Alokasi picking ${item.sku} berhasil disimpan.',
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
            if (_selectedItem != null) ...[
              const SizedBox(height: 12),
              _buildPickingCard(order),
            ],
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
            children: [
              IconButton(
                onPressed: () => context.go('/outbound'),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
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
                        color: AppColors.textPrimary,
                      ),
                    ),
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
          const Text(
            'Verifikasi Barcode / SKU',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Gunakan scanner perangkat atau masukkan kode barang.',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcodeController,
                  enabled: canScan && !_isScanning,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _verifyBarcode,
                  decoration: InputDecoration(
                    hintText: 'Scan barcode / kode SKU...',
                    prefixIcon: IconButton(
                      icon: const Icon(
                        Icons.camera_alt_rounded,
                        color: AppColors.primary,
                      ),
                      tooltip: 'Buka Kamera Scanner',
                      onPressed:
                          canScan && !_isScanning && !_isCameraScannerOpen
                          ? _openCameraScanner
                          : null,
                    ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: canScan && !_isScanning ? _verifyBarcode : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(48, 50),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                child: _isScanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.surface,
                        ),
                      )
                    : const Text('Verifikasi'),
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
    final selected = _selectedItem?.id == item.id;
    final isComplete = item.totalProcessedQty >= item.orderQty;
    final sourceRack = _rackById(item.sourceRackId)?.rackCode ?? item.fromRack;
    return InkWell(
      onTap: order.status == OutboundStatus.dispatched
          ? null
          : () => _selectItem(item),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          border: const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.sku.isEmpty ? item.barcode : item.sku,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${item.totalProcessedQty}/${item.orderQty} unit',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.name,
              softWrap: true,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _tag(
                  sourceRack.isEmpty ? 'Belum dialokasikan' : sourceRack,
                  sourceRack.isEmpty
                      ? AppColors.surfaceAlt
                      : AppColors.primaryLight,
                  sourceRack.isEmpty ? AppColors.textMuted : AppColors.primary,
                ),
                _tag(
                  isComplete ? 'Selesai picking' : 'Menunggu picking',
                  isComplete ? AppColors.successLight : AppColors.surfaceAlt,
                  isComplete ? AppColors.success : AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickingCard(OutboundOrder order) {
    final item = _selectedItem!;
    final canEdit =
        order.status != OutboundStatus.dispatched &&
        order.status != OutboundStatus.hold;
    final locations = _detail!.locations;
    final rackValue =
        locations.any((location) => location.id == _selectedSourceRackId)
        ? _selectedSourceRackId
        : null;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit / Alokasi Rak Asal',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: item.sku,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextSpan(text: ' · ${item.name}'),
              ],
            ),
            softWrap: true,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _quantityField(
                  label: 'Jumlah baik',
                  controller: _goodQtyController,
                  enabled: canEdit,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _quantityField(
                  label: 'Jumlah rusak',
                  controller: _damagedQtyController,
                  enabled: canEdit,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Rak Asal (Source Rack)',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 5),
          DropdownButtonFormField<int>(
            initialValue: rackValue,
            isExpanded: true,
            hint: const Text('Pilih rak asal'),
            items: locations
                .map(
                  (location) => DropdownMenuItem(
                    value: location.id,
                    child: Text(location.rackCode),
                  ),
                )
                .toList(),
            onChanged: canEdit
                ? (rackId) => setState(() => _selectedSourceRackId = rackId)
                : null,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (locations.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                'Daftar rak asal tidak tersedia pada detail manifes.',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _damageNoteController,
            enabled: canEdit,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Catatan kerusakan (opsional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canEdit && !_isSaving ? _savePicking : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.surface,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(
                _isSaving ? 'Menyimpan picking...' : 'Simpan Alokasi Rak',
              ),
            ),
          ),
        ],
      ),
    );
  }

  OutboundLocation? _rackById(int? rackId) {
    if (rackId == null) return null;
    return _detail?.locations
        .where((location) => location.id == rackId)
        .firstOrNull;
  }

  Widget _quantityField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
  }) => TextField(
    controller: controller,
    enabled: enabled,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );

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
