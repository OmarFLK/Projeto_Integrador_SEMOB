import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transport_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_components.dart';

class VehicleDetailPage extends ConsumerWidget {
  const VehicleDetailPage({super.key, required this.prefix});
  final String prefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider);
    final trips = ref.watch(tripsProvider);
    return PageBody(
      children: [
        PageHeader(
          title: 'Veículo $prefix',
          subtitle: 'Resumo operacional do prefixo',
          action: OutlinedButton.icon(
            onPressed: () => context.go('/fleet'),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Voltar à frota'),
          ),
        ),
        const SizedBox(height: 16),
        vehicles.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('Erro ao carregar: $error'),
          data: (data) {
            final vehicle = data
                .where((item) => item.prefix == prefix)
                .firstOrNull;
            if (vehicle == null) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Veículo não encontrado.'),
                ),
              );
            }
            final related =
                trips.value?.where((item) => item.vehicle == prefix).toList() ??
                const <TripRecord>[];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MetricsGrid(
                  children: [
                    MetricCard(
                      label: 'Viagens',
                      value: Formatters.integer(vehicle.trips),
                      icon: Icons.alt_route_rounded,
                    ),
                    MetricCard(
                      label: 'Km total',
                      value: '${Formatters.decimal(vehicle.totalKm)} km',
                      icon: Icons.route_outlined,
                    ),
                    MetricCard(
                      label: 'Linhas atendidas',
                      value: '${vehicle.lines.length}',
                      icon: Icons.signpost_outlined,
                    ),
                    MetricCard(
                      label: 'Status',
                      value: vehicle.status,
                      icon: Icons.check_circle_outline,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TwoColumnLayout(
                  left: SectionCard(
                    title: 'Histórico da amostra',
                    subtitle: '${vehicle.firstRecord} a ${vehicle.lastRecord}',
                    child: related.isEmpty
                        ? const Text(
                            'Nenhuma viagem deste prefixo está presente na amostra reduzida.',
                            style: TextStyle(color: AppColors.muted),
                          )
                        : Column(
                            children: related
                                .map(
                                  (trip) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.route_outlined,
                                      color: AppColors.green,
                                    ),
                                    title: Text(
                                      'Linha ${trip.line} • ${trip.direction}',
                                    ),
                                    subtitle: Text(
                                      '${trip.date} • ${trip.start} → ${trip.end}',
                                    ),
                                    trailing: Text(
                                      '${Formatters.decimal(trip.totalKm)} km',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  right: SectionCard(
                    title: 'Linhas em que operou',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: vehicle.lines
                          .map(
                            (line) => ActionChip(
                              label: Text('Linha $line'),
                              onPressed: () => context.go('/lines/$line'),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
