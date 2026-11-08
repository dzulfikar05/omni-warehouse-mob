import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';

class InboundBarcodeScannerScreen extends StatefulWidget {
  const InboundBarcodeScannerScreen({super.key});

  @override
  State<InboundBarcodeScannerScreen> createState() =>
      _InboundBarcodeScannerScreenState();
}

class _InboundBarcodeScannerScreenState
    extends State<InboundBarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _hasScanned = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;

      _hasScanned = true;
      Navigator.of(context).pop(value);
      return;
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } on MobileScannerException catch (error) {
      if (!mounted) return;
      final detail = error.errorDetails?.message ?? error.errorCode.name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lampu kamera tidak dapat diubah: $detail')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Scan Barcode / SKU',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, child) => IconButton(
              tooltip: 'Nyalakan atau matikan lampu',
              icon: Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on
                    : Icons.flash_off,
                color: Colors.white,
              ),
              onPressed: !state.isInitialized ||
                      state.torchState == TorchState.unavailable
                  ? null
                  : _toggleTorch,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              final message = error.errorCode ==
                      MobileScannerErrorCode.permissionDenied
                  ? 'Izin kamera ditolak. Aktifkan izin kamera di pengaturan '
                      'aplikasi.'
                  : 'Kamera tidak dapat dibuka: '
                      '${error.errorDetails?.message ?? error.errorCode.name}';
              return ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.no_photography_outlined,
                          color: Colors.white70,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            overlayBuilder: (context, constraints) => Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Text(
              'Arahkan kamera ke barcode produk atau SKU',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
