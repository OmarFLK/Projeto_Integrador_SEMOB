import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/global_filter_bar.dart';
import '../../../shared/widgets/page_components.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        PageHeader(
          title: 'Insights',
          subtitle:
              'Leituras automáticas derivadas dos indicadores disponíveis',
          action: const GlobalFilterBar(),
        ),
        const SizedBox(height: 16),
        const DataSourceNote(
          text:
              'Insights descritivos calculados sobre julho e agosto de 2026. Não são previsões de IA.',
        ),
        const SizedBox(height: 16),
        const MetricsGrid(
          children: [
            MetricCard(
              label: 'Insights ativos',
              value: '5',
              icon: Icons.lightbulb_outline_rounded,
            ),
            MetricCard(
              label: 'Exigem atenção',
              value: '2',
              icon: Icons.warning_amber_rounded,
            ),
            MetricCard(
              label: 'Oportunidades',
              value: '2',
              icon: Icons.trending_up_rounded,
            ),
            MetricCard(
              label: 'Informativos',
              value: '1',
              icon: Icons.info_outline_rounded,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._insights.map(
          (insight) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _InsightCard(insight: insight),
          ),
        ),
      ],
    );
  }
}

class _InsightData {
  const _InsightData(
    this.icon,
    this.title,
    this.description,
    this.metric,
    this.kind,
  );
  final IconData icon;
  final String title;
  final String description;
  final String metric;
  final StatusKind kind;
}

const _insights = [
  _InsightData(
    Icons.groups_2_outlined,
    'Aumento expressivo de passageiros',
    'O total informado passou de 489.653 em julho para 1.050.248 em agosto. A fonte classifica os dados como provisórios; recomenda-se validar o crescimento de não pagantes.',
    '+114,5%',
    StatusKind.warning,
  ),
  _InsightData(
    Icons.route_outlined,
    'Quilometragem produtiva cresceu',
    'A quilometragem produtiva aumentou de 248.321,3 km em julho para 261.886,8 km em agosto.',
    '+5,5%',
    StatusKind.good,
  ),
  _InsightData(
    Icons.timeline_rounded,
    'Km improdutivo apresentou redução',
    'Mesmo com aumento da quilometragem total, o componente improdutivo caiu em relação ao mês anterior.',
    '−4,3%',
    StatusKind.good,
  ),
  _InsightData(
    Icons.event_busy_outlined,
    'Diferença entre previstas e realizadas',
    'Foram identificadas 56 viagens programadas sem realização no consolidado de agosto; 03/08 apresentou a maior diferença diária.',
    '56 viagens',
    StatusKind.danger,
  ),
  _InsightData(
    Icons.emoji_events_outlined,
    'Linha 03 liderou em viagens',
    'A Linha 03 realizou 5.848 viagens, ligeiramente acima da Linha 02, com 5.841.',
    '5.848',
    StatusKind.neutral,
  ),
];

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});
  final _InsightData insight;

  @override
  Widget build(BuildContext context) {
    final color = switch (insight.kind) {
      StatusKind.good => AppColors.green,
      StatusKind.warning => AppColors.amber,
      StatusKind.danger => AppColors.red,
      StatusKind.neutral => AppColors.blue,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(insight.icon, color: color),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 220, maxWidth: 850),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    insight.description,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            StatusBadge(label: insight.metric, kind: insight.kind),
            OutlinedButton.icon(
              onPressed: () => context.go('/assistant'),
              icon: const Icon(Icons.auto_awesome, size: 17),
              label: const Text('Perguntar à IA'),
            ),
          ],
        ),
      ),
    );
  }
}
