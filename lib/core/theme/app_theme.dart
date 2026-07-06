import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/models/owner.dart';

/// Row colors per owner, ported from `rowColors()` in
/// acertos/web/src/types/index.ts. Bruna = lavender, Douglas = sage — this
/// is the mapping confirmed against the actual web implementation (the
/// inline comments inside web/tailwind.config.js's `lavender`/`sage` scales
/// say the opposite; those comments are stale, don't trust them).
class OwnerColors {
  const OwnerColors({required this.bg, required this.accent, required this.text});

  final Color bg;
  final Color accent;
  final Color text;
}

OwnerColors ownerColors(Owner owner) => switch (owner) {
  Owner.bruna => const OwnerColors(
    bg: Color(0xFFF2EEFF),
    accent: Color(0xFFA898D0),
    text: Color(0xFF8B80BF),
  ),
  Owner.douglas => const OwnerColors(
    bg: Color(0xFFEDF3E8),
    accent: Color(0xFF8AAB6A),
    text: Color(0xFF50663F),
  ),
  Owner.compartilhado => const OwnerColors(
    bg: Color(0xFFF1EBE4),
    accent: Color(0xFFBAB3AC),
    text: Color(0xFF564F48),
  ),
  Owner.ignorar => const OwnerColors(
    bg: Color(0xFFFAF8F5),
    accent: Color(0xFFD6CDC4),
    text: Color(0xFF847C74),
  ),
};

/// Brand palette, ported from acertos/web/tailwind.config.js (shared with
/// the Entre Dois app).
class AppColors {
  static const cream50 = Color(0xFFFEFAF4);
  static const cream100 = Color(0xFFF5EDDF);
  static const cream200 = Color(0xFFEFE5D4);
  static const cream300 = Color(0xFFD4C9B8);
  static const lavender600 = Color(0xFF8B80BF);
  static const lavender700 = Color(0xFF7872AE);
  static const sage500 = Color(0xFF50663F);
  static const charcoal800 = Color(0xFF1C1917);
  static const charcoal500 = Color(0xFF564F48);
  static const charcoal400 = Color(0xFF847C74);
}

class AppTheme {
  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.lavender600,
      brightness: Brightness.light,
      surface: AppColors.cream50,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.cream50,
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cream50,
        foregroundColor: AppColors.charcoal800,
        elevation: 0,
      ),
    );
  }
}
