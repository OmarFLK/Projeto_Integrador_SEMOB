import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transport_models.dart';
import '../../../services/api_client.dart' show apiError;
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/analytics_charts.dart';
import '../../../shared/widgets/global_filter_bar.dart';
import '../../../shared/widgets/coverage_notice.dart';
import '../../../shared/widgets/page_components.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operations = ref.watch(operationProvider);
    final passengers = ref.watch(passengersProvider);
    final lines = ref.watch(linesProvider);

    return PageBody(
      children: [
        PageHeader(
          title: 'Visão Geral',
          subtitle: 'Acompanhamento consolidado da operação municipal',
          action: const GlobalFilterBar(),
        ),
        const SizedBox(height: 16),
        const CoverageNotice(),
        const SizedBox(height: 16),
        operations.when(
          loading: () => const _LoadingDashboard(),
          error: (error, stack) => _ErrorDashboard(message: apiError(error)),
          data: (operationData) => passengers.when(
            loading: () => const _LoadingDashboard(),
            error: (error, stack) => _ErrorDashboard(message: apiError(error)),
            data: (passengerData) => lines.when(
              loading: () => const _LoadingDashboard(),
              error: (error, stack) =>
                  _ErrorDashboard(message: apiError(error)),
              data: (lineData) => _DashboardContent(
                operations: operationData,
                passengers: passengerData,
                lines: lineData,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.operations,
    required this.passengers,
    required this.lines,
  });

  final List<OperationDay> operations;
  final List<PassengerDay> passengers;
  final List<LineSummary> lines;

  @override
  Widget build(BuildContext context) {
    final scheduled = operations.fold<int>(
      0,
      (sum, item) => sum + item.scheduledTrips,
    );
    final completed = operations.fold<int>(
      0,
      (sum, item) => sum + item.completedTrips,
    );
    final productiveKm = operations.fold<double>(
      0,
      (sum, item) => sum + item.productiveKm,
    );
    final totalKm = operations.fold<double>(
      0,
      (sum, item) => sum + item.totalKm,
    );
    final turnstile = passengers.fold<int>(
      0,
      (sum, item) => sum + item.turnstile,
    );
    final advance = passengers.fold<int>(0, (sum, item) => sum + item.advance);
    final nonPaying = passengers.fold<int>(
      0,
      (sum, item) => sum + item.nonPaying,
    );
    final passengerTotal = passengers.fold<int>(
      0,
      (sum, item) => sum + item.total,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetricsGrid(
          children: [
            MetricCard(
              label: 'Passageiros totais',
              value: Formatters.integer(passengerTotal),
              icon: Icons.groups_2_outlined,
              positive: true,
              helper: 'Total do período selecionado',
            ),
            MetricCard(
              label: 'Passageiros pagantes',
              value: Formatters.integer(turnstile + advance),
              icon: Icons.confirmation_number_outlined,
              positive: true,
              helper: 'Catraca + antecipados',
            ),
            MetricCard(
              label: 'Não pagantes',
              value: Formatters.integer(nonPaying),
              icon: Icons.accessible_forward_outlined,
              positive: false,
              helper: 'Dado provisório',
            ),
            MetricCard(
              label: 'Viagens programadas',
              value: Formatters.integer(scheduled),
              icon: Icons.event_note_outlined,
              positive: false,
              helper: 'Total do período selecionado',
            ),
            MetricCard(
              label: 'Viagens realizadas',
              value: Formatters.integer(completed),
              icon: Icons.task_alt_rounded,
              positive: false,
              helper: 'Total do período selecionado',
            ),
            MetricCard(
              label: 'Taxa de realização',
              value: Formatters.percent(
                scheduled == 0 ? 0 : completed / scheduled * 100,
                decimals: 2,
              ),
              icon: Icons.speed_rounded,
              helper: '$completed de $scheduled',
            ),
            MetricCard(
              label: 'Km total',
              value: '${Formatters.decimal(totalKm)} km',
              icon: Icons.route_outlined,
              helper: 'Total do período selecionado',
            ),
            MetricCard(
              label: 'Km produtivo',
              value: '${Formatters.decimal(productiveKm)} km',
              icon: Icons.timeline_rounded,
              helper: 'Quilometragem registrada',
            ),
          ],
        ),
        const SizedBox(height: 12),
        TwoColumnLayout(
          leftFlex: 2,
          rightFlex: 1,
          left: SectionCard(
            title: 'Passageiros por dia',
            subtitle: 'Composição diária — dados provisórios de bilhetagem',
            child: AnalyticsLineChart(
              labels: passengers.map((item) => '${item.day}').toList(),
              series: [
                ChartSeries(
                  name: 'Catraca',
                  values: passengers
                      .map((item) => item.turnstile.toDouble())
                      .toList(),
                  color: context.palette.green,
                ),
                ChartSeries(
                  name: 'Antecipados',
                  values: passengers
                      .map((item) => item.advance.toDouble())
                      .toList(),
                  color: context.palette.blue,
                ),
                ChartSeries(
                  name: 'Não pagantes',
                  values: passengers
                      .map((item) => item.nonPaying.toDouble())
                      .toList(),
                  color: context.palette.amber,
                ),
                ChartSeries(
                  name: 'Total',
                  values: passengers
                      .map((item) => item.total.toDouble())
                      .toList(),
                  color: context.palette.graphite,
                ),
              ],
            ),
          ),
          right: SectionCard(
            title: 'Distribuição de passageiros',
            subtitle: 'Pagantes x não pagantes',
            child: DistributionDonut(
              primary: (turnstile + advance).toDouble(),
              secondary: nonPaying.toDouble(),
              primaryLabel: 'Pagantes',
              secondaryLabel: 'Não pagantes',
            ),
          ),
        ),
        const SizedBox(height: 12),
        TwoColumnLayout(
          left: SectionCard(
            title: 'Viagens programadas x realizadas',
            subtitle: 'Resultado diário da operação',
            child: AnalyticsBarChart(
              labels: operations.map((item) => '${item.day}').toList(),
              series: [
                ChartSeries(
                  name: 'Programadas',
                  values: operations
                      .map((item) => item.scheduledTrips.toDouble())
                      .toList(),
                  color: context.palette.graphite,
                ),
                ChartSeries(
                  name: 'Realizadas',
                  values: operations
                      .map((item) => item.completedTrips.toDouble())
                      .toList(),
                  color: context.palette.green,
                ),
              ],
            ),
          ),
          right: SectionCard(
            title: 'Quilometragem',
            subtitle: 'Produtiva, improdutiva e total por dia',
            child: AnalyticsLineChart(
              labels: operations.map((item) => '${item.day}').toList(),
              series: [
                ChartSeries(
                  name: 'Produtiva',
                  values: operations.map((item) => item.productiveKm).toList(),
                  color: context.palette.green,
                ),
                ChartSeries(
                  name: 'Improdutiva',
                  values: operations
                      .map((item) => item.unproductiveKm)
                      .toList(),
                  color: context.palette.amber,
                ),
                ChartSeries(
                  name: 'Total',
                  values: operations.map((item) => item.totalKm).toList(),
                  color: context.palette.graphite,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Operação por linha',
          subtitle: 'Viagens e quilometragem consolidadas no mês',
          trailing: TextButton(
            onPressed: () => context.go('/lines'),
            child: const Text('Ver linhas'),
          ),
          child: Column(
            children: [
              AnalyticsBarChart(
                height: 220,
                labels: lines.map((item) => item.code).toList(),
                series: [
                  ChartSeries(
                    name: 'Viagens',
                    values: lines.map((item) => item.trips.toDouble()).toList(),
                    color: context.palette.green,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _LineSummaryTable(lines: lines),
            ],
          ),
        ),
      ],
    );
  }
}

class _LineSummaryTable extends StatelessWidget {
  const _LineSummaryTable({required this.lines});

  final List<LineSummary> lines;

  @override
  Widget build(BuildContext context) {
    if (AppBreakpoints.isMobile(context)) {
      return Column(
        children: lines.take(5).map((line) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: context.palette.greenLight,
              child: Text(
                line.code,
                style: TextStyle(
                  color: context.palette.greenDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            title: Text('${Formatters.integer(line.trips)} viagens'),
            subtitle: Text(
              '${Formatters.decimal(line.totalKm)} km • Passageiros não disponíveis por linha',
            ),
            trailing: StatusBadge(
              label: '${line.performance.toStringAsFixed(1)}%',
            ),
            onTap: () => context.go('/lines/${line.code}'),
          );
        }).toList(),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Linha')),
          DataColumn(label: Text('Viagens'), numeric: true),
          DataColumn(label: Text('Km total'), numeric: true),
          DataColumn(label: Text('Passageiros')),
          DataColumn(label: Text('Variação')),
          DataColumn(label: Text('Status')),
        ],
        rows: lines.take(6).map((line) {
          return DataRow(
            onSelectChanged: (_) => context.go('/lines/${line.code}'),
            cells: [
              DataCell(
                Text(
                  'Linha ${line.code}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              DataCell(Text(Formatters.integer(line.trips))),
              DataCell(Text('${Formatters.decimal(line.totalKm)} km')),
              const DataCell(
                Tooltip(
                  message: 'A fonte não segmenta passageiros por linha.',
                  child: Text('Não disponível'),
                ),
              ),
              const DataCell(Text('—')),
              DataCell(
                StatusBadge(
                  label: 'Volume registrado',
                  kind: line.trips == 0 ? StatusKind.warning : StatusKind.good,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _LoadingDashboard extends StatelessWidget {
  const _LoadingDashboard();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 320,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorDashboard extends ConsumerWidget {
  const _ErrorDashboard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: context.palette.red,
              size: 36,
            ),
            const SizedBox(height: 10),
            const Text('Não foi possível carregar o dashboard.'),
            const SizedBox(height: 4),
            Text(
              message,
              style: TextStyle(color: context.palette.muted, fontSize: 11),
            ),
            TextButton(
              onPressed: () => refreshData(ref),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
