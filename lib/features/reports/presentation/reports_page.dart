import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/page_components.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _period = 'Agosto de 2026';

  static const reports = [
    (
      'Operação',
      Icons.route_outlined,
      'Viagens planejadas, realizadas e quilometragem',
    ),
    (
      'Viagens',
      Icons.alt_route_rounded,
      'Registros detalhados por linha e veículo',
    ),
    (
      'Passageiros',
      Icons.groups_2_outlined,
      'Catraca, antecipados e não pagantes',
    ),
    ('Linhas', Icons.signpost_outlined, 'Consolidado de desempenho por linha'),
    (
      'Frota',
      Icons.directions_bus_outlined,
      'Utilização e quilometragem por prefixo',
    ),
    (
      'Financeiro',
      Icons.account_balance_wallet_outlined,
      'Créditos transferidos e saldo final',
    ),
    (
      'Anomalias',
      Icons.warning_amber_rounded,
      'Ocorrências operacionais identificadas',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        const PageHeader(
          title: 'Relatórios',
          subtitle: 'Visualização e exportação de dados operacionais',
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.green,
                ),
                const Text(
                  'Período do relatório',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(
                  width: 230,
                  child: DropdownButtonFormField<String>(
                    initialValue: _period,
                    decoration: const InputDecoration(isDense: true),
                    items:
                        const [
                              'Agosto de 2026',
                              'Julho de 2026',
                              '1ª quinzena de setembro',
                            ]
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                    onChanged: (value) =>
                        setState(() => _period = value ?? _period),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 650
                ? 1
                : constraints.maxWidth < 1100
                ? 2
                : 3;
            const gap = 12.0;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: reports
                  .map(
                    (report) => SizedBox(
                      width: width,
                      child: _ReportCard(
                        title: report.$1,
                        icon: report.$2,
                        description: report.$3,
                        period: _period,
                        onAction: _feedback,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  void _feedback(String action) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$action preparado para a futura API de relatórios.'),
        ),
      );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.icon,
    required this.description,
    required this.period,
    required this.onAction,
  });
  final String title;
  final IconData icon;
  final String description;
  final String period;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.green),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            period,
            style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              OutlinedButton.icon(
                onPressed: () => onAction('Visualização de $title'),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Visualizar'),
              ),
              OutlinedButton(
                onPressed: () => onAction('PDF de $title'),
                child: const Text('PDF'),
              ),
              OutlinedButton(
                onPressed: () => onAction('CSV de $title'),
                child: const Text('CSV'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
