import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.onDark = false, this.compact = false});
  final bool onDark, compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: compact ? 40 : 50,
        height: compact ? 40 : 50,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0FAF3), Color(0xFFCCEBD9)],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Image.asset('assets/images/semob_logo.png', fit: BoxFit.contain),
      ),
      if (!compact) ...[
        const SizedBox(width: 14),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SEMOB',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onDark ? Colors.white : context.palette.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 21,
                  height: 1.1,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'São Caetano do Sul',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onDark
                      ? const Color(0xFFB9CEC1)
                      : context.palette.muted,
                  fontSize: 10,
                  height: 1.2,
                  letterSpacing: .2,
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
