import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../models/transport_models.dart';
import '../providers/app_providers.dart';

class GlobalFilterBar extends ConsumerWidget {
  const GlobalFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(globalFiltersProvider);
    if (AppBreakpoints.isMobile(context)) {
      return OutlinedButton.icon(
        onPressed: () => _openMobileFilters(context, ref, filters),
        icon: const Icon(Icons.tune_rounded, size: 19),
        label: const Text('Filtros da análise'),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: AppColors.green),
                  SizedBox(width: 7),
                  Text(
                    'Filtros',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            _FilterDropdown(
              value: filters.period,
              items: const [
                'Agosto de 2026',
                'Julho de 2026',
                '1ª quinzena de setembro',
              ],
              onChanged: (value) =>
                  _update(ref, filters.copyWith(period: value)),
            ),
            _FilterDropdown(
              value: filters.line,
              items: const [
                'Todas as linhas',
                'Linha 01',
                'Linha 02',
                'Linha 03',
                'Linha 04',
                'Linha 05',
                'Linha 06',
                'Linha 07',
                'Linha 08',
                'Linha 10',
              ],
              onChanged: (value) => _update(ref, filters.copyWith(line: value)),
            ),
            _FilterDropdown(
              value: filters.vehicle,
              items: const [
                'Todos os veículos',
                '1440',
                '1502',
                '1585',
                '1591',
                '1769',
                '1975',
              ],
              onChanged: (value) =>
                  _update(ref, filters.copyWith(vehicle: value)),
            ),
            _FilterDropdown(
              value: filters.direction,
              items: const ['Todos os sentidos', 'Ida', 'Volta'],
              onChanged: (value) =>
                  _update(ref, filters.copyWith(direction: value)),
            ),
            _FilterDropdown(
              value: filters.timeRange,
              items: const [
                'Todas as faixas',
                '04h–08h',
                '08h–12h',
                '12h–18h',
                '18h–00h',
              ],
              onChanged: (value) =>
                  _update(ref, filters.copyWith(timeRange: value)),
            ),
            TextButton.icon(
              onPressed: () => ref.read(globalFiltersProvider.notifier).reset(),
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Limpar'),
            ),
          ],
        ),
      ),
    );
  }

  void _update(WidgetRef ref, GlobalFilters filters) {
    ref.read(globalFiltersProvider.notifier).update(filters);
  }

  Future<void> _openMobileFilters(
    BuildContext context,
    WidgetRef ref,
    GlobalFilters current,
  ) async {
    var draft = current;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Filtros da análise',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _MobileField(
                label: 'Período',
                value: draft.period,
                items: const [
                  'Agosto de 2026',
                  'Julho de 2026',
                  '1ª quinzena de setembro',
                ],
                onChanged: (value) =>
                    setModalState(() => draft = draft.copyWith(period: value)),
              ),
              _MobileField(
                label: 'Linha',
                value: draft.line,
                items: const [
                  'Todas as linhas',
                  'Linha 01',
                  'Linha 02',
                  'Linha 03',
                  'Linha 04',
                  'Linha 05',
                  'Linha 06',
                  'Linha 07',
                  'Linha 08',
                  'Linha 10',
                ],
                onChanged: (value) =>
                    setModalState(() => draft = draft.copyWith(line: value)),
              ),
              _MobileField(
                label: 'Veículo',
                value: draft.vehicle,
                items: const [
                  'Todos os veículos',
                  '1440',
                  '1502',
                  '1585',
                  '1591',
                  '1769',
                  '1975',
                ],
                onChanged: (value) =>
                    setModalState(() => draft = draft.copyWith(vehicle: value)),
              ),
              _MobileField(
                label: 'Sentido',
                value: draft.direction,
                items: const ['Todos os sentidos', 'Ida', 'Volta'],
                onChanged: (value) => setModalState(
                  () => draft = draft.copyWith(direction: value),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  _update(ref, draft);
                  Navigator.pop(context);
                },
                child: const Text('Aplicar filtros'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: AppColors.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          style: const TextStyle(color: AppColors.ink, fontSize: 12),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _MobileField extends StatelessWidget {
  const _MobileField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}
