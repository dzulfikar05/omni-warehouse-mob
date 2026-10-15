import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum OmniButtonVariant {
  primary,
  secondary,
  danger,
  outline,
}

class OmniButton extends StatelessWidget {
  const OmniButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = OmniButtonVariant.primary,
    this.height = 52.0,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final OmniButtonVariant variant;
  final double height;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    BorderSide side = BorderSide.none;

    switch (variant) {
      case OmniButtonVariant.primary:
        bg = AppColors.primary;
        fg = Colors.white;
        break;
      case OmniButtonVariant.secondary:
        bg = AppColors.surfaceAlt;
        fg = AppColors.textPrimary;
        side = const BorderSide(color: AppColors.border);
        break;
      case OmniButtonVariant.danger:
        bg = AppColors.danger;
        fg = Colors.white;
        break;
      case OmniButtonVariant.outline:
        bg = Colors.transparent;
        fg = AppColors.primary;
        side = const BorderSide(color: AppColors.primaryBorder);
        break;
    }

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    if (isLoading) {
      content = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(fg),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: variant == OmniButtonVariant.primary ? 2 : 0,
          side: side,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: content,
      ),
    );
  }
}
