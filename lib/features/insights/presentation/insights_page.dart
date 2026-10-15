import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/global_filter_bar.dart';
import '../../../shared/widgets/coverage_notice.dart';
import '../../../shared/widgets/page_components.dart';
import '../../auth/presentation/auth_controller.dart';

class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(globalFiltersProvider).period;
    final insights = ref.watch(remoteProvider('insights?period=$p'));
    return PageBody(
      children: [
        const PageHeader(
          title: 'Insights',
          subtitle: 'Leituras calculadas sobre os dados selecionados',
          action: GlobalFilterBar(),
        ),
        const SizedBox(height: 16),
        const CoverageNotice(),
        const SizedBox(height: 16),
        insights.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => const Text('Não foi possível carregar os insights.'),
          data: (value) => Column(
            children: [
              for (final item in value as List)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SectionCard(
                    title: item['title'] as String,
                    subtitle: item['metric'] as String,
                    child: Text(item['description'] as String),
                  ),
                ),
            ],
          ),
        ),
        if (ref.watch(authProvider).user?.can('assistant') == true)
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/assistant'),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Perguntar à IA'),
            ),
          ),
      ],
    );
  }
}
