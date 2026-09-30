import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transport_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/global_filter_bar.dart';
import '../../../shared/widgets/page_components.dart';

class FleetPage extends ConsumerStatefulWidget {
  const FleetPage({super.key});

  @override
  ConsumerState<FleetPage> createState() => _FleetPageState();
}

class _FleetPageState extends ConsumerState<FleetPage> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesProvider);
    return PageBody(
      children: [
        PageHeader(
          title: 'Frota',
          subtitle: 'Veículos identificados nos registros de viagens',
          action: const GlobalFilterBar(),
        ),
        const SizedBox(height: 16),
        const DataSourceNote(
          text:
              '58 prefixos identificados no arquivo Mensal_Viagens • exibindo os principais por quilometragem',
        ),
        const SizedBox(height: 16),
        MetricsGrid(
          children: const [
            MetricCard(
              label: 'Prefixos identificados',
              value: '58',
              icon: Icons.directions_bus_outlined,
            ),
            MetricCard(
              label: 'Linhas atendidas',
              value: '9',
              icon: Icons.signpost_outlined,
            ),
            MetricCard(
              label: 'Maior quilometragem',
              value: '6.978,3 km',
              icon: Icons.route_outlined,
              helper: 'Prefixo 1769',
            ),
            MetricCard(
              label: 'Status da amostra',
              value: 'Operacional',
              icon: Icons.check_circle_outline,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Veículos',
          subtitle: 'Consolidação mensal por prefixo',
          trailing: SizedBox(
            width: AppBreakpoints.isMobile(context) ? 150 : 230,
            child: TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                hintText: 'Buscar prefixo',
                prefixIcon: Icon(Icons.search, size: 19),
                isDense: true,
              ),
            ),
          ),
          child: AsyncContent<VehicleSummary>(
            value: vehicles,
            builder: (data) {
              final filtered = data
                  .where((item) => item.prefix.contains(_search.trim()))
                  .toList();
              if (AppBreakpoints.isMobile(context)) {
                return Column(
                  children: filtered
                      .map((vehicle) => _VehicleCard(vehicle: vehicle))
                      .toList(),
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Prefixo')),
                    DataColumn(label: Text('Linhas')),
                    DataColumn(label: Text('Viagens'), numeric: true),
                    DataColumn(label: Text('Km total'), numeric: true),
                    DataColumn(label: Text('Primeiro registro')),
                    DataColumn(label: Text('Último registro')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: filtered
                      .map(
                        (vehicle) => DataRow(
                          onSelectChanged: (_) =>
                              context.go('/fleet/${vehicle.prefix}'),
                          cells: [
                            DataCell(
                              Text(
                                vehicle.prefix,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DataCell(Text(vehicle.lines.join(', '))),
                            DataCell(Text(Formatters.integer(vehicle.trips))),
                            DataCell(
                              Text('${Formatters.decimal(vehicle.totalKm)} km'),
                            ),
                            DataCell(Text(vehicle.firstRecord)),
                            DataCell(Text(vehicle.lastRecord)),
                            DataCell(StatusBadge(label: vehicle.status)),
                          ],
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});
  final VehicleSummary vehicle;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.go('/fleet/${vehicle.prefix}'),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.greenLight,
            child: Icon(Icons.directions_bus_outlined, color: AppColors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prefixo ${vehicle.prefix}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  'Linhas ${vehicle.lines.join(', ')} • ${Formatters.integer(vehicle.trips)} viagens',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${Formatters.decimal(vehicle.totalKm)} km',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    ),
  );
}
