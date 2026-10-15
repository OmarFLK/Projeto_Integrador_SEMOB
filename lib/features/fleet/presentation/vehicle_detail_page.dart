import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../models/transport_models.dart';
import '../../../core/utils/formatters.dart';
import '../../../services/api_client.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_components.dart';

class VehicleDetailPage extends ConsumerWidget {
  const VehicleDetailPage({super.key, required this.prefix});
  final String prefix;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(globalFiltersProvider).period;
    final vehicles = ref.watch(
      remoteProvider('vehicles?period=$p&vehicle=$prefix'),
    );
    final trips = ref.watch(
      tripPageProvider(
        Uri(
          queryParameters: {
            'period': p,
            'vehicle': prefix,
            'limit': '50',
            'order': 'desc',
          },
        ).query,
      ),
    );
    return PageBody(
      children: [
        PageHeader(
          title: 'Veículo $prefix',
          subtitle: 'Histórico no período $p',
          action: OutlinedButton(
            onPressed: () => context.go('/fleet'),
            child: const Text('Voltar à frota'),
          ),
        ),
        const SizedBox(height: 16),
        vehicles.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, s) => Text(apiError(e)),
          data: (value) {
            final rows = value as List;
            if (rows.isEmpty) {
              return const Text('Veículo não encontrado neste período.');
            }
            final vehicle = VehicleSummary.fromJson(
              Map<String, dynamic>.from(rows.first as Map),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MetricsGrid(
                  children: [
                    MetricCard(
                      label: 'Registros de atividades',
                      value: Formatters.integer(vehicle.trips),
                      icon: Icons.route,
                    ),
                    MetricCard(
                      label: 'Km total',
                      value: Formatters.decimal(vehicle.totalKm),
                      icon: Icons.map,
                    ),
                    MetricCard(
                      label: 'Linhas atendidas',
                      value: '${vehicle.lines.length}',
                      icon: Icons.signpost,
                    ),
                    MetricCard(
                      label: 'Janela registrada',
                      value: vehicle.firstRecord,
                      helper: vehicle.lastRecord,
                      icon: Icons.calendar_month,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: vehicle.lines
                      .map(
                        (line) => ActionChip(
                          label: Text('Linha $line'),
                          onPressed: () => context.go('/lines/$line'),
                        ),
                      )
                      .toList(),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Registros recentes',
          subtitle:
              'Primeira página, até 50 registros. Não indica status atual do veículo.',
          trailing: TextButton(
            onPressed: () {
              ref
                  .read(globalFiltersProvider.notifier)
                  .update(GlobalFilters(period: p, vehicle: prefix));
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
                for (final trip in page.items)
                  ListTile(
                    title: Text('${trip.date} • Linha ${trip.line}'),
                    subtitle: Text(
                      '${trip.direction} • ${trip.start} → ${trip.end} • ${trip.status.label}',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
