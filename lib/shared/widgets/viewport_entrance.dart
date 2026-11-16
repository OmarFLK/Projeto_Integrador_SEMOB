import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

enum EntranceEffect { paper, draw, rise, ring }

/// Starts once the widget enters its scroll viewport. No polling or idle ticker.
/// A changed data key permits another entrance; ordinary rebuilds do not.
class ViewportEntrance extends StatefulWidget {
  const ViewportEntrance({
    super.key,
    required this.child,
    this.effect = EntranceEffect.paper,
    this.order = 0,
    this.replayKey,
    this.lazy = false,
  });
  final Widget child;
  final EntranceEffect effect;
  final int order;
  final Object? replayKey;
  final bool lazy;

  @override
  State<ViewportEntrance> createState() => _ViewportEntranceState();
}

class _ViewportEntranceState extends State<ViewportEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(vsync: this);
  ScrollPosition? position;
  bool started = false, scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller.duration = DesignTokens.motion(
      context,
      Duration(milliseconds: 740 + widget.order.clamp(0, 7) * 65),
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      started = true;
      controller.value = 1;
      _detach();
    } else if (!started) {
      _listen();
    }
  }

  @override
  void didUpdateWidget(covariant ViewportEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replayKey != widget.replayKey &&
        !MediaQuery.disableAnimationsOf(context)) {
      started = false;
      controller.reset();
      _listen();
    }
  }

  void _listen() {
    _detach();
    position = Scrollable.maybeOf(context)?.position;
    position?.addListener(_schedule);
    _schedule();
  }

  void _detach() {
    position?.removeListener(_schedule);
    position = null;
  }

  void _schedule() {
    if (scheduled || started) return;
    scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduled = false;
      if (!mounted || started) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      final scroll = Scrollable.maybeOf(context)?.context.findRenderObject();
      final viewport = scroll is RenderBox && scroll.hasSize
          ? scroll.localToGlobal(Offset.zero) & scroll.size
          : Offset.zero & MediaQuery.sizeOf(context);
      // Require a visible portion, rather than consuming the animation below fold.
      final visible = rect.intersect(viewport);
      if (visible.width > 0 && visible.height >= rect.height.clamp(1, 48)) {
        _detach();
        setState(() => started = true);
        controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _detach();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: RepaintBoundary(
      child: widget.lazy && !started ? const SizedBox.expand() : widget.child,
    ),
    builder: (context, child) {
      final value = Interval(
        widget.order.clamp(0, 7) * .045,
        1,
        curve: Curves.easeOutCubic,
      ).transform(controller.value);
      if (value == 1) return child!;
      return switch (widget.effect) {
        EntranceEffect.paper => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, -32 * (1 - value)),
            child: Transform(
              alignment: Alignment.topCenter,
              transform: Matrix4.identity()
                ..setEntry(3, 2, .001)
                ..rotateX(-.24 * (1 - value)),
              child: child,
            ),
          ),
        ),
        EntranceEffect.draw || EntranceEffect.rise => ClipRect(
          clipper: _EntranceClipper(
            value,
            widget.effect == EntranceEffect.rise,
          ),
          child: child,
        ),
        EntranceEffect.ring => Opacity(
          opacity: value,
          child: Transform.rotate(
            angle: -.32 * (1 - value),
            child: Transform.scale(scale: .84 + .16 * value, child: child),
          ),
        ),
      };
    },
  );
}

class _EntranceClipper extends CustomClipper<Rect> {
  const _EntranceClipper(this.progress, this.vertical);
  final double progress;
  final bool vertical;
  @override
  Rect getClip(Size size) => vertical
      ? Rect.fromLTRB(
          -8,
          size.height * (1 - progress) - 12,
          size.width + 8,
          size.height + 12,
        )
      : Rect.fromLTRB(-8, -12, size.width * progress + 8, size.height + 12);
  @override
  bool shouldReclip(_EntranceClipper oldClipper) =>
      progress != oldClipper.progress || vertical != oldClipper.vertical;
}
