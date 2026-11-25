import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Warna identitas (sama untuk mode terang dan gelap).
  static const pitch = Color(0xFF0E4D3A);
  static const pitchDeep = Color(0xFF093428);
  static const pitchBright = Color(0xFF3FAE84);
  static const amber = Color(0xFFD98E04);
  static const red = Color(0xFFC0392B);
  static const blue = Color(0xFF1E6FD9);
  static const orange = Color(0xFFF28C28);

  // Mode terang.
  static const chalk = Color(0xFFF2F4F0);
  static const ink = Color(0xFF14201B);
  static const muted = Color(0xFF66736C);
  static const line = Color(0xFFDCE2DC);

  // Mode gelap.
  static const chalkDark = Color(0xFF0E1512);
  static const surfaceDark = Color(0xFF17211C);
  static const inkDark = Color(0xFFE6ECE8);
  static const mutedDark = Color(0xFF9AA8A0);
  static const lineDark = Color(0xFF2A3630);
}

/// Warna yang menyesuaikan mode terang/gelap.
/// Dipakai lewat `context.palette`.
class Palette {
  const Palette({
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
  });

  final Color background;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;

  /// Warna hijau yang tetap terbaca di atas [surface].
  final Color accent;

  static const light = Palette(
    background: AppColors.chalk,
    surface: Colors.white,
    ink: AppColors.ink,
    muted: AppColors.muted,
    line: AppColors.line,
    accent: AppColors.pitch,
  );

  static const dark = Palette(
    background: AppColors.chalkDark,
    surface: AppColors.surfaceDark,
    ink: AppColors.inkDark,
    muted: AppColors.mutedDark,
    line: AppColors.lineDark,
    accent: AppColors.pitchBright,
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

extension PaletteX on BuildContext {
  Palette get palette => Palette.of(this);
}

class AppTheme {
  AppTheme._();

  /// Gaya angka (skor, jam, poin): Barlow Condensed seperti papan skor stadion.
  /// Bila [color] tidak diisi, warna mengikuti teks tema (terang/gelap).
  static TextStyle numeric({
    double size = 26,
    FontWeight weight = FontWeight.w700,
    Color? color,
  }) {
    return GoogleFonts.barlowCondensed(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final p = isDark ? Palette.dark : Palette.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.pitch,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? AppColors.pitchBright : AppColors.pitch,
      surface: p.surface,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: p.background,
      textTheme: base.textTheme.apply(
        bodyColor: p.ink,
        displayColor: p.ink,
      ),
      dividerColor: p.line,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.pitchDeep : AppColors.pitch,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.barlowCondensed(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.accent.withAlpha(48),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.surface),
    );
  }
}
