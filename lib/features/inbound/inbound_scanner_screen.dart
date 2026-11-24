import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/utils/connectivity_checker.dart';
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
      if (availableRacks.isEmpty &&
          _availableRacks.isEmpty &&
          !detail.manifest.isOfflinePending) {
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
    });
    _openItemPutawaySheet(item);
  }

  InboundItem? _findItemByCode(String code) {
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

  Future<void> _handleBarcodeSubmit() async {
    if (_isScanning) return;

    final code = _barcodeController.text.trim();
    if (code.isEmpty) {
      OmniSnackbar.show(
        context,
        message: 'Masukkan atau scan barcode/SKU terlebih dahulu.',
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    final matched = _findItemByCode(code);
    if (matched != null) {
      _barcodeController.clear();
      HapticFeedback.mediumImpact();
      _selectItem(matched);
      return;
    }

    // Jika belum ditemukan di cache lokal, coba panggil API verifyBarcode backend
    setState(() => _isScanning = true);
    try {
      await ref
          .read(inboundRepositoryProvider.notifier)
          .verifyBarcode(widget.code, code);
      await _loadDetail(showLoading: false);
      _barcodeController.clear();
      HapticFeedback.mediumImpact();

      final refreshedMatch = _findItemByCode(code);
      if (refreshedMatch != null && mounted) {
        _selectItem(refreshedMatch);
      } else if (mounted) {
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
          builder: (context) => const InboundBarcodeScannerScreen(),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCameraScannerOpen = false);
    }

    if (scannedCode != null && scannedCode.trim().isNotEmpty && mounted) {
      _barcodeController.text = scannedCode;
      await _handleBarcodeSubmit();
    }
  }

  Future<void> _savePutawayData({
    required InboundItem item,
    required int goodQty,
    required int damagedQty,
    required String targetRack,
    String? damageNote,
  }) async {
    final itemId = int.tryParse(item.id);
    if (itemId == null) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(inboundRepositoryProvider.notifier).updateItemTally(
            manifestCode: widget.code,
            itemId: item.id,
            goodQty: goodQty,
            damagedQty: damagedQty,
            targetRack: targetRack,
            damageNote: damageNote,
            snapshot: _detail,
          );
      await _loadDetail(showLoading: false);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      OmniSnackbar.show(
        context,
        message:
            'Item ${item.sku.isEmpty ? item.barcode : item.sku} ($goodQty baik, $damagedQty rusak) disimpan ke Rak $targetRack.',
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

  void _openItemPutawaySheet(InboundItem item) {
    final canEdit = _detail!.manifest.status != InboundStatus.closed &&
        _detail!.manifest.status != InboundStatus.hold;

    final initialGoodQty = item.goodQty > 0
        ? item.goodQty
        : (item.expectedQty - item.damagedQty > 0
            ? item.expectedQty - item.damagedQty
            : item.expectedQty);

    final goodQtyCtrl = TextEditingController(text: initialGoodQty.toString());
    final damagedQtyCtrl =
        TextEditingController(text: item.damagedQty.toString());
    final damageNoteCtrl = TextEditingController(text: item.notes ?? '');
    String? currentRack = item.targetRack != null &&
            _availableRacks.contains(item.targetRack)
        ? item.targetRack
        : (_availableRacks.isNotEmpty ? _availableRacks.first : null);

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

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
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
                              Icons.inventory_2_outlined,
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
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: item.isCompleted
                                            ? AppColors.successLight
                                            : AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: item.isCompleted
                                              ? AppColors.successBorder
                                              : AppColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        'Target PO: ${item.expectedQty} unit',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: item.isCompleted
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
                            icon: const Icon(Icons.close_rounded,
                                size: 20, color: AppColors.textMuted),
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
                              label: 'Jumlah Baik (Unit)',
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
                              label: 'Jumlah Rusak (Unit)',
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

                      // Rack Selection
                      const Text(
                        'Lokasi Rak Tujuan Putaway',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _availableRacks.contains(currentRack)
                            ? currentRack
                            : null,
                        isExpanded: true,
                        hint: const Text('Pilih lokasi rak tujuan'),
                        items: _availableRacks
                            .map((rack) => DropdownMenuItem(
                                  value: rack,
                                  child: Text(rack),
                                ))
                            .toList(),
                        onChanged: canEdit
                            ? (rack) =>
                                setSheetState(() => currentRack = rack)
                            : null,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.grid_view_rounded,
                              size: 18, color: AppColors.textSecondary),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Damage Note
                      TextField(
                        controller: damageNoteCtrl,
                        enabled: canEdit,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Catatan kondisi / kerusakan (opsional)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: canEdit && !_isSaving
                              ? () async {
                                  final goodQty = int.tryParse(
                                          goodQtyCtrl.text.trim()) ??
                                      0;
                                  final damagedQty = int.tryParse(
                                          damagedQtyCtrl.text.trim()) ??
                                      0;

                                  if (currentRack == null ||
                                      currentRack!.isEmpty) {
                                    OmniSnackbar.show(
                                      context,
                                      message:
                                          'Pilih lokasi rak tujuan terlebih dahulu.',
                                      icon: Icons.error_outline_rounded,
                                    );
                                    return;
                                  }

                                  Navigator.pop(sheetContext);
                                  await _savePutawayData(
                                    item: item,
                                    goodQty: goodQty,
                                    damagedQty: damagedQty,
                                    targetRack: currentRack!,
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
                              : const Icon(Icons.check_circle_outline_rounded,
                                  size: 18),
                          label: Text(
                            _isSaving
                                ? 'Menyimpan...'
                                : 'Simpan & Alokasikan ke Rak',
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
        await notifier.resumeManifest(manifest.code);
      } else {
        await notifier.holdManifest(manifest.code, reason: reason);
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
      final committed = await ref
          .read(inboundRepositoryProvider.notifier)
          .commitManifestApi(manifest.code, snapshot: _detail);
      if (!mounted) return;
      final isOnline = ref.read(connectivityStatusProvider);
      OmniSnackbar.show(
        context,
        message: committed
            ? 'Stok fisik berhasil di-commit ke rak gudang.'
            : isOnline
            ? 'Commit belum berhasil. Coba lagi.'
            : 'Tidak ada jaringan. Commit tersimpan di perangkat dan akan dikirim saat jaringan tersedia.',
        icon: committed
            ? Icons.check_circle_rounded
            : isOnline
            ? Icons.error_outline_rounded
            : Icons.cloud_upload_outlined,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manifest.code.replaceAll('-', '-\u200B'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'RobotoMono',
                        color: AppColors.textPrimary,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 2),
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
              const SizedBox(width: 8),
              _statusBadge(manifest.status),
            ],
          ),
          const Divider(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed:
                    !canEdit || manifest.isOfflinePending || _isUpdatingStatus
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
                onPressed: !canEdit ||
                        isHeld ||
                        _isCommitting ||
                        _isUpdatingStatus
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
                  'Scan Barcode / Cari SKU',
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
                      icon: const Icon(Icons.camera_alt_rounded,
                          color: AppColors.primary, size: 20),
                      tooltip: 'Buka Kamera Scanner',
                      onPressed: canScan && !_isScanning && !_isCameraScannerOpen
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
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: canScan && !_isScanning ? _handleBarcodeSubmit : null,
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
    final canEdit = _detail!.manifest.status != InboundStatus.closed &&
        _detail!.manifest.status != InboundStatus.hold;
    final isDone = item.isCompleted;
    final hasDamage = item.damagedQty > 0;
    final selected = _selectedItem?.id == item.id;

    return InkWell(
      onTap: canEdit ? () => _selectItem(item) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryLight.withValues(alpha: 0.4)
              : (isDone ? const Color(0xFFF0FDF4) : AppColors.surface),
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
                        const Icon(Icons.check_circle_rounded,
                            size: 14, color: AppColors.success),
                      ],
                    ],
                  ),
                ),
                Text(
                  '${item.totalScanned}/${item.expectedQty} unit',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'RobotoMono',
                    fontWeight: FontWeight.w700,
                    color: isDone
                        ? AppColors.success
                        : (item.totalScanned > 0
                            ? AppColors.warning
                            : AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              softWrap: true,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _tag(
                  item.targetRack != null
                      ? 'Rak ${item.targetRack}'
                      : 'Belum di rak',
                  item.targetRack != null
                      ? AppColors.primaryLight
                      : AppColors.surfaceAlt,
                  item.targetRack != null
                      ? AppColors.primary
                      : AppColors.textMuted,
                ),
                _tag(
                  isDone
                      ? 'Lengkap (100%)'
                      : (item.totalScanned > 0
                          ? 'Sebagian (${item.totalScanned} unit)'
                          : 'Menunggu scan'),
                  isDone
                      ? AppColors.successLight
                      : (item.totalScanned > 0
                          ? AppColors.warningLight
                          : AppColors.surfaceAlt),
                  isDone
                      ? AppColors.success
                      : (item.totalScanned > 0
                          ? AppColors.warning
                          : AppColors.textMuted),
                ),
                if (hasDamage)
                  _tag(
                    '${item.damagedQty} Rusak/BAP',
                    const Color(0xFFFEF2F2),
                    AppColors.danger,
                  ),
              ],
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
              Icon(prefixIcon,
                  size: 14, color: iconColor ?? AppColors.textSecondary),
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
