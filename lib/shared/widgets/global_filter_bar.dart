import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/transport_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../providers/app_providers.dart';

class GlobalFilterBar extends ConsumerStatefulWidget {
  const GlobalFilterBar({super.key});
  @override
  ConsumerState<GlobalFilterBar> createState() => _FilterState();
}

class _FilterState extends ConsumerState<GlobalFilterBar> {
  bool expanded = true;
  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(globalFiltersProvider);
    final options = ref.watch(optionsProvider);
    final path = GoRouterState.of(context).uri.path;
    final lineEnabled =
        path.startsWith('/lines') ||
        ['/trips', '/fleet', '/anomalies'].contains(path);
    final dimensions = ['/trips', '/fleet'].contains(path);
    void update(GlobalFilters value) =>
        ref.read(globalFiltersProvider.notifier).update(value);
    if (!lineEnabled && !dimensions) {
      return options.when(
        loading: () => const SizedBox(
          height: 52,
          child: Center(child: LinearProgressIndicator()),
        ),
        error: (_, _) => TextButton.icon(
          onPressed: () => ref.invalidate(optionsProvider),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Recarregar períodos'),
        ),
        data: (data) {
          final periods = (data['periods'] as List).cast<Map>();
          final values = periods.map((p) => p['value'] as String).toList();
          final selected = values.contains(filters.period)
              ? filters.period
              : values.firstOrNull;
          if (selected != null && selected != filters.period) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) update(GlobalFilters(period: selected));
            });
          }
          return Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('Período:$selected'),
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Período',
                    prefixIcon: Icon(Icons.calendar_today_outlined, size: 16),
                    isDense: true,
                  ),
                  items: [
                    for (final p in periods)
                      DropdownMenuItem(
                        value: p['value'] as String,
                        child: Text(
                          p['label'] as String,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) update(GlobalFilters(period: v));
                  },
                ),
              ),
              IconButton(
                tooltip: 'Limpar filtros',
                onPressed: () =>
                    ref.read(globalFiltersProvider.notifier).reset(),
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              ),
            ],
          );
        },
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border.all(color: context.palette.line.withValues(alpha: .7)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: context.palette.green),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Recorte dos dados',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(globalFiltersProvider.notifier).reset(),
                child: const Text('Limpar'),
              ),
              IconButton(
                tooltip: expanded ? 'Recolher filtros' : 'Expandir filtros',
                onPressed: () => setState(() => expanded = !expanded),
                icon: Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: DesignTokens.motion(context),
            curve: DesignTokens.curve,
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: options.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => Row(
                        children: [
                          const Expanded(child: Text('Filtros indisponíveis')),
                          TextButton(
                            onPressed: () => ref.invalidate(optionsProvider),
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                      data: (data) {
                        final periods = (data['periods'] as List).cast<Map>();
                        final periodValues = periods
                            .map((r) => r['value'] as String)
                            .toList();
                        if (!periodValues.contains(filters.period) &&
                            periodValues.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              update(GlobalFilters(period: periodValues.first));
                            }
                          });
                        }
                        return LayoutBuilder(
                          builder: (context, c) {
                            final fieldWidth = c.maxWidth < 420
                                ? c.maxWidth
                                : c.maxWidth < 650
                                ? (c.maxWidth - 12) / 2
                                : 180.0;
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
                                width: fieldWidth,
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('$label:$selected'),
                                  initialValue: selected,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: label,
                                    isDense: true,
                                  ),
                                  items: values
                                      .map(
                                        (v) => DropdownMenuItem(
                                          value: v,
                                          child: Text(
                                            labels[v] ?? v,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
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

                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                field(
                                  'Período',
                                  filters.period,
                                  periodValues,
                                  (v) => update(GlobalFilters(period: v)),
                                  labels: {
                                    for (final p in periods)
                                      p['value'] as String:
                                          p['label'] as String,
                                  },
                                ),
                                if (lineEnabled)
                                  field('Linha', filters.line, [
                                    'Todas as linhas',
                                    ...(data['lines'] as List).cast<String>(),
                                  ], (v) => update(filters.copyWith(line: v))),
                                if (dimensions)
                                  field(
                                    'Veículo',
                                    filters.vehicle,
                                    [
                                      'Todos os veículos',
                                      ...(data['vehicles'] as List)
                                          .cast<String>(),
                                    ],
                                    (v) => update(filters.copyWith(vehicle: v)),
                                  ),
                                if (dimensions)
                                  field(
                                    'Sentido',
                                    filters.direction,
                                    [
                                      'Todos os sentidos',
                                      ...(data['directions'] as List)
                                          .cast<String>(),
                                    ],
                                    (v) =>
                                        update(filters.copyWith(direction: v)),
                                  ),
                                if (dimensions)
                                  field(
                                    'Faixa horária',
                                    filters.timeRange,
                                    [
                                      'Todas as faixas',
                                      ...(data['timeRanges'] as List)
                                          .cast<String>(),
                                    ],
                                    (v) =>
                                        update(filters.copyWith(timeRange: v)),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
          if (filters.line != 'Todas as linhas' && lineEnabled ||
              dimensions &&
                  (filters.vehicle != 'Todos os veículos' ||
                      filters.direction != 'Todos os sentidos' ||
                      filters.timeRange != 'Todas as faixas'))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (lineEnabled && filters.line != 'Todas as linhas')
                    InputChip(
                      label: Text('Linha ${filters.line}'),
                      onDeleted: () =>
                          update(filters.copyWith(line: 'Todas as linhas')),
                    ),
                  if (dimensions && filters.vehicle != 'Todos os veículos')
                    InputChip(
                      label: Text('Veículo ${filters.vehicle}'),
                      onDeleted: () => update(
                        filters.copyWith(vehicle: 'Todos os veículos'),
                      ),
                    ),
                  if (dimensions && filters.direction != 'Todos os sentidos')
                    InputChip(
                      label: Text(filters.direction),
                      onDeleted: () => update(
                        filters.copyWith(direction: 'Todos os sentidos'),
                      ),
                    ),
                  if (dimensions && filters.timeRange != 'Todas as faixas')
                    InputChip(
                      label: Text(filters.timeRange),
                      onDeleted: () => update(
                        filters.copyWith(timeRange: 'Todas as faixas'),
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
