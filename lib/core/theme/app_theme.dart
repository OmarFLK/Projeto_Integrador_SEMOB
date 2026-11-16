import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'design_tokens.dart';

abstract final class AppTheme {
  static ThemeData get light => build(Brightness.light);
  static ThemeData get dark => build(Brightness.dark);
  static ThemeData build(Brightness brightness, {bool compact = false}) {
    final dark = brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF192F23) : const Color(0xFFF9FAEF);
    final ink = dark ? const Color(0xFFF0F3E3) : AppColors.ink;
    final muted = dark ? const Color(0xFFB1BDA6) : AppColors.muted;
    final line = dark ? const Color(0xFF354C37) : AppColors.line;
    final primary = dark ? AppColors.lime : AppColors.green;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.moss,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: dark ? AppColors.forestBlack : Colors.white,
          secondary: dark ? AppColors.sage : AppColors.moss,
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: muted,
          outline: line,
          outlineVariant: line.withValues(alpha: .65),
          error: dark ? const Color(0xFFFFA294) : AppColors.red,
          primaryContainer: dark
              ? const Color(0xFF31482C)
              : AppColors.greenLight,
          onPrimaryContainer: dark ? AppColors.lime : AppColors.greenDark,
        );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: line),
    );
    final text = Typography.material2021().black.apply(
      bodyColor: ink,
      displayColor: ink,
      fontFamily: 'NotoSans',
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? AppColors.forestBlack : AppColors.canvas,
      fontFamily: 'NotoSans',
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.3,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -.9,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -.6,
          fontFeatures: [const FontFeature.tabularFigures()],
        ),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.5),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      dividerColor: line,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 350),
        decoration: BoxDecoration(
          color: AppColors.forest,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(color: AppColors.ivory, fontSize: 12),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: line),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        showDragHandle: true,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius),
          side: BorderSide(color: line.withValues(alpha: .8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF14291E) : const Color(0xFFF1F4E6),
        labelStyle: TextStyle(color: muted, fontSize: 13),
        hintStyle: TextStyle(color: muted, fontSize: 13),
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
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(0, 46),
          side: BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(44, 44),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: line),
        backgroundColor: surface,
        selectedColor: scheme.primaryContainer,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(
          scheme.primaryContainer.withValues(alpha: .3),
        ),
        headingTextStyle: TextStyle(
          color: muted,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        dataTextStyle: TextStyle(
          color: ink,
          fontSize: 12,
          fontFeatures: [const FontFeature.tabularFigures()],
        ),
        dataRowMinHeight: 52,
        dataRowMaxHeight: 64,
        columnSpacing: 24,
        dividerThickness: .5,
      ),
    );
  }
}
