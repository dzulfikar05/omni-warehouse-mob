import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/omni_snackbar.dart';
import 'stock_opname_model.dart';
import 'stock_opname_repository.dart';

class StockOpnameScannerScreen extends ConsumerStatefulWidget {
  const StockOpnameScannerScreen({super.key, this.sessionCode});

  final String? sessionCode;

  @override
  ConsumerState<StockOpnameScannerScreen> createState() =>
      _StockOpnameScannerScreenState();
}

class _StockOpnameScannerScreenState
    extends ConsumerState<StockOpnameScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _cameraOpen = false;
  bool _isRecording = false;
  bool _isSubmittingReview = false;

  @override
  void dispose() {
    unawaited(_scannerController.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isRecording) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        unawaited(_recordScannedBarcode(value));
        return;
      }
    }
  }

  Future<void> _recordScannedBarcode(String barcode) async {
    if (_isRecording) return;
    final session = ref.read(stockOpnameRepositoryProvider).asData?.value;
    if (session == null) return;
    final normalizedBarcode = barcode.toLowerCase();
    StockOpnameItem? item;
    for (final candidate in session.items) {
      if (candidate.barcode.toLowerCase() == normalizedBarcode ||
          candidate.sku.toLowerCase() == normalizedBarcode) {
        item = candidate;
        break;
      }
    }
    if (item == null) {
      OmniSnackbar.show(
        context,
        message: 'Barcode $barcode tidak termasuk dalam sesi ini.',
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.danger,
      );
      return;
    }

    setState(() => _isRecording = true);
    try {
      final quantity = (item.physicalQty ?? 0) + 1;
      await ref
          .read(stockOpnameRepositoryProvider.notifier)
          .recordCount(itemId: item.id, physicalQty: quantity);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      OmniSnackbar.show(
        context,
        message: '${item.sku}: jumlah fisik $quantity ${item.unit}',
        icon: Icons.check_circle_rounded,
      );
    } catch (error) {
      if (mounted) {
        OmniSnackbar.show(
          context,
          message: error.toString(),
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _editPhysicalQty(StockOpnameItem item) async {
    final quantity = await showDialog<int>(
      context: context,
      builder: (_) => _PhysicalCountDialog(item: item),
    );
    if (quantity == null || !mounted) return;
    try {
      await ref
          .read(stockOpnameRepositoryProvider.notifier)
          .recordCount(itemId: item.id, physicalQty: quantity);
      if (mounted) {
        OmniSnackbar.show(context, message: 'Jumlah fisik berhasil disimpan.');
      }
    } catch (error) {
      if (mounted) {
        OmniSnackbar.show(
          context,
          message: error.toString(),
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.danger,
        );
      }
    }
  }

  Future<void> _submitReview(StockOpnameSession session) async {
    if (!session.allItemsCounted || _isSubmittingReview) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kirim untuk review?'),
        content: const Text(
          'Sesi opname akan dikirim ke supervisor untuk ditinjau.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit Review'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmittingReview = true);
    try {
      await ref.read(stockOpnameRepositoryProvider.notifier).submitReview();
      if (!mounted) return;
      OmniSnackbar.show(
        context,
        message: 'Sesi opname berhasil dikirim untuk review supervisor.',
      );
    } catch (error) {
      if (mounted) {
        OmniSnackbar.show(
          context,
          message: error.toString(),
          icon: Icons.error_outline_rounded,
          iconColor: AppColors.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(stockOpnameRepositoryProvider);
    final session = sessionState.asData?.value;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hitung Stock Opname'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: () => context.go('/more/opname'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: sessionState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ScannerMessage(
              message: error.toString(),
              onRetry: () => ref
                  .read(stockOpnameRepositoryProvider.notifier)
                  .loadActiveSession(),
            ),
            data: (session) {
              if (session == null ||
                  (widget.sessionCode != null &&
                      widget.sessionCode!.toLowerCase() !=
                          session.sessionCode.toLowerCase())) {
                return const _ScannerMessage(
                  message:
                      'Sesi stock opname tidak ditemukan atau sudah tidak aktif.',
                );
              }
              return _buildSessionContent(session);
            },
          ),
        ),
      ),
      bottomNavigationBar: session != null
          ? SafeArea(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!session.allItemsCounted && !session.isInReview)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Hitung semua item sebelum mengirim sesi.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            session.allItemsCounted &&
                                !session.isInReview &&
                                !_isSubmittingReview
                            ? () => _submitReview(session)
                            : null,
                        icon: _isSubmittingReview
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.fact_check_outlined),
                        label: Text(
                          session.isInReview
                              ? 'Sudah dikirim untuk review'
                              : _isSubmittingReview
                              ? 'Mengirim...'
                              : 'Selesaikan Opname / Submit Review',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSessionContent(StockOpnameSession session) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
    children: [
      _SessionInfoCard(session: session),
      const SizedBox(height: 12),
      _buildScannerPanel(),
      const SizedBox(height: 16),
      Row(
        children: [
          const Expanded(
            child: Text(
              'SKU TARGET',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Text(
            '${session.countedItems}/${session.items.length} dihitung',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (session.items.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: Text(
              'Tidak ada SKU untuk dihitung.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        )
      else
        ...session.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CountItemCard(
              item: item,
              onEdit: () => _editPhysicalQty(item),
            ),
          ),
        ),
    ],
  );

  Widget _buildScannerPanel() => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        if (_cameraOpen)
          SizedBox(
            height: 210,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    final message =
                        error.errorCode ==
                            MobileScannerErrorCode.permissionDenied
                        ? 'Izin kamera ditolak. Aktifkan izin kamera di pengaturan.'
                        : 'Kamera tidak dapat dibuka: '
                              '${error.errorDetails?.message ?? error.errorCode.name}';
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _scannerController,
                    builder: (context, state, _) => IconButton.filledTonal(
                      tooltip: 'Lampu kamera',
                      onPressed:
                          !state.isInitialized ||
                              state.torchState == TorchState.unavailable
                          ? null
                          : () => _scannerController.toggleTorch(),
                      icon: Icon(
                        state.torchState == TorchState.on
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 17, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Scan barcode SKU di rak target untuk menambah hitungan fisik.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _cameraOpen = !_cameraOpen),
                  icon: Icon(
                    _cameraOpen
                        ? Icons.videocam_off_outlined
                        : Icons.camera_alt_outlined,
                  ),
                  label: Text(_cameraOpen ? 'Tutup kamera' : 'Buka kamera'),
                ),
              ),
              const SizedBox(width: 8),
              if (_isRecording)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SessionInfoCard extends StatelessWidget {
  const _SessionInfoCard({required this.session});

  final StockOpnameSession session;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          session.sessionCode,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontFamily: 'RobotoMono',
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Gudang: ${session.warehouse.isEmpty ? '-' : session.warehouse}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          'Zona: ${session.zone.isEmpty ? '-' : session.zone}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(
              Icons.visibility_off_outlined,
              color: AppColors.primary,
              size: 15,
            ),
            SizedBox(width: 5),
            Text(
              'Blind count · stok sistem disembunyikan',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _CountItemCard extends StatelessWidget {
  const _CountItemCard({required this.item, required this.onEdit});

  final StockOpnameItem item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.physicalQty == null
                ? AppColors.border
                : AppColors.successBorder,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.sku,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontFamily: 'RobotoMono',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rak target: ${item.targetRack.isEmpty ? '-' : item.targetRack}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.physicalQty == null
                      ? '—'
                      : '${item.physicalQty} ${item.unit}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  'Jumlah fisik',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _PhysicalCountDialog extends StatefulWidget {
  const _PhysicalCountDialog({required this.item});

  final StockOpnameItem item;

  @override
  State<_PhysicalCountDialog> createState() => _PhysicalCountDialogState();
}

class _PhysicalCountDialogState extends State<_PhysicalCountDialog> {
  late final TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.item.physicalQty?.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Jumlah fisik'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${widget.item.sku} · ${widget.item.targetRack}'),
        const SizedBox(height: 12),
        TextField(
          controller: _quantityController,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Qty fisik (${widget.item.unit})',
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          final parsed = int.tryParse(_quantityController.text.trim());
          if (parsed == null || parsed < 0) return;
          FocusScope.of(context).unfocus();
          Navigator.pop(context, parsed);
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}

class _ScannerMessage extends StatelessWidget {
  const _ScannerMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Muat ulang')),
          ],
        ],
      ),
    ),
  );
}
