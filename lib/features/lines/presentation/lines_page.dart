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

class LinesPage extends ConsumerStatefulWidget {
  const LinesPage({super.key});

  @override
  ConsumerState<LinesPage> createState() => _LinesPageState();
}

class _LinesPageState extends ConsumerState<LinesPage> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(linesProvider);
    return PageBody(
      children: [
        PageHeader(
          title: 'Linhas',
          subtitle: 'Desempenho operacional das linhas municipais',
          action: const GlobalFilterBar(),
        ),
        const SizedBox(height: 16),
        const DataSourceNote(),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Linhas em operação',
          subtitle: 'Linhas identificadas no período selecionado',
          trailing: SizedBox(
            width: AppBreakpoints.isMobile(context) ? 150 : 230,
            child: TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                hintText: 'Buscar linha',
                prefixIcon: Icon(Icons.search, size: 19),
                isDense: true,
              ),
            ),
          ),
          child: AsyncContent<LineSummary>(
            value: lines,
            builder: (data) {
              final filtered = data
                  .where((line) => line.code.contains(_search.trim()))
                  .toList();
              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: Text('Nenhuma linha encontrada.')),
                );
              }
              return _LinesList(lines: filtered);
            },
          ),
        ),
      ],
    );
  }
}

class _LinesList extends StatelessWidget {
  const _LinesList({required this.lines});
  final List<LineSummary> lines;

  @override
  Widget build(BuildContext context) {
    if (AppBreakpoints.isMobile(context)) {
      return Column(
        children: lines.map((line) => _LineCard(line: line)).toList(),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1050 ? 3 : 2;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: lines
              .map(
                (line) => SizedBox(
                  width: width,
                  child: _LineCard(line: line),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line});
  final LineSummary line;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/lines/${line.code}'),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: context.palette.line),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    line.code,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Linha municipal',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.palette.muted),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _LineMetric(
                    label: 'Viagens',
                    value: Formatters.integer(line.trips),
                  ),
                ),
                Expanded(
                  child: _LineMetric(
                    label: 'Km total',
                    value: Formatters.decimal(line.totalKm),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: _LineMetric(
                    label: 'Passageiros',
                    value: 'Não disponível',
                  ),
                ),
                StatusBadge(
                  label: '${line.performance.toStringAsFixed(1)}% das viagens',
                  kind: StatusKind.neutral,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LineMetric extends StatelessWidget {
  const _LineMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(color: context.palette.muted, fontSize: 10.5),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: context.palette.ink,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    ],
  );
}
