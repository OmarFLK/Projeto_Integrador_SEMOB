import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transport_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/analytics_charts.dart';
import '../../../shared/widgets/global_filter_bar.dart';
import '../../../shared/widgets/coverage_notice.dart';
import '../../../shared/widgets/export_actions.dart';
import '../../../shared/widgets/page_components.dart';

class FinancialPage extends ConsumerWidget {
  const FinancialPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
    children: [
      const PageHeader(
        title: 'Financeiro',
        subtitle: 'Créditos e saldos do período selecionado',
        action: GlobalFilterBar(),
      ),
      const SizedBox(height: 16),
      const CoverageNotice(domain: 'financial'),
      const SizedBox(height: 16),
      AsyncContent<FinancialDay>(
        value: ref.watch(financialProvider),
        builder: (days) {
          final total = days.fold<double>(
            0,
            (s, d) => s + d.transferredCredits,
          );
          final peak = days.reduce(
            (a, b) => a.transferredCredits > b.transferredCredits ? a : b,
          );
          final incomplete = days.any((d) => d.incomplete);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MetricsGrid(
                children: [
                  MetricCard(
                    label: incomplete
                        ? 'Créditos conhecidos'
                        : 'Créditos transferidos',
                    value: Formatters.currency(total),
                    icon: Icons.credit_card,
                  ),
                  MetricCard(
                    label: 'Último saldo registrado',
                    value: Formatters.currency(days.last.finalBalance),
                    icon: Icons.account_balance_wallet,
                    helper: days.last.date,
                  ),
                  MetricCard(
                    label: 'Maior transferência',
                    value: Formatters.currency(peak.transferredCredits),
                    icon: Icons.trending_up,
                    helper: peak.date,
                  ),
                  const MetricCard(
                    label: 'Receita tarifária',
                    value: 'Indisponível',
                    icon: Icons.receipt_long,
                    helper: 'Crédito transferido não equivale a receita',
                  ),
                ],
              ),
              if (incomplete)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: DataSourceNote(
                    text:
                        'Há campos financeiros ausentes. Os valores conhecidos são parciais.',
                    provisional: true,
                  ),
                ),
              const SizedBox(height: 16),
              const ExportActions(resource: 'financial'),
              const SizedBox(height: 16),
              TwoColumnLayout(
                left: SectionCard(
                  title: 'Créditos transferidos',
                  child: AnalyticsBarChart(
                    labels: days.map((d) => '${d.day}').toList(),
                    series: [
                      ChartSeries(
                        name: 'Créditos',
                        values: days.map((d) => d.transferredCredits).toList(),
                        color: AppColors.green,
                      ),
                    ],
                  ),
                ),
                right: SectionCard(
                  title: 'Saldo final',
                  child: AnalyticsLineChart(
                    labels: days.map((d) => '${d.day}').toList(),
                    series: [
                      ChartSeries(
                        name: 'Saldo',
                        values: days.map((d) => d.finalBalance).toList(),
                        color: AppColors.blue,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Movimentações',
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Data')),
                      DataColumn(label: Text('Créditos')),
                      DataColumn(label: Text('Saldo')),
                      DataColumn(label: Text('Cobertura')),
                    ],
                    rows: days
                        .map(
                          (d) => DataRow(
                            cells: [
                              DataCell(Text(d.date)),
                              DataCell(
                                Text(Formatters.currency(d.transferredCredits)),
                              ),
                              DataCell(
                                Text(Formatters.currency(d.finalBalance)),
                              ),
                              DataCell(
                                Text(d.incomplete ? 'Parcial' : 'Informado'),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}
