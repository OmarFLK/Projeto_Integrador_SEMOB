import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/transport_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/api_client.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/analytics_charts.dart';
import '../../../shared/widgets/page_components.dart';

class LineDetailPage extends ConsumerWidget {
  const LineDetailPage({super.key, required this.lineCode});
  final String lineCode;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(globalFiltersProvider).period;
    final lines = ref.watch(remoteProvider('lines?period=$p'));
    final history = ref.watch(
      remoteProvider('line-history?period=$p&line=$lineCode'),
    );
    final anomalies = ref.watch(
      remoteProvider('anomalies?period=$p&line=$lineCode'),
    );
    final trips = ref.watch(
      tripPageProvider(
        Uri(
          queryParameters: {
            'period': p,
            'line': lineCode,
            'limit': '50',
            'order': 'desc',
          },
        ).query,
      ),
    );
    final vehicles = ref.watch(
      remoteProvider('vehicles?period=$p&line=$lineCode'),
    );
    return PageBody(
      children: [
        PageHeader(
          title: 'Linha $lineCode',
          subtitle: 'Período $p',
          action: OutlinedButton(
            onPressed: () => context.go('/lines'),
            child: const Text('Voltar às linhas'),
          ),
        ),
        const SizedBox(height: 16),
        lines.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, s) => Text(apiError(e)),
          data: (value) {
            final records = (value as List).map(
              (r) => LineSummary.fromJson(Map<String, dynamic>.from(r as Map)),
            );
            final line = records.where((r) => r.code == lineCode).firstOrNull;
            if (line == null) {
              return const Text('Linha não encontrada neste período.');
            }
            return MetricsGrid(
              children: [
                MetricCard(
                  label: 'Viagens consolidadas',
                  value: Formatters.integer(line.trips),
                  icon: Icons.route,
                ),
                MetricCard(
                  label: 'Km total',
                  value: Formatters.decimal(line.totalKm),
                  icon: Icons.map,
                ),
                MetricCard(
                  label: 'Participação nas viagens',
                  value: Formatters.percent(line.performance),
                  icon: Icons.pie_chart,
                ),
                const MetricCard(
                  label: 'Passageiros por linha',
                  value: 'Indisponível',
                  icon: Icons.groups,
                  helper: 'Fonte não relaciona passageiros à linha',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Evolução diária de viagens',
          child: history.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, s) => Text(apiError(e)),
            data: (value) {
              final rows = (value as List).cast<Map>();
              if (rows.isEmpty) return const Text('Sem registros.');
              return AnalyticsBarChart(
                labels: rows
                    .map((r) => (r['date'] as String).substring(8))
                    .toList(),
                series: [
                  ChartSeries(
                    name: 'Viagens',
                    values: rows
                        .map((r) => (r['trips'] as num).toDouble())
                        .toList(),
                    color: AppColors.green,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Veículos registrados',
          child: vehicles.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, s) => Text(apiError(e)),
            data: (value) => Wrap(
              spacing: 8,
              children: [
                for (final v in value as List)
                  ActionChip(
                    label: Text(v['prefix'] as String),
                    onPressed: () => context.go('/fleet/${v['prefix']}'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Registros recentes',
          subtitle: 'Primeira página, até 50 registros',
          trailing: TextButton(
            onPressed: () {
              ref
                  .read(globalFiltersProvider.notifier)
                  .update(GlobalFilters(period: p, line: lineCode));
              context.go('/trips');
            },
            child: const Text('Consultar todas'),
          ),
          child: trips.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, s) => Text(apiError(e)),
            data: (page) => Column(
              children: [
                Text('${page.total} registros encontrados'),
                for (final t in page.items)
                  ListTile(
                    title: Text('${t.date} • ${t.vehicle} • ${t.status.label}'),
                    subtitle: Text('${t.direction} • ${t.start} → ${t.end}'),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Ocorrências da linha',
          child: anomalies.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, s) => Text(apiError(e)),
            data: (value) => Column(
              children: [
                if ((value as List).isEmpty)
                  const Text('Nenhuma ocorrência registrada no período.'),
                for (final a in value)
                  ListTile(
                    title: Text(a['description'] as String),
                    subtitle: Text(a['date'] as String),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
