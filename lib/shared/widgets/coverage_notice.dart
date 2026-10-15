import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'page_components.dart';

class CoverageNotice extends ConsumerWidget {
  const CoverageNotice({super.key, this.domain = 'passengers'});
  final String domain;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(globalFiltersProvider).period;
    final coverage = ref.watch(remoteProvider('coverage?period=$p'));
    return coverage.when(
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const DataSourceNote(
        text:
            'Não foi possível verificar a cobertura dos dados. Comparações indisponíveis.',
        provisional: true,
      ),
      data: (value) {
        final domains = value['domains'] as Map;
        final info = domains[domain] as Map;
        return DataSourceNote(
          provisional: info['complete'] != true,
          text:
              'Período $p • ${info['days']} de ${info['expectedDays']} dias com registros de ${switch (domain) {
                'passengers' => 'passageiros',
                'financial' => 'financeiro',
                _ => 'operação',
              }}. ${info['complete'] == true ? 'Cobertura mensal completa.' : 'Cobertura parcial; não comparar como mês completo.'}${domain == 'passengers' ? ' Valores provisórios de bilhetagem.' : ''}',
        );
      },
    );
  }
}
