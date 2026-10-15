import 'package:flutter/material.dart';

/// Colour tokens. Same values as the NegosyoPlan design canvas.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF0A5763); // brand teal, from the logo
  static const primaryHover = Color(0xFF074550);
  static const tint = Color(0xFFE2F2F0);
  static const tint2 = Color(0xFFF4FAF8);
  static const tintBorder = Color(0xFFCFE3DF);
  static const mint = Color(0xFF8CC48A);
  static const text = Color(0xFF18201C);
  static const text2 = Color(0xFF3E4843);
  static const muted = Color(0xFF59625D);
  static const muted2 = Color(0xFF6B746F);
  static const hint = Color(0xFF8A938E);
  static const border = Color(0xFFE8ECE9);
  static const borderStrong = Color(0xFFCBD2CD);
  static const divider = Color(0xFFECEFEC);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF5F7F6);
  static const track = Color(0xFFE6EAE6);
  static const actualBg = Color(0xFFE3ECFA);
  static const actualFg = Color(0xFF1E3A8A);
  static const estimateBg = Color(0xFFFCEFD9);
  static const estimateFg = Color(0xFF8A4B08);
  static const missingBg = Color(0xFFFBE9E9);
  static const missingFg = Color(0xFF8F1D1D);
  static const missingBorder = Color(0xFFEBCACA);
  static const warnBg = Color(0xFFFFF4E5);
  static const warnBorder = Color(0xFFF1C98A);
  static const adminBg = Color(0xFFFAFBFA);
  static const adminSideMuted = Color(0xFFBFDCD8);
}

/// Text styles. Large, readable, few weights (users are 40–60 years old).
class AppText {
  AppText._();

  static const h1 = TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.25, color: AppColors.text);
  static const h1Desktop = TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.15, color: AppColors.text);
  static const h2 = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.25, color: AppColors.text);
  static const label = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3, color: AppColors.text);
  static const body = TextStyle(fontSize: 17, height: 1.45, color: AppColors.text);
  static const lead = TextStyle(fontSize: 17, height: 1.45, color: AppColors.text2);
  static const small = TextStyle(fontSize: 14, height: 1.4, color: AppColors.muted2);
  static const tiny = TextStyle(fontSize: 13, height: 1.35, color: AppColors.muted);
  static const number = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text);
  static const eyebrow = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.primary);
}

class AppTheme {
  AppTheme._();

  static const fontFamily = 'AtkinsonHyperlegible';
  static const fontFallback = <String>['DejaVuSans'];

  static ThemeData light({double textScale = 1}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.surface,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.borderStrong),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      scaffoldBackgroundColor: AppColors.surface,
      dividerColor: AppColors.divider,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        hintStyle: const TextStyle(color: AppColors.hint, fontSize: 18),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.primary, width: 2)),
        errorBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.missingFg, width: 1.5)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.primary : Colors.white,
        ),
        side: const BorderSide(color: AppColors.borderStrong, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.text,
        contentTextStyle: TextStyle(fontSize: 16, color: Colors.white, fontFamily: fontFamily),
      ),
    );
  }
}
