import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const pitch = Color(0xFF0E4D3A);
  static const pitchDeep = Color(0xFF093428);
  static const chalk = Color(0xFFF2F4F0);
  static const ink = Color(0xFF14201B);
  static const muted = Color(0xFF66736C);
  static const line = Color(0xFFDCE2DC);
  static const amber = Color(0xFFD98E04);
  static const red = Color(0xFFC0392B);
}

class AppTheme {
  AppTheme._();

  /// Gaya angka (skor, jam, poin): Barlow Condensed seperti papan skor stadion.
  static TextStyle numeric({
    double size = 26,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.ink,
  }) {
    return GoogleFonts.barlowCondensed(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.pitch)
        .copyWith(primary: AppColors.pitch);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.chalk,
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.pitch,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.barlowCondensed(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.pitch.withAlpha(36),
      ),
    );
  }
}
