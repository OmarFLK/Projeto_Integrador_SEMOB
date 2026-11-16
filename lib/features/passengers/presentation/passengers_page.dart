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
        if (activeModuleView(context) == 'overview') ...[
          SemobHeroPanel(
            eyebrow: 'Passageiros / Demanda',
            title: 'Pessoas que movem a cidade.',
            description:
                '${Formatters.integer(total)} passageiros registrados no período. Explore a composição e a evolução diária da bilhetagem.',
          ),
          const SizedBox(height: 20),
        ],
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
        if (activeModuleView(context) != 'evolution')
          SectionCard(
            title: 'Passageiros por dia',
            subtitle:
                'Composição empilhada entre catraca, antecipados e não pagantes',
            child: _StackedPassengerChart(data: data),
          ),
        const SizedBox(height: 12),
        if (activeModuleView(context) != 'composition')
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
                    color: context.palette.graphite,
                  ),
                  ChartSeries(
                    name: 'Pagantes',
                    values: data.map((item) => item.paying.toDouble()).toList(),
                    color: context.palette.green,
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
  Widget build(BuildContext context) => AnalyticsStackedBarChart(
    labels: data.map((d) => '${d.day}').toList(),
    series: [
      ChartSeries(
        name: 'Catraca',
        values: data.map((d) => d.turnstile.toDouble()).toList(),
        color: context.palette.green,
      ),
      ChartSeries(
        name: 'Antecipados',
        values: data.map((d) => d.advance.toDouble()).toList(),
        color: context.palette.blue,
      ),
      ChartSeries(
        name: 'Não pagantes',
        values: data.map((d) => d.nonPaying.toDouble()).toList(),
        color: context.palette.amber,
      ),
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
        color: muted ? context.palette.canvas : context.palette.greenLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: muted ? context.palette.muted : context.palette.green,
            size: 22,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: context.palette.muted, fontSize: 11),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: context.palette.ink,
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
