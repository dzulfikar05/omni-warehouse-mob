import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography tokens — font Inter (Google Fonts).
abstract final class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.4,
    height: 1.2,
  );
  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.25,
  );
  static const TextStyle heading3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.45,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.4,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    height: 1.35,
    letterSpacing: 0.1,
  );
  // Monospace — untuk kode manifest, barcode, transfer code
  static const TextStyle mono = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    fontFamily: 'RobotoMono',
    color: AppColors.primary,
    height: 1.3,
    letterSpacing: 0.2,
  );
  static const TextStyle monoSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    fontFamily: 'RobotoMono',
    color: AppColors.textSecondary,
    height: 1.35,
    letterSpacing: 0.15,
  );
}
