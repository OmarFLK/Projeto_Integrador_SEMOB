import 'package:flutter/material.dart';

abstract final class DesignTokens {
  static const radius = 22.0;
  static const rail = 76.0;
  static const sidebar = 264.0;
  static const quick = Duration(milliseconds: 180);
  static const navigation = Duration(milliseconds: 260);
  static const chart = Duration(milliseconds: 650);
  static const curve = Curves.easeOutCubic;
  static Duration motion(BuildContext context, [Duration duration = quick]) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
