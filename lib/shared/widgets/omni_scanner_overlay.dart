import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class OmniScannerOverlay extends StatefulWidget {
  const OmniScannerOverlay({
    super.key,
    this.instruction = 'Arahkan kamera ke Barcode / QR item',
    this.boxSize = 280.0,
  });

  final String instruction;
  final double boxSize;

  @override
  State<OmniScannerOverlay> createState() => _OmniScannerOverlayState();
}

class _OmniScannerOverlayState extends State<OmniScannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: widget.boxSize,
        height: widget.boxSize,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Center instruction & icon
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_2_rounded,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      widget.instruction,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'RobotoMono',
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Animated Laser Sweep Line
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final topOffset =
                    16.0 + _controller.value * (widget.boxSize - 36.0);
                return Positioned(
                  top: topOffset,
                  left: 12,
                  right: 12,
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0xFF60A5FA),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.8),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Tactical Corner Reticles (Primary Color)
            _buildCorner(Alignment.topLeft, top: true, left: true),
            _buildCorner(Alignment.topRight, top: true, left: false),
            _buildCorner(Alignment.bottomLeft, top: false, left: true),
            _buildCorner(Alignment.bottomRight, top: false, left: false),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner(Alignment alignment, {required bool top, required bool left}) {
    const double length = 26.0;
    const double thickness = 3.0;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: length,
          height: length,
          child: CustomPaint(
            painter: _CornerPainter(
              color: AppColors.primary,
              top: top,
              left: left,
              thickness: thickness,
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  _CornerPainter({
    required this.color,
    required this.top,
    required this.left,
    required this.thickness,
  });

  final Color color;
  final bool top;
  final bool left;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, 4);
      path.quadraticBezierTo(0, 0, 4, 0);
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width - 4, 0);
      path.quadraticBezierTo(size.width, 0, size.width, 4);
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height - 4);
      path.quadraticBezierTo(0, size.height, 4, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height - 4);
      path.quadraticBezierTo(size.width, size.height, size.width - 4, size.height);
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
