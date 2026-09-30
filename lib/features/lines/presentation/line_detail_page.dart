import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transport_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/analytics_charts.dart';
import '../../../shared/widgets/page_components.dart';

class LineDetailPage extends ConsumerWidget {
  const LineDetailPage({super.key, required this.lineCode});
  final String lineCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(linesProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final trips = ref.watch(tripsProvider);
    return PageBody(
      children: [
        PageHeader(
          title: 'Linha $lineCode',
          subtitle: 'Detalhes operacionais e registros relacionados',
          action: OutlinedButton.icon(
            onPressed: () => context.go('/lines'),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Voltar às linhas'),
          ),
        ),
        const SizedBox(height: 16),
        const DataSourceNote(),
        const SizedBox(height: 16),
        lines.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('Erro ao carregar: $error'),
          data: (items) {
            final line = items
                .where((item) => item.code == lineCode)
                .firstOrNull;
            if (line == null) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Linha não encontrada.'),
                ),
              );
            }
            final relatedVehicles =
                vehicles.value
                    ?.where((item) => item.lines.contains(lineCode))
                    .toList() ??
                const <VehicleSummary>[];
            final relatedTrips =
                trips.value?.where((item) => item.line == lineCode).toList() ??
                const <TripRecord>[];
            return _LineDetailContent(
              line: line,
              allLines: items,
              vehicles: relatedVehicles,
              trips: relatedTrips,
            );
          },
        ),
      ],
    );
  }
}

class _LineDetailContent extends StatelessWidget {
  const _LineDetailContent({
    required this.line,
    required this.allLines,
    required this.vehicles,
    required this.trips,
  });
  final LineSummary line;
  final List<LineSummary> allLines;
  final List<VehicleSummary> vehicles;
  final List<TripRecord> trips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetricsGrid(
          children: [
            MetricCard(
              label: 'Viagens',
              value: Formatters.integer(line.trips),
              icon: Icons.alt_route_rounded,
            ),
            MetricCard(
              label: 'Quilometragem',
              value: '${Formatters.decimal(line.totalKm)} km',
              icon: Icons.route_outlined,
            ),
            MetricCard(
              label: 'Desempenho',
              value: Formatters.percent(line.performance),
              icon: Icons.speed_rounded,
            ),
            MetricCard(
              label: 'Passageiros',
              value: 'Não disponível',
              icon: Icons.groups_2_outlined,
              helper: 'Fonte não segmentada por linha',
            ),
          ],
        ),
        const SizedBox(height: 12),
        TwoColumnLayout(
          leftFlex: 2,
          rightFlex: 1,
          left: SectionCard(
            title: 'Comparativo com a rede',
            subtitle: 'Viagens consolidadas por linha no mês',
            child: AnalyticsBarChart(
              labels: allLines.map((item) => item.code).toList(),
              series: [
                ChartSeries(
                  name: 'Viagens',
                  values: allLines
                      .map((item) => item.trips.toDouble())
                      .toList(),
                  color: AppColors.green,
                ),
              ],
            ),
          ),
          right: SectionCard(
            title: 'Veículos utilizados',
            subtitle: 'Prefixos identificados na amostra consolidada',
            child: vehicles.isEmpty
                ? const _Unavailable(text: 'Sem prefixos na amostra reduzida.')
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: vehicles
                        .map((item) => Chip(label: Text(item.prefix)))
                        .toList(),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TwoColumnLayout(
          left: SectionCard(
            title: 'Viagens da amostra',
            subtitle: 'Sentido, faixa horária e horários realizados',
            child: trips.isEmpty
                ? const _Unavailable(
                    text: 'Sem viagens desta linha na amostra reduzida.',
                  )
                : Column(
                    children: trips
                        .take(5)
                        .map(
                          (trip) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.route_outlined,
                              color: AppColors.green,
                            ),
                            title: Text('${trip.date} • ${trip.direction}'),
                            subtitle: Text(
                              '${trip.timeRange} • ${trip.start} → ${trip.end}',
                            ),
                            trailing: StatusBadge(
                              label: trip.status.label,
                              kind: tripStatusKind(trip.status),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          right: const SectionCard(
            title: 'Evolução e passageiros',
            subtitle: 'Componente preparado para a API analítica',
            child: _Unavailable(
              text:
                  'A fonte atual não relaciona passageiros a uma linha. A série diária completa será conectada ao backend.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SectionCard(
          title: 'Ocorrências da linha',
          child: _Unavailable(
            text:
                'Nenhuma ocorrência adicional encontrada na amostra selecionada.',
          ),
        ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: AppColors.muted, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}
