import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transport_models.dart';
import '../../../services/api_client.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/global_filter_bar.dart';
import '../../../shared/widgets/page_components.dart';
import '../../../shared/widgets/export_actions.dart';
import '../../auth/presentation/auth_controller.dart';

class TripsPage extends ConsumerStatefulWidget {
  const TripsPage({super.key});
  @override
  ConsumerState<TripsPage> createState() => _TripsState();
}

class _TripsState extends ConsumerState<TripsPage> {
  String search = '';
  String? status;
  int offset = 0;
  bool ascending = true;
  Timer? debounce;
  static const limit = 50;
  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(globalFiltersProvider);
    ref.listen(globalFiltersProvider, (a, b) {
      if (a != b) setState(() => offset = 0);
    });
    final parameters = {
      ...filters.query(),
      'search': search,
      'limit': '$limit',
      'offset': '$offset',
      'order': ascending ? 'asc' : 'desc',
      'status': ?status,
    };
    final query = Uri(queryParameters: parameters).query;
    final page = ref.watch(tripPageProvider(query));
    return PageBody(
      children: [
        const PageHeader(
          title: 'Viagens',
          subtitle: 'Consulta completa com filtros e paginação no servidor',
          action: GlobalFilterBar(),
        ),
        const SizedBox(height: 16),
        const DataSourceNote(
          text:
              'Registros detalhados de atividades e exceções. A contagem pode diferir do resumo de viagens normais realizadas.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar linha, prefixo ou atividade',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) {
                  debounce?.cancel();
                  debounce = Timer(const Duration(milliseconds: 350), () {
                    if (mounted) {
                      setState(() {
                        search = v;
                        offset = 0;
                      });
                    }
                  });
                },
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Todos'),
                  ),
                  for (final s in TripStatus.values)
                    DropdownMenuItem(value: s.name, child: Text(s.label)),
                ],
                onChanged: (v) => setState(() {
                  status = v;
                  offset = 0;
                }),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                ascending = !ascending;
                offset = 0;
              }),
              icon: const Icon(Icons.sort),
              label: Text(ascending ? 'Mais antigas' : 'Mais recentes'),
            ),
            if (ref.watch(authProvider).user?.can('export') == true)
              for (final format in ['csv', 'pdf'])
                TextButton(
                  onPressed: () => exportResource(
                    context,
                    ref,
                    'trips',
                    format,
                    query: parameters,
                  ),
                  child: Text('Exportar ${format.toUpperCase()}'),
                ),
          ],
        ),
        const SizedBox(height: 16),
        page.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Column(
            children: [
              Text(apiError(e)),
              TextButton(
                onPressed: () => ref.invalidate(tripPageProvider(query)),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
          data: (result) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${Formatters.integer(result.total)} registros encontrados'),
              const SizedBox(height: 8),
              if (result.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Nenhuma viagem corresponde aos filtros.'),
                )
              else if (AppBreakpoints.isMobile(context))
                ...result.items.map(
                  (r) => Card(
                    child: ListTile(
                      title: Text('Linha ${r.line} • ${r.vehicle}'),
                      subtitle: Text(
                        '${r.date} • ${r.start} → ${r.end}\n${r.activity} • ${r.direction} • ${r.timeRange}\n${Formatters.decimal(r.totalKm)} km • ${r.status.label}',
                      ),
                    ),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Data')),
                      DataColumn(label: Text('Linha')),
                      DataColumn(label: Text('Prefixo')),
                      DataColumn(label: Text('Atividade')),
                      DataColumn(label: Text('Sentido')),
                      DataColumn(label: Text('Faixa')),
                      DataColumn(label: Text('Início')),
                      DataColumn(label: Text('Fim')),
                      DataColumn(label: Text('Km total')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: result.items
                        .map(
                          (r) => DataRow(
                            cells: [
                              for (final value in [
                                r.date,
                                r.line,
                                r.vehicle,
                                r.activity,
                                r.direction,
                                r.timeRange,
                                r.start,
                                r.end,
                                Formatters.decimal(r.totalKm),
                                r.status.label,
                              ])
                                DataCell(Text(value)),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: offset > 0
                        ? () => setState(
                            () => offset = (offset - limit).clamp(
                              0,
                              result.total,
                            ),
                          )
                        : null,
                    child: const Text('Anterior'),
                  ),
                  Text(
                    result.total == 0
                        ? '0 registros'
                        : '${offset + 1}–${(offset + limit).clamp(0, result.total)} de ${result.total}',
                  ),
                  OutlinedButton(
                    onPressed: offset + limit < result.total
                        ? () => setState(() => offset += limit)
                        : null,
                    child: const Text('Próxima'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
