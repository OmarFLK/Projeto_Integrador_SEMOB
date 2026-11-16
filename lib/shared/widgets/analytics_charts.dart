import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import 'forest_widgets.dart';
import 'viewport_entrance.dart';

class ChartSeries {
  const ChartSeries({
    required this.name,
    required this.values,
    required this.color,
  });
  final String name;
  final List<double> values;
  final Color color;
}

final _chartNumberFormat = NumberFormat.decimalPattern('pt_BR');
String chartNumber(double value) => _chartNumberFormat.format(value);
String compactChartNumber(double value) {
  if (value.abs() >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')} mi';
  }
  if (value.abs() >= 1000) {
    return '${(value / 1000).toStringAsFixed(value.abs() < 10000 ? 1 : 0).replaceAll('.', ',')} mil';
  }
  return chartNumber(value);
}

FlTitlesData chartTitles(
  BuildContext context,
  double maximum,
  List<String> labels,
) => FlTitlesData(
  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
  leftTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 52,
      interval: maximum / 4,
      getTitlesWidget: (v, m) => SideTitleWidget(
        meta: m,
        child: Text(
          compactChartNumber(v),
          style: TextStyle(color: context.palette.muted, fontSize: 10),
        ),
      ),
    ),
  ),
  bottomTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 30,
      interval: labels.length > 12 ? 5 : 1,
      getTitlesWidget: (v, m) {
        final index = v.round();
        if (index < 0 || index >= labels.length) return const SizedBox.shrink();
        return SideTitleWidget(
          meta: m,
          child: Text(
            labels[index],
            style: TextStyle(color: context.palette.muted, fontSize: 10),
          ),
        );
      },
    ),
  ),
);

List<FlSpot> chartSpots(List<double> values, List<String> labels) {
  final result = <FlSpot>[];
  for (var i = 0; i < values.length; i++) {
    if (i > 0 && i < labels.length) {
      final current = int.tryParse(labels[i]);
      final previous = int.tryParse(labels[i - 1]);
      if (current != null && previous != null && current > previous + 1) {
        result.add(FlSpot.nullSpot);
      }
    }
    result.add(
      values[i].isFinite ? FlSpot(i.toDouble(), values[i]) : FlSpot.nullSpot,
    );
  }
  return result;
}

double chartMaximum(Iterable<ChartSeries> series) {
  final values = series.expand((s) => s.values).where((v) => v.isFinite);
  return (values.isEmpty
          ? 1.0
          : values
                .reduce((a, b) => a > b ? a : b)
                .clamp(1, double.infinity)
                .toDouble()) *
      1.15;
}

double chartMinimum(Iterable<ChartSeries> series) {
  final values = series.expand((s) => s.values).where((v) => v.isFinite);
  if (values.isEmpty) return 0;
  final minimum = values.reduce((a, b) => a < b ? a : b);
  return minimum < 0 ? minimum * 1.15 : 0;
}

class AnalyticsLineChart extends StatefulWidget {
  const AnalyticsLineChart({
    super.key,
    required this.series,
    this.labels = const [],
    this.height = 250,
  });
  final List<ChartSeries> series;
  final List<String> labels;
  final double height;
  @override
  State<AnalyticsLineChart> createState() => _LineState();
}

class _LineState extends State<AnalyticsLineChart> {
  final hidden = <String>{};
  @override
  Widget build(BuildContext context) {
    final selected = widget.series
        .where((s) => !hidden.contains(s.name))
        .toList();
    final max = chartMaximum(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartLegend(
          series: widget.series,
          hidden: hidden,
          onToggle: (name) => setState(() {
            if (hidden.contains(name)) {
              hidden.remove(name);
            } else if (selected.length > 1) {
              hidden.add(name);
            }
          }),
        ),
        const SizedBox(height: 18),
        RepaintBoundary(
          child: SizedBox(
            height: widget.height,
            child: _ChartReveal(
              series: selected,
              labels: widget.labels,
              child: LineChart(
                duration: DesignTokens.motion(
                  context,
                  const Duration(milliseconds: 450),
                ),
                curve: DesignTokens.curve,
                LineChartData(
                  minY: chartMinimum(selected),
                  maxY: max,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: max / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: context.palette.line.withValues(alpha: .55),
                      strokeWidth: .7,
                      dashArray: [4, 5],
                    ),
                  ),
                  titlesData: chartTitles(context, max, widget.labels),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => context.palette.elevated,
                      tooltipBorder: BorderSide(color: context.palette.line),
                      tooltipBorderRadius: BorderRadius.circular(12),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (spots) => [
                        for (final spot in spots)
                          LineTooltipItem(
                            '${spot.x.round() < widget.labels.length ? widget.labels[spot.x.round()] : ''} · ${selected[spot.barIndex].name}\n${chartNumber(spot.y)}',
                            TextStyle(
                              color: selected[spot.barIndex].color,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  lineBarsData: [
                    for (final s in selected)
                      LineChartBarData(
                        spots: chartSpots(s.values, widget.labels),
                        color: s.color,
                        barWidth: 2.6,
                        isCurved: false,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              s.color.withValues(
                                alpha: selected.length == 1 ? .27 : .10,
                              ),
                              s.color.withValues(alpha: .005),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AnalyticsBarChart extends StatefulWidget {
  const AnalyticsBarChart({
    super.key,
    required this.series,
    required this.labels,
    this.height = 250,
  });
  final List<ChartSeries> series;
  final List<String> labels;
  final double height;
  @override
  State<AnalyticsBarChart> createState() => _BarState();
}

class _BarState extends State<AnalyticsBarChart> {
  final hidden = <String>{};
  @override
  Widget build(BuildContext context) {
    final selected = widget.series
        .where((s) => !hidden.contains(s.name))
        .toList();
    final max = chartMaximum(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartLegend(
          series: widget.series,
          hidden: hidden,
          onToggle: (name) => setState(() {
            if (hidden.contains(name)) {
              hidden.remove(name);
            } else if (selected.length > 1) {
              hidden.add(name);
            }
          }),
        ),
        const SizedBox(height: 18),
        RepaintBoundary(
          child: SizedBox(
            height: widget.height,
            child: _ChartReveal(
              effect: EntranceEffect.rise,
              series: selected,
              labels: widget.labels,
              child: BarChart(
                duration: DesignTokens.motion(
                  context,
                  const Duration(milliseconds: 450),
                ),
                curve: DesignTokens.curve,
                BarChartData(
                  minY: chartMinimum(selected),
                  maxY: max,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: max / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: context.palette.line.withValues(alpha: .55),
                      strokeWidth: .7,
                      dashArray: [4, 5],
                    ),
                  ),
                  titlesData: chartTitles(context, max, widget.labels),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => context.palette.elevated,
                      tooltipBorder: BorderSide(color: context.palette.line),
                      tooltipBorderRadius: BorderRadius.circular(12),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (group, index, rod, rodIndex) =>
                          BarTooltipItem(
                            '${widget.labels[group.x]} · ${selected[rodIndex].name}\n${chartNumber(rod.toY)}',
                            TextStyle(
                              color: context.palette.ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < widget.labels.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 3,
                        barRods: [
                          for (final s in selected)
                            if (i < s.values.length)
                              BarChartRodData(
                                toY: s.values[i],
                                width: selected.length > 1 ? 5 : 9,
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    s.color.withValues(alpha: .5),
                                    s.color,
                                  ],
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5),
                                ),
                              ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AnalyticsStackedBarChart extends StatelessWidget {
  const AnalyticsStackedBarChart({
    super.key,
    required this.series,
    required this.labels,
    this.height = 270,
  });
  final List<ChartSeries> series;
  final List<String> labels;
  final double height;
  @override
  Widget build(BuildContext context) {
    final totals = [
      for (var i = 0; i < labels.length; i++)
        series.fold<double>(
          0,
          (sum, s) => sum + (i < s.values.length ? s.values[i] : 0),
        ),
    ];
    final maximum = chartMaximum([
      ChartSeries(name: 'Total', values: totals, color: context.palette.green),
    ]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartLegend(series: series),
        const SizedBox(height: 18),
        RepaintBoundary(
          child: SizedBox(
            height: height,
            child: _ChartReveal(
              effect: EntranceEffect.rise,
              series: series,
              labels: labels,
              child: BarChart(
                duration: DesignTokens.motion(context, DesignTokens.chart),
                curve: DesignTokens.curve,
                BarChartData(
                  minY: 0,
                  maxY: maximum,
                  borderData: FlBorderData(show: false),
                  titlesData: chartTitles(context, maximum, labels),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maximum / 4,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: context.palette.line.withValues(alpha: .55),
                      strokeWidth: .7,
                      dashArray: [4, 5],
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => context.palette.elevated,
                      tooltipBorderRadius: BorderRadius.circular(12),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (group, index, rod, rodIndex) =>
                          BarTooltipItem(
                            'Dia ${labels[group.x]}\n${[for (final s in series) '${s.name}: ${chartNumber(s.values[group.x])}'].join('\n')}\nTotal: ${chartNumber(rod.toY)}',
                            TextStyle(
                              color: context.palette.ink,
                              fontSize: 11,
                              height: 1.7,
                            ),
                          ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < labels.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: totals[i],
                            width: 9,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                            rodStackItems: _stacks(i),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<BarChartRodStackItem> _stacks(int index) {
    var start = 0.0;
    final items = <BarChartRodStackItem>[];
    for (final s in series) {
      final end = start + (index < s.values.length ? s.values[index] : 0);
      items.add(BarChartRodStackItem(start, end, s.color));
      start = end;
    }
    return items;
  }
}

class DistributionDonut extends StatefulWidget {
  const DistributionDonut({
    super.key,
    required this.primary,
    required this.secondary,
    required this.primaryLabel,
    required this.secondaryLabel,
    this.height = 220,
  });
  final double primary, secondary, height;
  final String primaryLabel, secondaryLabel;
  @override
  State<DistributionDonut> createState() => _DonutState();
}

class _DonutState extends State<DistributionDonut> {
  int touched = -1;
  @override
  Widget build(BuildContext context) {
    final total = widget.primary + widget.secondary;
    if (total == 0) {
      return const SemobEmptyState(
        message: 'Nenhum passageiro registrado no período.',
        icon: Icons.donut_large_rounded,
      );
    }
    final values = [widget.primary, widget.secondary];
    final labels = [widget.primaryLabel, widget.secondaryLabel];
    final colors = [context.palette.green, context.palette.blue];
    final index = touched < 0 ? 0 : touched;
    final percentage = values[index] / total * 100;
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: ViewportEntrance(
            lazy: true,
            effect: EntranceEffect.ring,
            replayKey: Object.hash(widget.primary, widget.secondary),
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  duration: DesignTokens.motion(context, DesignTokens.chart),
                  curve: DesignTokens.curve,
                  PieChartData(
                    centerSpaceRadius: 62,
                    sectionsSpace: 5,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        final selected = event.isInterestedForInteractions
                            ? response?.touchedSection?.touchedSectionIndex ??
                                  -1
                            : -1;
                        if (selected != touched) {
                          setState(
                            () => touched = selected < 0 || selected > 1
                                ? -1
                                : selected,
                          );
                        }
                      },
                    ),
                    sections: [
                      for (var i = 0; i < 2; i++)
                        PieChartSectionData(
                          value: values[i],
                          color: colors[i],
                          radius: touched == i ? 28 : 21,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                IgnorePointer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SemobAnimatedCounter(
                        value:
                            '${percentage.toStringAsFixed(1).replaceAll('.', ',')}%',
                        style: TextStyle(
                          fontSize: 26,
                          letterSpacing: -1,
                          fontWeight: FontWeight.w700,
                          color: context.palette.ink,
                        ),
                      ),
                      Text(
                        labels[index],
                        style: TextStyle(
                          color: context.palette.muted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chartNumber(values[index]),
                        style: TextStyle(
                          color: context.palette.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _ChartLegend(
          series: [
            for (var i = 0; i < 2; i++)
              ChartSeries(
                name: labels[i],
                values: [values[i]],
                color: colors[i],
              ),
          ],
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({
    required this.series,
    this.hidden = const {},
    this.onToggle,
  });
  final List<ChartSeries> series;
  final Set<String> hidden;
  final ValueChanged<String>? onToggle;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: [
      for (final s in series)
        Semantics(
          toggled: !hidden.contains(s.name),
          child: Tooltip(
            message: onToggle == null ? s.name : 'Mostrar ou ocultar ${s.name}',
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onToggle == null ? null : () => onToggle!(s.name),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: hidden.contains(s.name)
                            ? context.palette.line
                            : s.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      s.name,
                      style: TextStyle(
                        color: context.palette.muted,
                        fontSize: 11,
                        decoration: hidden.contains(s.name)
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _ChartReveal extends StatelessWidget {
  const _ChartReveal({
    required this.child,
    required this.series,
    required this.labels,
    this.effect = EntranceEffect.draw,
  });
  final Widget child;
  final List<ChartSeries> series;
  final List<String> labels;
  final EntranceEffect effect;
  @override
  Widget build(BuildContext context) => _KeyboardChart(
    series: series,
    labels: labels,
    child: ViewportEntrance(
      lazy: true,
      effect: effect,
      replayKey: Object.hash(
        Object.hashAll(labels),
        Object.hashAll([
          for (final s in series) Object.hash(s.name, Object.hashAll(s.values)),
        ]),
      ),
      child: child,
    ),
  );
}

class _KeyboardChart extends StatefulWidget {
  const _KeyboardChart({
    required this.child,
    required this.series,
    required this.labels,
  });
  final Widget child;
  final List<ChartSeries> series;
  final List<String> labels;
  @override
  State<_KeyboardChart> createState() => _KeyboardChartState();
}

class _KeyboardChartState extends State<_KeyboardChart> {
  bool focused = false;
  int index = 0;
  @override
  Widget build(BuildContext context) {
    if (widget.labels.isEmpty) return widget.child;
    final current = index.clamp(0, widget.labels.length - 1);
    final description =
        '${widget.labels[current]} · ${[for (final s in widget.series)
          if (current < s.values.length) '${s.name}: ${chartNumber(s.values[current])}'].join(' · ')}';
    return Focus(
      key: const Key('keyboard_chart'),
      onFocusChange: (v) => setState(() => focused = v),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          node.unfocus();
          return KeyEventResult.handled;
        }
        final direction = event.logicalKey == LogicalKeyboardKey.arrowRight
            ? 1
            : event.logicalKey == LogicalKeyboardKey.arrowLeft
            ? -1
            : 0;
        if (direction == 0) return KeyEventResult.ignored;
        setState(
          () =>
              index = (current + direction).clamp(0, widget.labels.length - 1),
        );
        return KeyEventResult.handled;
      },
      child: Semantics(
        key: const Key('chart_semantics'),
        label: 'Gráfico interativo. Use as setas para explorar os registros.',
        value: focused ? description : '${widget.labels.length} registros',
        liveRegion: focused,
        child: Stack(
          children: [
            widget.child,
            if (focused)
              Positioned(
                left: 54,
                right: 4,
                top: 4,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.palette.elevated,
                      border: Border.all(color: context.palette.green),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      description,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.palette.ink,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
