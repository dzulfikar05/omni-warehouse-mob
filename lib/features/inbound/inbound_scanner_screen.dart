import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/omni_snackbar.dart';
import 'inbound_model.dart';
import 'inbound_repository.dart';
import 'widgets/inbound_barcode_scanner.dart';

class InboundScannerScreen extends ConsumerStatefulWidget {
  const InboundScannerScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<InboundScannerScreen> createState() =>
      _InboundScannerScreenState();
}

class _InboundScannerScreenState extends ConsumerState<InboundScannerScreen> {
  final _barcodeController = TextEditingController();
  final _goodQtyController = TextEditingController(text: '0');
  final _damagedQtyController = TextEditingController(text: '0');
  final _damageNoteController = TextEditingController();

  InboundManifestDetail? _detail;
  InboundItem? _selectedItem;
  List<String> _availableRacks = const [];
  String? _selectedRack;
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
      final notifier = ref.read(inboundRepositoryProvider.notifier);
      final detail = await notifier.loadManifestDetail(widget.code);
      if (!mounted) return;

      final racks = detail.locations
          .map((location) => location.rackCode)
          .where((rack) => rack.isNotEmpty)
          .toList();
      var availableRacks = racks;
      if (availableRacks.isEmpty && _availableRacks.isEmpty) {
        final options = await ref
            .read(inboundDataSourceProvider)
            .getMasterOptions(ref.read(inboundTenantSlugProvider));
        availableRacks = options.availableRacks;
      }
      if (!mounted) return;

      setState(() {
        _detail = detail;
        _availableRacks = availableRacks;
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

  void _selectItem(InboundItem item) {
    setState(() {
      _selectedItem = item;
      _goodQtyController.text = item.goodQty.toString();
      _damagedQtyController.text = item.damagedQty.toString();
      _damageNoteController.text = item.notes ?? '';
      _selectedRack =
          item.targetRack != null && _availableRacks.contains(item.targetRack)
          ? item.targetRack
          : (_availableRacks.isEmpty ? null : _availableRacks.first);
    });
  }

  Future<void> _verifyBarcode() async {
    if (_isScanning) return;

    final barcode = _barcodeController.text.trim();
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
          .read(inboundRepositoryProvider.notifier)
          .verifyBarcode(widget.code, barcode);
      await _loadDetail(showLoading: false);
      _barcodeController.clear();
      HapticFeedback.mediumImpact();
      if (mounted) {
        OmniSnackbar.show(
          context,
          message: 'Barcode berhasil diverifikasi.',
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
          builder: (context) => const InboundBarcodeScannerScreen(),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCameraScannerOpen = false);
    }

    if (scannedCode != null && scannedCode.trim().isNotEmpty && mounted) {
      _barcodeController.text = scannedCode;
      await _verifyBarcode();
    }
  }

  Future<void> _savePutaway() async {
    final item = _selectedItem;
    if (item == null) return;

    final goodQty = int.tryParse(_goodQtyController.text.trim());
    final damagedQty = int.tryParse(_damagedQtyController.text.trim());
    if (goodQty == null ||
        damagedQty == null ||
        goodQty < 0 ||
        damagedQty < 0) {
      OmniSnackbar.show(
        context,
        message: 'Jumlah fisik harus bernilai angka valid.',
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    final itemId = int.tryParse(item.id);
    if (itemId == null) return;

    if (_selectedRack == null || _selectedRack!.isEmpty) {
      OmniSnackbar.show(
        context,
        message: 'Pilih lokasi rak tujuan.',
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(inboundRepositoryProvider.notifier).updateItemTally(
            manifestCode: widget.code,
            itemId: itemId,
            goodQty: goodQty,
            damagedQty: damagedQty,
            targetRack: _selectedRack!,
            damageNote: _damageNoteController.text.trim().isEmpty
                ? null
                : _damageNoteController.text.trim(),
          );
      await _loadDetail(showLoading: false);
      if (!mounted) return;
      OmniSnackbar.show(
        context,
        message: 'Alokasi rak dan kuantitas fisik berhasil disimpan.',
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

  Future<void> _changeHoldStatus(InboundManifest manifest) async {
    String? reason;
    if (manifest.status != InboundStatus.hold) {
      final reasonController = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hold transaksi inbound'),
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
      final notifier = ref.read(inboundRepositoryProvider.notifier);
      if (manifest.status == InboundStatus.hold) {
        await notifier.resumeManifest(widget.code);
      } else {
        await notifier.holdManifest(widget.code, reason: reason);
      }
      await _loadDetail(showLoading: false);
      if (mounted) {
        OmniSnackbar.show(
          context,
          message: manifest.status == InboundStatus.hold
              ? 'Transaksi inbound dilanjutkan.'
              : 'Transaksi inbound di-HOLD.',
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

  Future<void> _commitInbound(InboundManifest manifest) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Commit penerimaan inbound'),
        content: Text(
          'Selesaikan dan simpan stok manifes ${manifest.code} ke rak?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Commit ke Rak'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isCommitting = true);
    try {
      await ref
          .read(inboundRepositoryProvider.notifier)
          .commitManifestApi(widget.code);
      if (!mounted) return;
      OmniSnackbar.show(
        context,
        message: 'Stok fisik berhasil di-commit ke rak gudang.',
        icon: Icons.check_circle_rounded,
      );
      context.go('/inbound');
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
    if (_detail == null) {
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
                  _errorMessage ?? 'Manifes tidak ditemukan.',
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

    final manifest = _detail!.manifest;
    final items = _detail!.items;
    final totalUnits =
        items.fold<int>(0, (sum, item) => sum + item.expectedQty);
    final goodUnits = items.fold<int>(0, (sum, item) => sum + item.goodQty);
    final damagedUnits =
        items.fold<int>(0, (sum, item) => sum + item.damagedQty);
    final progress =
        totalUnits == 0 ? 0.0 : ((goodUnits + damagedUnits) / totalUnits);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Workspace Receiving'),
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
            _buildManifestHeader(manifest),
            const SizedBox(height: 12),
            _buildScanCard(),
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
                    'Valid (Baik)',
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
                    'Rusak (BAP)',
                    '$damagedUnits unit',
                    Icons.warning_amber_rounded,
                    AppColors.warning,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetric(
                    'Progress',
                    '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    Icons.local_shipping_outlined,
                    AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildItemsCard(items),
            if (_selectedItem != null) ...[
              const SizedBox(height: 12),
              _buildPutawayCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManifestHeader(InboundManifest manifest) {
    final isHeld = manifest.status == InboundStatus.hold;
    final canEdit = manifest.status != InboundStatus.closed;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/inbound'),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manifest.code.replaceAll('-', '-\u200B'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      softWrap: true,
                    ),
                    Text(
                      manifest.supplierName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(manifest.status),
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
                    : () => _changeHoldStatus(manifest),
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
                    : () => _commitInbound(manifest),
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
                label: const Text('Commit ke Rak'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScanCard() {
    final canScan = _detail!.manifest.status != InboundStatus.closed &&
        _detail!.manifest.status != InboundStatus.hold;
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
                  onSubmitted: (_) => _verifyBarcode(),
                  decoration: InputDecoration(
                    hintText: 'Scan barcode / kode SKU...',
                    prefixIcon: IconButton(
                      icon: const Icon(Icons.camera_alt_rounded,
                          color: AppColors.primary),
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

  Widget _buildMetric(String title, String value, IconData icon, Color color) {
    return _card(
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
  }

  Widget _buildItemsCard(List<InboundItem> items) {
    return _card(
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
                    'Detail Item Receiving & Putaway',
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
            ...items.map(_buildItemRow),
        ],
      ),
    );
  }

  Widget _buildItemRow(InboundItem item) {
    final selected = _selectedItem?.id == item.id;
    return InkWell(
      onTap: _detail!.manifest.status == InboundStatus.closed
          ? null
          : () => _selectItem(item),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          border: const Border(
            bottom: BorderSide(color: AppColors.border),
          ),
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
                  '${item.goodQty + item.damagedQty}/${item.expectedQty} unit',
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
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              softWrap: true,
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _tag(
                  item.targetRack ?? 'Belum dialokasikan',
                  item.targetRack == null
                      ? AppColors.surfaceAlt
                      : AppColors.primaryLight,
                  item.targetRack == null
                      ? AppColors.textMuted
                      : AppColors.primary,
                ),
                _tag(
                  item.isCompleted ? 'Selesai' : 'Menunggu scan',
                  item.isCompleted
                      ? AppColors.successLight
                      : AppColors.surfaceAlt,
                  item.isCompleted ? AppColors.success : AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPutawayCard() {
    final item = _selectedItem!;
    final rackStock = _locationByRack(_selectedRack)?.stockQuantity;
    final canEdit = _detail!.manifest.status != InboundStatus.closed &&
        _detail!.manifest.status != InboundStatus.hold;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit / Alokasi Rak',
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
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
            softWrap: true,
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
            'Lokasi Rak',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            initialValue:
                _availableRacks.contains(_selectedRack) ? _selectedRack : null,
            isExpanded: true,
            hint: const Text('Pilih lokasi rak'),
            items: _availableRacks
                .map(
                  (rack) {
                    final stock = _locationByRack(rack)?.stockQuantity;
                    return DropdownMenuItem(
                      value: rack,
                      child: Text(
                        stock == null ? rack : '$rack · Stok $stock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                )
                .toList(),
            onChanged:
                canEdit ? (rack) => setState(() => _selectedRack = rack) : null,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (rackStock != null)
            Padding(
              padding: const EdgeInsets.only(top: 5, left: 3),
              child: Text(
                'Stok saat ini di rak: $rackStock unit',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
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
              onPressed: canEdit && !_isSaving ? _savePutaway : null,
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
                _isSaving ? 'Menyimpan alokasi...' : 'Simpan Alokasi Rak',
              ),
            ),
          ),
        ],
      ),
    );
  }

  InboundLocation? _locationByRack(String? rackCode) {
    if (rackCode == null) return null;
    return _detail?.locations
        .where((location) => location.rackCode == rackCode)
        .firstOrNull;
  }

  Widget _quantityField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
  }) =>
      TextField(
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

  Widget _statusBadge(InboundStatus status) => Container(
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

final inboundTenantSlugProvider = Provider<String>((ref) {
  final authState = ref.watch(authProvider);
  return authState.tenantSlug ?? authState.tenantName ?? 'demo-tenant';
});
