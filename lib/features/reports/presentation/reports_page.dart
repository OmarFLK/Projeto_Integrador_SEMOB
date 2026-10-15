import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/api_client.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/global_filter_bar.dart';
import '../../../shared/widgets/page_components.dart';
import '../../../shared/widgets/export_actions.dart';
import '../../auth/presentation/auth_controller.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsState();
}

class _ReportsState extends ConsumerState<ReportsPage> {
  bool importing = false;
  String dataset = 'operation_days';
  String? feedback;
  bool failed = false;
  static const reports = [
    ('operation', 'Operação', '/operation'),
    ('trips', 'Viagens', '/trips'),
    ('passengers', 'Passageiros', '/passengers'),
    ('lines', 'Linhas', '/lines'),
    ('vehicles', 'Frota', '/fleet'),
    ('financial', 'Financeiro', '/financial'),
    ('anomalies', 'Anomalias', '/anomalies'),
  ];
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final meta = ref.watch(remoteProvider('meta'));
    final options = ref.watch(optionsProvider);
    return PageBody(
      children: [
        const PageHeader(
          title: 'Relatórios e dados',
          subtitle: 'Consulte, exporte e importe lotes com rastreabilidade',
          action: GlobalFilterBar(),
        ),
        const SizedBox(height: 16),
        if (user?.can('import') == true)
          SectionCard(
            title: 'Importar novos dados',
            subtitle:
                'ZIP com HTMLs organizados por mês ou CSV normalizado. Limite: 25 MB.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: dataset,
                  decoration: const InputDecoration(
                    labelText: 'Tipo do CSV (não se aplica ao ZIP)',
                  ),
                  items:
                      ((options.value?['datasets'] as List?)?.cast<String>() ??
                              [
                                'operation_days',
                                'fleet_compliance_days',
                                'line_days',
                                'time_range_line_stats',
                                'time_range_summaries',
                                'trips',
                                'anomalies',
                                'passenger_days',
                                'credit_balances',
                                'financial_flows',
                              ])
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                  onChanged: importing
                      ? null
                      : (v) => setState(() => dataset = v!),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: importing
                          ? null
                          : () => downloadDataset(context, ref, dataset),
                      icon: const Icon(Icons.download),
                      label: const Text('Baixar modelo CSV'),
                    ),
                    TextButton(
                      onPressed: importing
                          ? null
                          : () => downloadDataset(
                              context,
                              ref,
                              dataset,
                              template: false,
                            ),
                      child: const Text('Baixar dados normalizados do período'),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: importing ? null : _import,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    importing
                        ? 'Validando e importando...'
                        : 'Selecionar arquivo e importar',
                  ),
                ),
                if (importing) const LinearProgressIndicator(),
                if (feedback != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      feedback!,
                      style: TextStyle(color: failed ? Colors.red : null),
                    ),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'O CSV usa as colunas normalizadas documentadas no projeto. Novos lotes preservam o histórico fora das chaves atualizadas.',
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        meta.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, s) => TextButton(
            onPressed: () => ref.invalidate(remoteProvider('meta')),
            child: const Text('Recarregar situação dos dados'),
          ),
          data: (value) => DataSourceNote(
            text:
                'Última importação: ${value['importedAt'] ?? 'Nenhuma'} • ${value['counts']?['trips'] ?? 0} registros de viagens • ${value['counts']?['source_files'] ?? 0} fontes.',
          ),
        ),
        const SizedBox(height: 16),
        for (final report in reports)
          if (report.$1 != 'financial' || user?.can('financial') == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionCard(
                title: report.$2,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.go(report.$3),
                      icon: const Icon(Icons.visibility),
                      label: const Text('Visualizar'),
                    ),
                    ExportActions(resource: report.$1),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _import() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Relatórios SEMOB',
            extensions: ['zip', 'csv'],
          ),
        ],
      );
      if (file == null) return;
      if (await file.length() > 25 * 1024 * 1024) {
        throw Exception('O arquivo deve ter até 25 MB.');
      }
      setState(() {
        importing = true;
        feedback = null;
        failed = false;
      });
      final response = await ref
          .read(apiClientProvider)
          .dio
          .post<Map<String, dynamic>>(
            'imports',
            data: {
              'filename': file.name,
              'dataset': dataset,
              'content': base64Encode(await file.readAsBytes()),
            },
          );
      if (!mounted) return;
      refreshData(ref);
      setState(() => feedback = 'Lote publicado. ${response.data!['counts']}');
    } catch (e) {
      if (mounted) {
        setState(() {
          failed = true;
          feedback = e is Exception && e.toString().contains('25 MB')
              ? 'O arquivo deve ter até 25 MB.'
              : apiError(e);
        });
      }
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }
}
