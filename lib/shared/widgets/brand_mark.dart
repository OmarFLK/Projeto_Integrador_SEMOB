import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.onDark = false, this.compact = false});

  final bool onDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = onDark ? AppColors.white : AppColors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/semob_logo.png',
            fit: BoxFit.cover,
            width: compact ? 38 : 46,
            height: compact ? 38 : 46,
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SEMOB',
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 0,
                ),
              ),
              Text(
                'SÃO CAETANO DO SUL',
                style: TextStyle(
                  color: onDark ? Colors.white70 : AppColors.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 8,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
