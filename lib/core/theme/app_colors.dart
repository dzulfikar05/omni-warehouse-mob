import 'package:flutter/material.dart';

/// Design token warna — selaras dengan web omni-warehouse (Tailwind palette).
/// Tidak ada hardcoded Color() di luar file ini.
abstract final class AppColors {
  // Primary — Blue-600 (konsisten dengan web)
  static const Color primary       = Color(0xFF2563EB);
  static const Color primaryDark   = Color(0xFF1D4ED8);
  static const Color primaryLight  = Color(0xFFEFF6FF);
  static const Color primaryBorder = Color(0xFFBFDBFE);

  // Success — Emerald-600
  static const Color success       = Color(0xFF059669);
  static const Color successLight  = Color(0xFFECFDF5);
  static const Color successBorder = Color(0xFF6EE7B7);

  // Warning — Amber-600
  static const Color warning       = Color(0xFFD97706);
  static const Color warningLight  = Color(0xFFFFFBEB);
  static const Color warningBorder = Color(0xFFFDE68A);

  // Danger — Rose-600
  static const Color danger        = Color(0xFFE11D48);
  static const Color dangerLight   = Color(0xFFFFF1F2);
  static const Color dangerBorder  = Color(0xFFFDA4AF);

  // Neutral — Slate
  static const Color textPrimary   = Color(0xFF0F172A); // slate-900
  static const Color textSecondary = Color(0xFF475569); // slate-600
  static const Color textMuted     = Color(0xFF94A3B8); // slate-400
  static const Color border        = Color(0xFFE2E8F0); // slate-200
  static const Color borderStrong  = Color(0xFFCBD5E1); // slate-300
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color surfaceAlt    = Color(0xFFF8FAFC); // slate-50
  static const Color background    = Color(0xFFF1F5F9); // slate-100
}
