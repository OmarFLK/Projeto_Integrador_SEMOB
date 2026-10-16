import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

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

class AnalyticsLineChart extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final allValues = series.expand((item) => item.values);
    final maximum = allValues.isEmpty
        ? 1.0
        : allValues
                  .reduce((a, b) => a > b ? a : b)
                  .clamp(1.0, double.infinity) *
              1.12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartLegend(series: series),
        const SizedBox(height: 16),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maximum,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maximum / 4,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: context.palette.line, strokeWidth: 0.8),
              ),
              titlesData: _titles(context, maximum),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.graphite,
                ),
              ),
              lineBarsData: series
                  .map(
                    (item) => LineChartBarData(
                      spots: [
                        for (var i = 0; i < item.values.length; i++)
                          FlSpot(i.toDouble(), item.values[i]),
                      ],
                      color: item.color,
                      barWidth: 2.2,
                      isCurved: true,
                      curveSmoothness: 0.2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: series.length == 1,
                        color: item.color.withValues(alpha: 0.08),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  FlTitlesData _titles(BuildContext context, double maximum) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          interval: maximum / 4,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            meta: meta,
            child: Text(
              _compact(value),
              style: TextStyle(color: context.palette.muted, fontSize: 10),
            ),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: labels.length > 10 ? 5 : 1,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            if (index < 0 || index >= labels.length) return const SizedBox();
            return SideTitleWidget(
              meta: meta,
              child: Text(
                labels[index],
                style: TextStyle(color: context.palette.muted, fontSize: 10),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AnalyticsBarChart extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final allValues = series.expand((item) => item.values);
    final maximum = allValues.isEmpty
        ? 1.0
        : allValues
                  .reduce((a, b) => a > b ? a : b)
                  .clamp(1.0, double.infinity) *
              1.15;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartLegend(series: series),
        const SizedBox(height: 16),
        SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              maxY: maximum,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: maximum / 4,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: context.palette.line, strokeWidth: 0.8),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: maximum / 4,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        _compact(value),
                        style: TextStyle(
                          color: context.palette.muted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: labels.length > 12 ? 5 : 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= labels.length) {
                        return const SizedBox();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          labels[index],
                          style: TextStyle(
                            color: context.palette.muted,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < labels.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 2,
                    barRods: [
                      for (final item in series)
                        BarChartRodData(
                          toY: i < item.values.length ? item.values[i] : 0,
                          color: item.color,
                          width: series.length > 1 ? 5 : 10,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DistributionDonut extends StatelessWidget {
  const DistributionDonut({
    super.key,
    required this.primary,
    required this.secondary,
    required this.primaryLabel,
    required this.secondaryLabel,
    this.height = 220,
  });

  final double primary;
  final double secondary;
  final String primaryLabel;
  final String secondaryLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = primary + secondary;
    final percentage = total == 0 ? 0 : primary / total * 100;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  centerSpaceRadius: 58,
                  sectionsSpace: 3,
                  startDegreeOffset: -90,
                  sections: [
                    PieChartSectionData(
                      value: primary,
                      color: context.palette.green,
                      radius: 20,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: secondary,
                      color: context.palette.amber,
                      radius: 20,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${percentage.toStringAsFixed(1).replaceAll('.', ',')}%',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: context.palette.ink,
                    ),
                  ),
                  Text(
                    primaryLabel,
                    style: TextStyle(
                      color: context.palette.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _ChartLegend(
          series: [
            ChartSeries(
              name: primaryLabel,
              values: const [],
              color: context.palette.green,
            ),
            ChartSeries(
              name: secondaryLabel,
              values: const [],
              color: context.palette.amber,
            ),
          ],
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.series});

  final List<ChartSeries> series;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: series
          .map(
            (item) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.name,
                  style: TextStyle(color: context.palette.muted, fontSize: 11),
                ),
              ],
            ),
          )
          .toList(),
    );
  }
}

String _compact(double value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)} mi';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)} mil';
  return value.toStringAsFixed(0);
}
