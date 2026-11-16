import 'package:flutter/material.dart';

abstract final class AppColors {
  static const forestBlack = Color(0xFF0F1F17);
  static const forest = Color(0xFF1E3A2E);
  static const moss = Color(0xFF3E5A3F);
  static const sage = Color(0xFF789575);
  static const mutedSage = Color(0xFF6B7F67);
  static const softSage = Color(0xFFC7CBB8);
  static const ivory = Color(0xFFE5E8CE);
  static const olive = Color(0xFF3D4337);
  static const lime = Color(0xFFCBEA65);
  static const green = Color(0xFF365B35);
  static const greenDark = Color(0xFF203E2D);
  static const greenLight = Color(0xFFE3EACF);
  static const charcoal = forestBlack;
  static const graphite = olive;
  static const ink = Color(0xFF17281E);
  static const muted = Color(0xFF58644F);
  static const line = Color(0xFFD4DCC4);
  static const canvas = Color(0xFFF0F2E5);
  static const white = Color(0xFFFFFFFF);
  static const amber = Color(0xFF925A0A);
  static const amberSoft = Color(0xFFFFEFD0);
  static const red = Color(0xFFAF392F);
  static const redSoft = Color(0xFFFFE8E1);
  static const blue = Color(0xFF326E83);
  static const blueSoft = Color(0xFFE2EFF0);
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
  Color get canvas => isDark ? AppColors.forestBlack : AppColors.canvas;
  Color get elevated =>
      isDark ? const Color(0xFF223C2D) : const Color(0xFFFAFBEF);
  Color get green => scheme.primary;
  Color get greenLight => scheme.primaryContainer;
  Color get greenDark => scheme.onPrimaryContainer;
  Color get redSoft => isDark ? const Color(0xFF422B27) : AppColors.redSoft;
  Color get amberSoft => isDark ? const Color(0xFF3D3622) : AppColors.amberSoft;
  Color get blueSoft => isDark ? const Color(0xFF203C3D) : AppColors.blueSoft;
  Color get red => scheme.error;
  Color get amber => isDark ? const Color(0xFFF1C579) : AppColors.amber;
  Color get blue => isDark ? const Color(0xFF93CBCD) : AppColors.blue;
  Color get graphite => isDark ? AppColors.softSage : AppColors.olive;
  List<Color> get chartColors => [
    green,
    blue,
    amber,
    graphite,
    const Color(0xFFB6A2D6),
  ];
}
