import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transport_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/analytics_charts.dart';
import '../../../shared/widgets/global_filter_bar.dart';
import '../../../shared/widgets/page_components.dart';

class OperationPage extends ConsumerWidget {
  const OperationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(operationProvider);
    return PageBody(
      children: [
        PageHeader(
          title: 'Operação',
          subtitle: 'Cumprimento de viagens, frota empregada e quilometragem',
          action: const GlobalFilterBar(),
        ),
        const SizedBox(height: 16),
        const DataSourceNote(),
        const SizedBox(height: 16),
        AsyncContent<OperationDay>(
          value: asyncData,
          builder: (days) => _OperationContent(days: days),
        ),
      ],
    );
  }
}

class _OperationContent extends StatelessWidget {
  const _OperationContent({required this.days});

  final List<OperationDay> days;

  @override
  Widget build(BuildContext context) {
    final vehicles = days
        .map((item) => item.vehicles)
        .reduce((a, b) => a > b ? a : b);
    final scheduled = days.fold<int>(
      0,
      (sum, item) => sum + item.scheduledTrips,
    );
    final completed = days.fold<int>(
      0,
      (sum, item) => sum + item.completedTrips,
    );
    final productive = days.fold<double>(
      0,
      (sum, item) => sum + item.productiveKm,
    );
    final unproductive = days.fold<double>(
      0,
      (sum, item) => sum + item.unproductiveKm,
    );
    final divergent = days.where((item) => item.tripDifference > 0).toList()
      ..sort((a, b) => b.tripDifference.compareTo(a.tripDifference));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetricsGrid(
          children: [
            MetricCard(
              label: 'Veículos em operação',
              value: '$vehicles',
              icon: Icons.directions_bus_outlined,
              helper: 'Maior valor diário',
            ),
            MetricCard(
              label: 'Viagens programadas',
              value: Formatters.integer(scheduled),
              icon: Icons.event_note_outlined,
            ),
            MetricCard(
              label: 'Viagens realizadas',
              value: Formatters.integer(completed),
              icon: Icons.task_alt_rounded,
            ),
            MetricCard(
              label: 'Não realizadas',
              value: Formatters.integer(scheduled - completed),
              icon: Icons.event_busy_outlined,
              change: '0,16%',
              positive: false,
            ),
            MetricCard(
              label: 'Taxa de cumprimento',
              value: Formatters.percent(
                completed / scheduled * 100,
                decimals: 2,
              ),
              icon: Icons.speed_rounded,
            ),
            MetricCard(
              label: 'Km produtivo',
              value: '${Formatters.decimal(productive)} km',
              icon: Icons.timeline_rounded,
            ),
            MetricCard(
              label: 'Km improdutivo',
              value: '${Formatters.decimal(unproductive)} km',
              icon: Icons.route_outlined,
              helper: '5,01% do total',
            ),
            MetricCard(
              label: 'Km total',
              value: '${Formatters.decimal(productive + unproductive)} km',
              icon: Icons.map_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        TwoColumnLayout(
          left: SectionCard(
            title: 'Programadas x realizadas por dia',
            subtitle: 'Dias com diferença são destacados na lista de atenção',
            child: AnalyticsBarChart(
              labels: days.map((item) => '${item.day}').toList(),
              series: [
                ChartSeries(
                  name: 'Programadas',
                  values: days
                      .map((item) => item.scheduledTrips.toDouble())
                      .toList(),
                  color: AppColors.graphite,
                ),
                ChartSeries(
                  name: 'Realizadas',
                  values: days
                      .map((item) => item.completedTrips.toDouble())
                      .toList(),
                  color: AppColors.green,
                ),
              ],
            ),
          ),
          right: SectionCard(
            title: 'Veículos utilizados por dia',
            subtitle: 'Quantidade de prefixos registrados na operação',
            child: AnalyticsLineChart(
              labels: days.map((item) => '${item.day}').toList(),
              series: [
                ChartSeries(
                  name: 'Veículos',
                  values: days.map((item) => item.vehicles.toDouble()).toList(),
                  color: AppColors.blue,
                ),
                ChartSeries(
                  name: 'Máx. por faixa',
                  values: days
                      .map((item) => item.maxVehiclesInRange.toDouble())
                      .toList(),
                  color: AppColors.green,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TwoColumnLayout(
          leftFlex: 2,
          rightFlex: 1,
          left: SectionCard(
            title: 'Quilometragem por dia',
            subtitle: 'Produtiva, improdutiva e total',
            child: AnalyticsLineChart(
              labels: days.map((item) => '${item.day}').toList(),
              series: [
                ChartSeries(
                  name: 'Produtiva',
                  values: days.map((item) => item.productiveKm).toList(),
                  color: AppColors.green,
                ),
                ChartSeries(
                  name: 'Improdutiva',
                  values: days.map((item) => item.unproductiveKm).toList(),
                  color: AppColors.amber,
                ),
                ChartSeries(
                  name: 'Total',
                  values: days.map((item) => item.totalKm).toList(),
                  color: AppColors.graphite,
                ),
              ],
            ),
          ),
          right: SectionCard(
            title: 'Dias que exigem atenção',
            subtitle: '${divergent.length} dias com diferença de viagens',
            trailing: IconButton(
              tooltip: 'Abrir anomalias',
              onPressed: () => context.go('/anomalies'),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
            ),
            child: Column(
              children: divergent
                  .take(7)
                  .map(
                    (day) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: day.tripDifference >= 7
                            ? AppColors.redSoft
                            : AppColors.amberSoft,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: day.tripDifference >= 7
                                ? AppColors.red
                                : AppColors.amber,
                            size: 19,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              '${day.day.toString().padLeft(2, '0')}/08 • ${day.weekday}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            '${day.tripDifference} viagens',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/trips'),
            icon: const Icon(Icons.alt_route_rounded, size: 18),
            label: const Text('Abrir viagens detalhadas'),
          ),
        ),
      ],
    );
  }
}
