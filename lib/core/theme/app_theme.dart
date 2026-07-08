import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette. `lavender`/`salvia` match the original web app's palette
/// (acertos/web/tailwind.config.js, shared with Entre Dois); the rest of the
/// Material 3 token set (surface/outline/error/inverse-surface/etc.) comes
/// from the UI mockup applied on 2026-07-07, which restyled the app around
/// white cards + accent pills instead of per-owner tinted row backgrounds.
class AppColors {
  static const background = Color(0xFFFDF8FE);
  static const brandCard = Color(0xFFFFFCFA);
  static const primary = Color(0xFF5E548F);
  static const primaryContainer = Color(0xFF776CAA);
  static const onPrimaryContainer = Color(0xFFFFFBFF);
  static const lavender = Color(0xFF8B80BF);
  static const salvia = Color(0xFF50663F);
  static const onSurface = Color(0xFF1C1B1F);
  static const onSurfaceVariant = Color(0xFF48454F);
  static const outline = Color(0xFF797580);
  static const outlineVariant = Color(0xFFC9C4D0);
  static const surfaceVariant = Color(0xFFE6E1E7);
  static const surfaceContainerLow = Color(0xFFF7F2F8);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const error = Color(0xFFBA1A1A);
  static const inverseSurface = Color(0xFF313034);
  static const inverseOnSurface = Color(0xFFF4EFF5);
}

class AppTheme {
  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.lavender,
      brightness: Brightness.light,
      surface: AppColors.background,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
      ),
    );
  }
}
