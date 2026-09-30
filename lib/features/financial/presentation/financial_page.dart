import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transport_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/analytics_charts.dart';
import '../../../shared/widgets/global_filter_bar.dart';
import '../../../shared/widgets/page_components.dart';

class FinancialPage extends ConsumerWidget {
  const FinancialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financial = ref.watch(financialProvider);
    return PageBody(
      children: [
        PageHeader(
          title: 'Financeiro',
          subtitle: 'Créditos transferidos e saldo do sistema',
          action: const GlobalFilterBar(),
        ),
        const SizedBox(height: 16),
        const DataSourceNote(
          text:
              'Indicadores limitados aos campos financeiros disponíveis no relatório Saldos_Mensal • Agosto de 2026',
        ),
        const SizedBox(height: 16),
        MetricsGrid(
          children: const [
            MetricCard(
              label: 'Créditos transferidos',
              value: 'R\$ 676.230,71',
              icon: Icons.credit_card_outlined,
              helper: 'Total de agosto/2026',
            ),
            MetricCard(
              label: 'Saldo final',
              value: 'R\$ 19.763.241,64',
              icon: Icons.account_balance_wallet_outlined,
              helper: 'Posição em 31/08/2026',
            ),
            MetricCard(
              label: 'Maior transferência',
              value: 'R\$ 140.260,00',
              icon: Icons.trending_up_rounded,
              helper: '25/08/2026',
            ),
            MetricCard(
              label: 'Receita tarifária',
              value: 'Não disponível',
              icon: Icons.receipt_long_outlined,
              helper: 'Campo ausente na fonte',
            ),
          ],
        ),
        const SizedBox(height: 12),
        AsyncContent<FinancialDay>(
          value: financial,
          builder: (days) => Column(
            children: [
              TwoColumnLayout(
                left: SectionCard(
                  title: 'Créditos transferidos para cartões',
                  subtitle: 'Evolução nos dias selecionados da amostra',
                  child: AnalyticsBarChart(
                    labels: days.map((item) => '${item.day}').toList(),
                    series: [
                      ChartSeries(
                        name: 'Créditos (R\$)',
                        values: days
                            .map((item) => item.transferredCredits)
                            .toList(),
                        color: AppColors.green,
                      ),
                    ],
                  ),
                ),
                right: SectionCard(
                  title: 'Evolução do saldo final',
                  subtitle: 'Saldo informado pelo relatório de origem',
                  child: AnalyticsLineChart(
                    labels: days.map((item) => '${item.day}').toList(),
                    series: [
                      ChartSeries(
                        name: 'Saldo (R\$)',
                        values: days.map((item) => item.finalBalance).toList(),
                        color: AppColors.graphite,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Movimentações da amostra',
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Data')),
                      DataColumn(
                        label: Text('Créditos transferidos'),
                        numeric: true,
                      ),
                      DataColumn(label: Text('Saldo final'), numeric: true),
                    ],
                    rows: days
                        .map(
                          (item) => DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  '${item.day.toString().padLeft(2, '0')}/08/2026',
                                ),
                              ),
                              DataCell(
                                Text(
                                  Formatters.currency(item.transferredCredits),
                                ),
                              ),
                              DataCell(
                                Text(Formatters.currency(item.finalBalance)),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SectionCard(
          title: 'Dados financeiros futuros',
          subtitle: 'Componentes preparados, sem apresentar valores como reais',
          child: Row(
            children: [
              Icon(Icons.lock_clock_outlined, color: AppColors.muted),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Receita por linha, tarifa média e conciliação poderão ser ativadas quando esses campos forem fornecidos pela API.',
                  style: TextStyle(color: AppColors.muted, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
