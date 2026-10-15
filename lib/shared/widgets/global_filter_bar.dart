import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/transport_models.dart';
import '../providers/app_providers.dart';

class GlobalFilterBar extends ConsumerWidget {
  const GlobalFilterBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(globalFiltersProvider);
    final options = ref.watch(optionsProvider);
    final path = GoRouterState.of(context).uri.path;
    final lineEnabled =
        path.startsWith('/lines') ||
        ['/trips', '/fleet', '/anomalies'].contains(path);
    final dimensions = ['/trips', '/fleet'].contains(path);
    void update(GlobalFilters value) =>
        ref.read(globalFiltersProvider.notifier).update(value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: options.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, s) => Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Filtros indisponíveis'),
              TextButton(
                onPressed: () => ref.invalidate(optionsProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
          data: (data) {
            Widget field(
              String label,
              String value,
              List<String> values,
              ValueChanged<String> changed, {
              Map<String, String> labels = const {},
            }) {
              final selected = values.contains(value)
                  ? value
                  : values.firstOrNull;
              return SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('$label:$selected'),
                  initialValue: selected,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: label, isDense: true),
                  items: values
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(
                            labels[v] ?? v,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) changed(v);
                  },
                ),
              );
            }

            final periods = (data['periods'] as List).cast<Map>();
            final periodValues = periods
                .map((r) => r['value'] as String)
                .toList();
            if (!periodValues.contains(filters.period) &&
                periodValues.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ref.context.mounted) {
                  update(GlobalFilters(period: periodValues.first));
                }
              });
            }
            return Wrap(
              spacing: 10,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                field(
                  'Período',
                  filters.period,
                  periodValues,
                  (v) => update(GlobalFilters(period: v)),
                  labels: {
                    for (final p in periods)
                      p['value'] as String: p['label'] as String,
                  },
                ),
                if (lineEnabled)
                  field('Linha', filters.line, [
                    'Todas as linhas',
                    ...(data['lines'] as List).cast<String>(),
                  ], (v) => update(filters.copyWith(line: v))),
                if (dimensions)
                  field('Veículo', filters.vehicle, [
                    'Todos os veículos',
                    ...(data['vehicles'] as List).cast<String>(),
                  ], (v) => update(filters.copyWith(vehicle: v))),
                if (dimensions)
                  field('Sentido', filters.direction, [
                    'Todos os sentidos',
                    ...(data['directions'] as List).cast<String>(),
                  ], (v) => update(filters.copyWith(direction: v))),
                if (dimensions)
                  field('Faixa horária', filters.timeRange, [
                    'Todas as faixas',
                    ...(data['timeRanges'] as List).cast<String>(),
                  ], (v) => update(filters.copyWith(timeRange: v))),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(globalFiltersProvider.notifier).reset(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Limpar'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
