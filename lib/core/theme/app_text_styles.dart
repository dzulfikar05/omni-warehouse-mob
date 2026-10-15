import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography tokens — font Inter (Google Fonts).
abstract final class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.5,
  );
  static const TextStyle heading2 = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.3,
  );
  static const TextStyle heading3 = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );
  // Monospace — untuk kode manifest, barcode, transfer code
  static const TextStyle mono = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w700,
    fontFamily: 'RobotoMono', color: AppColors.primary,
  );
  static const TextStyle monoSmall = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500,
    fontFamily: 'RobotoMono', color: AppColors.textSecondary,
  );
}
