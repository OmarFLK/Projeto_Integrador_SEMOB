import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_tokens.dart';

class SemobPageTransition extends StatelessWidget {
  const SemobPageTransition({super.key, required this.child, this.order = 0});
  final Widget child;
  final int order;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: DesignTokens.motion(
      context,
      Duration(milliseconds: 360 + order.clamp(0, 7) * 40),
    ),
    curve: Interval((order * .05).clamp(0, .35), 1, curve: DesignTokens.curve),
    builder: (_, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - value)),
        child: child,
      ),
    ),
    child: child,
  );
}

class SemobGlassCard extends StatefulWidget {
  const SemobGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.highlight = false,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final bool highlight;
  final VoidCallback? onTap;
  @override
  State<SemobGlassCard> createState() => _GlassState();
}

class _GlassState extends State<SemobGlassCard> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedContainer(
        duration: DesignTokens.motion(context),
        curve: DesignTokens.curve,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignTokens.radius),
          border: Border.all(
            color: widget.highlight
                ? p.green.withValues(alpha: .4)
                : p.line.withValues(alpha: hovered ? 1 : .65),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [widget.highlight ? p.greenLight : p.elevated, p.surface],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: p.isDark ? .13 : .035),
              blurRadius: hovered ? 24 : 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(DesignTokens.radius),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(DesignTokens.radius),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

class SemobHeroPanel extends StatelessWidget {
  const SemobHeroPanel({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.trailing,
    this.image = false,
  });
  final String eyebrow, title, description;
  final Widget? trailing;
  final bool image;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(26),
    child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest, AppColors.forestBlack],
        ),
      ),
      child: Stack(
        children: [
          if (image)
            Positioned.fill(
              child: Opacity(
                opacity: .14,
                child: Image.asset(
                  'assets/images/login_bus.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
              ),
            ),
          Positioned(
            right: -65,
            top: -100,
            child: Container(
              width: 290,
              height: 290,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.lime.withValues(alpha: .16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: LayoutBuilder(
              builder: (context, c) {
                final text = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.lime,
                        fontSize: 10,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.ivory,
                        fontSize: c.maxWidth < 500 ? 25 : 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.1,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.softSage,
                        fontSize: 12,
                        height: 1.7,
                      ),
                    ),
                  ],
                );
                if (trailing == null) return text;
                if (c.maxWidth < 500) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [text, const SizedBox(height: 20), trailing!],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: 24),
                    trailing!,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class SemobAnimatedCounter extends StatelessWidget {
  const SemobAnimatedCounter({
    super.key,
    required this.value,
    required this.style,
  });
  final String value;
  final TextStyle style;
  @override
  Widget build(BuildContext context) {
    final match = RegExp(
      r'^(R\$\s*)?([\d.]+(?:,\d+)?)(\s*(?:%|km))?$',
    ).firstMatch(value);
    if (match == null) return Text(value, style: style);
    final number = double.tryParse(
      match[2]!.replaceAll('.', '').replaceAll(',', '.'),
    );
    if (number == null) return Text(value, style: style);
    final decimals = match[2]!.contains(',')
        ? match[2]!.split(',').last.length
        : 0;
    return Semantics(
      label: value,
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: number),
          duration: DesignTokens.motion(context, DesignTokens.chart),
          curve: DesignTokens.curve,
          builder: (_, n, _) {
            final parts = n.toStringAsFixed(decimals).split('.');
            final integer = parts[0].replaceAllMapped(
              RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
              (m) => '${m[1]}.',
            );
            return Text(
              '${match[1] ?? ''}$integer${decimals > 0 ? ',${parts[1]}' : ''}${match[3] ?? ''}',
              style: style,
            );
          },
        ),
      ),
    );
  }
}

class SemobLoadingSkeleton extends StatelessWidget {
  const SemobLoadingSkeleton({super.key, this.height = 220, this.lines = 3});
  final double height;
  final int lines;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Carregando dados',
    child: ExcludeSemantics(
      child: Container(
        height: height,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < lines; i++) ...[
              FractionallySizedBox(
                widthFactor: i == 0 ? .45 : .9 - i * .1,
                child: Container(
                  height: i == 0 ? 18 : 12,
                  decoration: BoxDecoration(
                    color: context.palette.line.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      context.palette.greenLight.withValues(alpha: .15),
                      context.palette.greenLight.withValues(alpha: .55),
                    ],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SemobEmptyState extends StatelessWidget {
  const SemobEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.search_off_rounded,
    this.action,
  });
  final String message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: context.palette.muted, size: 34),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.muted, height: 1.6),
        ),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    ),
  );
}

class FrostedPanel extends StatelessWidget {
  const FrostedPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        decoration: BoxDecoration(
          color: context.palette.surface.withValues(alpha: .95),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.palette.line),
        ),
        child: child,
      ),
    ),
  );
}
