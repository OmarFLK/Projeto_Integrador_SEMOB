import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transport_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/analytics_charts.dart';
import '../../../shared/widgets/global_filter_bar.dart';
import '../../../shared/widgets/coverage_notice.dart';
import '../../../shared/widgets/page_components.dart';

class PassengersPage extends ConsumerWidget {
  const PassengersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passengers = ref.watch(passengersProvider);
    return PageBody(
      children: [
        PageHeader(
          title: 'Passageiros',
          subtitle: 'Demanda, categorias de bilhetagem e evolução diária',
          action: const GlobalFilterBar(),
        ),
        const SizedBox(height: 16),
        const CoverageNotice(),
        const SizedBox(height: 16),
        AsyncContent<PassengerDay>(
          value: passengers,
          builder: (data) => _PassengersContent(data: data),
        ),
      ],
    );
  }
}

class _PassengersContent extends StatelessWidget {
  const _PassengersContent({required this.data});

  final List<PassengerDay> data;

  @override
  Widget build(BuildContext context) {
    final turnstile = data.fold<int>(0, (sum, item) => sum + item.turnstile);
    final advance = data.fold<int>(0, (sum, item) => sum + item.advance);
    final nonPaying = data.fold<int>(0, (sum, item) => sum + item.nonPaying);
    final total = data.fold<int>(0, (sum, item) => sum + item.total);
    final peak = data.reduce((a, b) => a.total > b.total ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetricsGrid(
          children: [
            MetricCard(
              label: 'Total de passageiros',
              value: Formatters.integer(total),
              icon: Icons.groups_2_outlined,
              helper: 'Total do período selecionado',
            ),
            MetricCard(
              label: 'Catraca',
              value: Formatters.integer(turnstile),
              icon: Icons.sensor_door_outlined,
              helper: 'do total',
            ),
            MetricCard(
              label: 'Antecipados',
              value: Formatters.integer(advance),
              icon: Icons.credit_card_outlined,
              helper: 'do total',
            ),
            MetricCard(
              label: 'Não pagantes',
              value: Formatters.integer(nonPaying),
              icon: Icons.accessible_forward_outlined,
              positive: false,
              helper: 'do total provisório',
            ),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Passageiros por dia',
          subtitle:
              'Composição empilhada entre catraca, antecipados e não pagantes',
          child: _StackedPassengerChart(data: data),
        ),
        const SizedBox(height: 12),
        TwoColumnLayout(
          leftFlex: 2,
          rightFlex: 1,
          left: SectionCard(
            title: 'Evolução no período',
            subtitle: 'Total diário e passageiros pagantes',
            child: AnalyticsLineChart(
              labels: data.map((item) => '${item.day}').toList(),
              series: [
                ChartSeries(
                  name: 'Total',
                  values: data.map((item) => item.total.toDouble()).toList(),
                  color: AppColors.graphite,
                ),
                ChartSeries(
                  name: 'Pagantes',
                  values: data.map((item) => item.paying.toDouble()).toList(),
                  color: AppColors.green,
                ),
              ],
            ),
          ),
          right: SectionCard(
            title: 'Destaques de demanda',
            subtitle: 'Leitura do mês analisado',
            child: Column(
              children: [
                _DemandHighlight(
                  icon: Icons.trending_up_rounded,
                  title: 'Maior demanda',
                  value:
                      '${peak.day.toString().padLeft(2, '0')} • ${Formatters.integer(peak.total)} passageiros',
                ),
                const SizedBox(height: 10),
                _DemandHighlight(
                  icon: Icons.percent_rounded,
                  title: 'Não pagantes',
                  value:
                      '${Formatters.percent(total == 0 ? 0 : nonPaying / total * 100)} do total',
                ),
                const SizedBox(height: 10),
                const _DemandHighlight(
                  icon: Icons.schedule_outlined,
                  title: 'Horário de maior demanda',
                  value: 'Não disponível na fonte de passageiros',
                  muted: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StackedPassengerChart extends StatelessWidget {
  const _StackedPassengerChart({required this.data});

  final List<PassengerDay> data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Wrap(
          spacing: 16,
          children: [
            _Legend(color: AppColors.green, label: 'Catraca'),
            _Legend(color: AppColors.blue, label: 'Antecipados'),
            _Legend(color: AppColors.amber, label: 'Não pagantes'),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 270,
          child: BarChart(
            BarChartData(
              maxY:
                  data.fold<double>(
                    1,
                    (m, r) => r.total > m ? r.total.toDouble() : m,
                  ) *
                  1.1,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 13000,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: AppColors.line, strokeWidth: .8),
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
                    reservedSize: 44,
                    interval: 13000,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        '${(value / 1000).round()} mil',
                        style: const TextStyle(
                          color: AppColors.muted,
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
                    interval: 5,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= data.length) {
                        return const SizedBox();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          '${data[index].day}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < data.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: data[i].total.toDouble(),
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2),
                        ),
                        rodStackItems: [
                          BarChartRodStackItem(
                            0,
                            data[i].turnstile.toDouble(),
                            AppColors.green,
                          ),
                          BarChartRodStackItem(
                            data[i].turnstile.toDouble(),
                            data[i].paying.toDouble(),
                            AppColors.blue,
                          ),
                          BarChartRodStackItem(
                            data[i].paying.toDouble(),
                            data[i].total.toDouble(),
                            AppColors.amber,
                          ),
                        ],
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

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
    ],
  );
}

class _DemandHighlight extends StatelessWidget {
  const _DemandHighlight({
    required this.icon,
    required this.title,
    required this.value,
    this.muted = false,
  });
  final IconData icon;
  final String title;
  final String value;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: muted ? AppColors.canvas : AppColors.greenLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: muted ? AppColors.muted : AppColors.green,
            size: 22,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
