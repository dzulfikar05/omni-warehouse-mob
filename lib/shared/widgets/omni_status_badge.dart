import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum OmniBadgeVariant {
  primary,
  success,
  warning,
  danger,
  neutral,
}

class OmniStatusBadge extends StatelessWidget {
  const OmniStatusBadge({
    super.key,
    required this.label,
    this.variant = OmniBadgeVariant.primary,
    this.isMono = true,
    this.prefixIcon,
  });

  final String label;
  final OmniBadgeVariant variant;
  final bool isMono;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;

    switch (variant) {
      case OmniBadgeVariant.primary:
        bg = AppColors.primaryLight;
        border = AppColors.primaryBorder;
        text = AppColors.primary;
        break;
      case OmniBadgeVariant.success:
        bg = AppColors.successLight;
        border = AppColors.successBorder;
        text = AppColors.success;
        break;
      case OmniBadgeVariant.warning:
        bg = AppColors.warningLight;
        border = AppColors.warningBorder;
        text = AppColors.warning;
        break;
      case OmniBadgeVariant.danger:
        bg = AppColors.dangerLight;
        border = AppColors.dangerBorder;
        text = AppColors.danger;
        break;
      case OmniBadgeVariant.neutral:
        bg = AppColors.surfaceAlt;
        border = AppColors.border;
        text = AppColors.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, size: 11, color: text),
            const SizedBox(width: 3.5),
          ],
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFamily: isMono ? 'RobotoMono' : null,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
