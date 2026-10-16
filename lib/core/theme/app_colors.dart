import 'package:flutter/material.dart';

abstract final class AppColors {
  static const green = Color(0xFF08783E);
  static const greenDark = Color(0xFF045D30);
  static const greenLight = Color(0xFFE7F3EC);
  static const charcoal = Color(0xFF1D2722);
  static const graphite = Color(0xFF26312C);
  static const ink = Color(0xFF18201C);
  static const muted = Color(0xFF66736C);
  static const line = Color(0xFFE1E7E3);
  static const canvas = Color(0xFFF5F7F6);
  static const white = Color(0xFFFFFFFF);
  static const amber = Color(0xFFB86900);
  static const amberSoft = Color(0xFFFFF3DC);
  static const red = Color(0xFFB42318);
  static const redSoft = Color(0xFFFFEDEA);
  static const blue = Color(0xFF246B9E);
  static const blueSoft = Color(0xFFEAF3FA);
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => AppPalette(Theme.of(this).colorScheme);
}

class AppPalette {
  const AppPalette(this.scheme);
  final ColorScheme scheme;
  bool get isDark => scheme.brightness == Brightness.dark;
  Color get ink => scheme.onSurface;
  Color get muted => scheme.onSurfaceVariant;
  Color get line => scheme.outline;
  Color get surface => scheme.surface;
  Color get canvas => isDark ? const Color(0xFF0D1712) : AppColors.canvas;
  Color get green => scheme.primary;
  Color get greenLight => scheme.primaryContainer;
  Color get greenDark => scheme.onPrimaryContainer;
  Color get redSoft => isDark ? const Color(0xFF462923) : AppColors.redSoft;
  Color get amberSoft => isDark ? const Color(0xFF3B321E) : AppColors.amberSoft;
  Color get blueSoft => isDark ? const Color(0xFF203744) : AppColors.blueSoft;
  Color get red => scheme.error;
  Color get amber => isDark ? const Color(0xFFF1C56A) : AppColors.amber;
  Color get blue => isDark ? const Color(0xFF8DCBF1) : AppColors.blue;
  Color get graphite => isDark ? const Color(0xFFCCDCD2) : AppColors.graphite;
}
