import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/transport_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/global_filter_bar.dart';
import '../../../shared/widgets/page_components.dart';

class AnomaliesPage extends ConsumerStatefulWidget {
  const AnomaliesPage({super.key});

  @override
  ConsumerState<AnomaliesPage> createState() => _AnomaliesPageState();
}

class _AnomaliesPageState extends ConsumerState<AnomaliesPage> {
  AnomalyLevel? _level;

  @override
  Widget build(BuildContext context) {
    final anomalies = ref.watch(anomaliesProvider);
    final records = anomalies.value ?? <AnomalyRecord>[];
    return PageBody(
      children: [
        PageHeader(
          title: 'Anomalias',
          subtitle: 'Central de ocorrências derivadas dos dados operacionais',
          action: const GlobalFilterBar(),
        ),
        const SizedBox(height: 16),
        const DataSourceNote(
          text:
              'Exceções reportadas pelas fontes no período selecionado. Investigue cada ocorrência no contexto operacional.',
        ),
        const SizedBox(height: 16),
        MetricsGrid(
          children: [
            MetricCard(
              label: 'Não realizadas',
              value: anomalies.isLoading
                  ? '…'
                  : '${records.where((r) => r.metric == "Não realizada").length}',
              icon: Icons.event_busy_outlined,
              change: 'Atenção',
              positive: false,
            ),
            MetricCard(
              label: 'Não iniciadas',
              value: anomalies.isLoading
                  ? '…'
                  : '${records.where((r) => r.metric == "Não iniciada").length}',
              icon: Icons.play_disabled_outlined,
            ),
            MetricCard(
              label: 'Não terminadas',
              value: anomalies.isLoading
                  ? '…'
                  : '${records.where((r) => r.metric == "Não terminada").length}',
              icon: Icons.stop_circle_outlined,
            ),
            MetricCard(
              label: 'Total de exceções',
              value: anomalies.isLoading ? '…' : '${records.length}',
              icon: Icons.compare_arrows_rounded,
              helper: 'Total no mês',
            ),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Ocorrências recentes',
          subtitle: 'Eventos priorizados para investigação',
          trailing: DropdownButton<AnomalyLevel?>(
            value: _level,
            hint: const Text('Todos os níveis'),
            items: const [
              DropdownMenuItem<AnomalyLevel?>(
                value: null,
                child: Text('Todos os níveis'),
              ),
              DropdownMenuItem(
                value: AnomalyLevel.critical,
                child: Text('Crítico'),
              ),
              DropdownMenuItem(
                value: AnomalyLevel.attention,
                child: Text('Atenção'),
              ),
              DropdownMenuItem(
                value: AnomalyLevel.information,
                child: Text('Informativo'),
              ),
            ],
            onChanged: (value) => setState(() => _level = value),
          ),
          child: AsyncContent<AnomalyRecord>(
            value: anomalies,
            builder: (data) {
              final filtered = data
                  .where((item) => _level == null || item.level == _level)
                  .toList();
              return Column(
                children: filtered
                    .map((item) => _AnomalyItem(item: item))
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AnomalyItem extends StatelessWidget {
  const _AnomalyItem({required this.item});
  final AnomalyRecord item;

  @override
  Widget build(BuildContext context) {
    final (label, color, soft) = switch (item.level) {
      AnomalyLevel.critical => (
        'CRÍTICO',
        context.palette.red,
        context.palette.redSoft,
      ),
      AnomalyLevel.attention => (
        'ATENÇÃO',
        context.palette.amber,
        context.palette.amberSoft,
      ),
      AnomalyLevel.information => (
        'INFORMATIVO',
        context.palette.blue,
        context.palette.blueSoft,
      ),
    };
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: soft,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 9.5,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              item.date,
              style: TextStyle(color: context.palette.muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          item.description,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 5),
        Text(
          'Linha ${item.line}${item.vehicle == null ? '' : ' • Veículo ${item.vehicle}'} • ${item.metric}',
          style: TextStyle(color: context.palette.muted, fontSize: 11.5),
        ),
      ],
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: context.palette.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: AppBreakpoints.isMobile(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/trips'),
                  child: const Text('Investigar'),
                ),
              ],
            )
          : Row(
              children: [
                Container(width: 4, height: 58, color: color),
                const SizedBox(width: 14),
                Expanded(child: details),
                OutlinedButton(
                  onPressed: () => context.go('/trips'),
                  child: const Text('Investigar'),
                ),
              ],
            ),
    );
  }
}
