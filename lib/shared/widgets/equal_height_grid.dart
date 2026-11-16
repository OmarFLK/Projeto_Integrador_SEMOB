import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Equalizes natural content heights without intrinsic layout (charts and
/// LayoutBuilder cannot be measured with IntrinsicHeight). Widths stay responsive.
class EqualHeightGrid extends MultiChildRenderObjectWidget {
  const EqualHeightGrid({
    super.key,
    required super.children,
    this.columns = 2,
    this.gap = 16,
    this.weights = const [],
  }) : assert(columns > 0),
       assert(weights.length == 0 || weights.length == columns);
  final int columns;
  final double gap;
  final List<int> weights;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderEqualHeightGrid(columns, gap, weights, Directionality.of(context));
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderEqualHeightGrid).update(
      columns,
      gap,
      weights,
      Directionality.of(context),
    );
  }
}

class _CellData extends ContainerBoxParentData<RenderBox> {}

class _RenderEqualHeightGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _CellData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _CellData> {
  _RenderEqualHeightGrid(this.columns, this.gap, this.weights, this.direction);
  int columns;
  double gap;
  List<int> weights;
  TextDirection direction;

  void update(
    int count,
    double spacing,
    List<int> flex,
    TextDirection textDirection,
  ) {
    if (columns == count &&
        gap == spacing &&
        direction == textDirection &&
        _sameWeights(flex)) {
      return;
    }
    columns = count;
    gap = spacing;
    weights = flex;
    direction = textDirection;
    markNeedsLayout();
  }

  bool _sameWeights(List<int> other) =>
      weights.length == other.length &&
      List.generate(
        weights.length,
        (i) => i,
      ).every((i) => weights[i] == other[i]);

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CellData) child.parentData = _CellData();
  }

  @override
  void performLayout() {
    assert(
      constraints.hasBoundedWidth,
      'EqualHeightGrid needs a bounded width.',
    );
    final width = constraints.maxWidth;
    if (childCount == 0) {
      size = constraints.constrain(Size(width, 0));
      return;
    }
    final available = math.max(0.0, width - gap * (columns - 1));
    final totalWeight = weights.isEmpty
        ? columns
        : weights.fold(0, (a, b) => a + b);
    final widths = [
      for (var i = 0; i < columns; i++)
        available * (weights.isEmpty ? 1 : weights[i]) / totalWeight,
    ];
    var height = 0.0;
    var index = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints.tightFor(width: widths[index % columns]),
        parentUsesSize: true,
      );
      height = math.max(height, child.size.height);
      child = (child.parentData! as _CellData).nextSibling;
      index++;
    }
    child = firstChild;
    index = 0;
    var x = 0.0;
    while (child != null) {
      final column = index % columns;
      if (column == 0) x = 0;
      child.layout(
        // Keep height unbounded above so later text/form/animation changes
        // propagate layout back to this grid, instead of becoming a tight
        // relayout boundary with an obsolete measured height.
        BoxConstraints(
          minWidth: widths[column],
          maxWidth: widths[column],
          minHeight: height,
        ),
        parentUsesSize: true,
      );
      final data = child.parentData! as _CellData;
      data.offset = Offset(
        direction == TextDirection.ltr ? x : width - x - widths[column],
        (index ~/ columns) * (height + gap),
      );
      x += widths[column] + gap;
      child = data.nextSibling;
      index++;
    }
    final rows = (childCount / columns).ceil();
    size = constraints.constrain(Size(width, height * rows + gap * (rows - 1)));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
