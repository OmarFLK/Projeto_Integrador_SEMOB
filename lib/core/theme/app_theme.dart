import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => build(Brightness.light);
  static ThemeData get dark => build(Brightness.dark);

  static ThemeData build(Brightness brightness, {bool compact = false}) {
    final dark = brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF15231C) : AppColors.white;
    final canvas = dark ? const Color(0xFF0D1712) : AppColors.canvas;
    final ink = dark ? const Color(0xFFEDF5F0) : AppColors.ink;
    final muted = dark ? const Color(0xFFA6B9AD) : AppColors.muted;
    final line = dark ? const Color(0xFF2D4035) : AppColors.line;
    final primary = dark ? const Color(0xFF7ED9A5) : AppColors.green;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.green,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: dark ? const Color(0xFF082F1B) : Colors.white,
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: muted,
          outline: line,
          outlineVariant: line,
          error: dark ? const Color(0xFFFFA89D) : AppColors.red,
          primaryContainer: dark
              ? const Color(0xFF213D2D)
              : AppColors.greenLight,
          onPrimaryContainer: dark
              ? const Color(0xFFB8F4D1)
              : AppColors.greenDark,
        );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: line),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'NotoSans',
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      dividerColor: line,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      popupMenuTheme: PopupMenuThemeData(color: surface),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: compact ? 12 : 16,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(0, 44),
          side: BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: line),
        backgroundColor: surface,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(canvas),
        headingTextStyle: TextStyle(
          color: muted,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        dataTextStyle: TextStyle(color: ink, fontSize: 13),
        dividerThickness: 0.7,
      ),
    );
  }
}
