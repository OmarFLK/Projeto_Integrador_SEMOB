import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transport_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/global_filter_bar.dart';
import '../../../shared/widgets/page_components.dart';

class TripsPage extends ConsumerStatefulWidget {
  const TripsPage({super.key});

  @override
  ConsumerState<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends ConsumerState<TripsPage> {
  String _search = '';
  TripStatus? _status;
  bool _ascending = true;
  int _page = 0;
  static const _pageSize = 5;

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(tripsProvider);
    return PageBody(
      children: [
        PageHeader(
          title: 'Viagens',
          subtitle: 'Consulta detalhada dos registros operacionais',
          action: const GlobalFilterBar(),
        ),
        const SizedBox(height: 16),
        const DataSourceNote(
          text:
              'Amostra navegável derivada dos relatórios Mensal_Viagens e exceções • Agosto de 2026',
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Registros de viagens',
          subtitle:
              '36.752 registros na fonte mensal • amostra otimizada para o protótipo',
          trailing: IconButton(
            tooltip: 'Exportar CSV',
            onPressed: () => _feedback(
              'Exportação CSV preparada para integração com a API.',
            ),
            icon: const Icon(Icons.download_outlined, size: 20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Toolbar(
                search: _search,
                status: _status,
                onSearch: (value) => setState(() {
                  _search = value;
                  _page = 0;
                }),
                onStatus: (value) => setState(() {
                  _status = value;
                  _page = 0;
                }),
                onExport: () => _feedback(
                  'Exportação visual concluída. O arquivo será gerado pela API futura.',
                ),
              ),
              const SizedBox(height: 14),
              AsyncContent<TripRecord>(
                value: trips,
                emptyMessage: 'Nenhuma viagem corresponde aos filtros.',
                builder: _buildTrips,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrips(List<TripRecord> allTrips) {
    final filtered =
        allTrips.where((trip) {
          final query = _search.trim().toLowerCase();
          final matchesSearch =
              query.isEmpty ||
              trip.line.toLowerCase().contains(query) ||
              trip.vehicle.toLowerCase().contains(query) ||
              trip.activity.toLowerCase().contains(query);
          return matchesSearch && (_status == null || trip.status == _status);
        }).toList()..sort((a, b) {
          final result = a.date.compareTo(b.date);
          return _ascending ? result : -result;
        });

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 44),
        child: Center(
          child: Text(
            'Nenhuma viagem corresponde aos filtros.',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }
    final totalPages = (filtered.length / _pageSize).ceil();
    final safePage = _page.clamp(0, totalPages - 1);
    final start = safePage * _pageSize;
    final pageItems = filtered.skip(start).take(_pageSize).toList();

    return Column(
      children: [
        if (AppBreakpoints.isMobile(context))
          ...pageItems.map((trip) => _TripCard(trip: trip))
        else
          _TripsTable(
            trips: pageItems,
            ascending: _ascending,
            onSort: () => setState(() => _ascending = !_ascending),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              '${filtered.length} registros na amostra',
              style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Página anterior',
              onPressed: safePage > 0
                  ? () => setState(() => _page = safePage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text(
              '${safePage + 1} de $totalPages',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            IconButton(
              tooltip: 'Próxima página',
              onPressed: safePage + 1 < totalPages
                  ? () => setState(() => _page = safePage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }

  void _feedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.search,
    required this.status,
    required this.onSearch,
    required this.onStatus,
    required this.onExport,
  });

  final String search;
  final TripStatus? status;
  final ValueChanged<String> onSearch;
  final ValueChanged<TripStatus?> onStatus;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final searchField = SizedBox(
      width: AppBreakpoints.isMobile(context) ? double.infinity : 300,
      child: TextField(
        onChanged: onSearch,
        decoration: const InputDecoration(
          hintText: 'Buscar linha, prefixo ou atividade',
          prefixIcon: Icon(Icons.search_rounded, size: 20),
          isDense: true,
        ),
      ),
    );
    final statusField = SizedBox(
      width: AppBreakpoints.isMobile(context) ? double.infinity : 190,
      child: DropdownButtonFormField<TripStatus?>(
        initialValue: status,
        decoration: const InputDecoration(labelText: 'Status', isDense: true),
        items: [
          const DropdownMenuItem<TripStatus?>(
            value: null,
            child: Text('Todos os status'),
          ),
          ...TripStatus.values.map(
            (item) => DropdownMenuItem<TripStatus?>(
              value: item,
              child: Text(item.label),
            ),
          ),
        ],
        onChanged: onStatus,
      ),
    );
    final export = OutlinedButton.icon(
      onPressed: onExport,
      icon: const Icon(Icons.file_download_outlined, size: 18),
      label: const Text('Exportar'),
    );
    if (AppBreakpoints.isMobile(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchField,
          const SizedBox(height: 10),
          statusField,
          const SizedBox(height: 10),
          export,
        ],
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [searchField, statusField, export],
    );
  }
}

class _TripsTable extends StatelessWidget {
  const _TripsTable({
    required this.trips,
    required this.ascending,
    required this.onSort,
  });

  final List<TripRecord> trips;
  final bool ascending;
  final VoidCallback onSort;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: 0,
        sortAscending: ascending,
        columns: [
          DataColumn(label: const Text('Data'), onSort: (_, _) => onSort()),
          const DataColumn(label: Text('Linha')),
          const DataColumn(label: Text('Prefixo')),
          const DataColumn(label: Text('Atividade')),
          const DataColumn(label: Text('Sentido')),
          const DataColumn(label: Text('Faixa')),
          const DataColumn(label: Text('Início')),
          const DataColumn(label: Text('Fim')),
          const DataColumn(label: Text('Km prod.'), numeric: true),
          const DataColumn(label: Text('Km improd.'), numeric: true),
          const DataColumn(label: Text('Km total'), numeric: true),
          const DataColumn(label: Text('Status')),
        ],
        rows: trips
            .map(
              (trip) => DataRow(
                cells: [
                  DataCell(Text(trip.date)),
                  DataCell(
                    Text(
                      trip.line,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataCell(Text(trip.vehicle)),
                  DataCell(Text(trip.activity)),
                  DataCell(Text(trip.direction)),
                  DataCell(Text(trip.timeRange)),
                  DataCell(Text(trip.start)),
                  DataCell(Text(trip.end)),
                  DataCell(Text(Formatters.decimal(trip.productiveKm))),
                  DataCell(Text(Formatters.decimal(trip.unproductiveKm))),
                  DataCell(Text(Formatters.decimal(trip.totalKm))),
                  DataCell(
                    StatusBadge(
                      label: trip.status.label,
                      kind: tripStatusKind(trip.status),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final TripRecord trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Linha ${trip.line} • ${trip.vehicle}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusBadge(
                label: trip.status.label,
                kind: tripStatusKind(trip.status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${trip.date} • ${trip.direction} • ${trip.timeRange}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            '${trip.start} → ${trip.end}  •  ${Formatters.decimal(trip.totalKm)} km',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
