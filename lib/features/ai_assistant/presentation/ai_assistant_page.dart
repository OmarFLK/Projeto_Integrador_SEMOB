import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/transport_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/analytics_charts.dart';
import '../../../shared/widgets/page_components.dart';

class AiAssistantPage extends ConsumerStatefulWidget {
  const AiAssistantPage({super.key});

  @override
  ConsumerState<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends ConsumerState<AiAssistantPage> {
  final _controller = TextEditingController();
  final List<String> _questions = [];
  bool _thinking = false;

  static const suggestions = [
    'Quantos passageiros tivemos nos últimos 15 dias?',
    'Qual linha realizou mais viagens?',
    'Compare viagens programadas e realizadas.',
    'Quais viagens não foram realizadas?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(globalFiltersProvider);
    final chat = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AssistantIntro(onSuggestion: _ask),
        for (final question in _questions) ...[
          const SizedBox(height: 14),
          _UserMessage(text: question),
          const SizedBox(height: 10),
          const _AssistantAnswer(),
        ],
        if (_thinking) ...[
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: _ThinkingBubble(),
          ),
        ],
      ],
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppBreakpoints.isMobile(context) ? 16 : 24,
              20,
              AppBreakpoints.isMobile(context) ? 16 : 24,
              24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: AppBreakpoints.isDesktop(context)
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: chat),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 280,
                            child: _ContextPanel(filters: filters),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _CompactContext(filters: filters),
                          const SizedBox(height: 14),
                          chat,
                        ],
                      ),
              ),
            ),
          ),
        ),
        _Composer(
          controller: _controller,
          onSend: () => _ask(_controller.text),
        ),
      ],
    );
  }

  Future<void> _ask(String question) async {
    final clean = question.trim();
    if (clean.isEmpty || _thinking) return;
    _controller.clear();
    setState(() => _thinking = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _questions.add(clean);
      _thinking = false;
    });
  }
}

class _AssistantIntro extends StatelessWidget {
  const _AssistantIntro({required this.onSuggestion});
  final ValueChanged<String> onSuggestion;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assistente SEMOB',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Protótipo com respostas demonstrativas',
                      style: TextStyle(color: AppColors.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Olá! Posso ajudar a explorar os dados de operação, viagens, passageiros e frota. Tente uma destas perguntas:',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _AiAssistantPageState.suggestions
                .map(
                  (item) => ActionChip(
                    avatar: const Icon(Icons.chat_bubble_outline, size: 15),
                    label: Text(item),
                    onPressed: () => onSuggestion(item),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
  );
}

class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
      ),
      child: Text(text, style: const TextStyle(color: AppColors.white)),
    ),
  );
}

class _AssistantAnswer extends StatelessWidget {
  const _AssistantAnswer();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Card(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.green, size: 18),
                SizedBox(width: 8),
                Text(
                  'Análise demonstrativa',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Em agosto de 2026, a operação realizou 34.994 das 35.050 viagens programadas, atingindo 99,84% de cumprimento. A Linha 03 liderou o período com 5.848 viagens.',
              style: TextStyle(height: 1.45),
            ),
            const SizedBox(height: 14),
            const MetricsGrid(
              children: [
                MetricCard(
                  label: 'Viagens realizadas',
                  value: '34.994',
                  icon: Icons.task_alt_outlined,
                ),
                MetricCard(
                  label: 'Taxa de cumprimento',
                  value: '99,84%',
                  icon: Icons.speed_rounded,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const SectionCard(
              title: 'Ranking de linhas',
              child: AnalyticsBarChart(
                labels: ['03', '02', '06', '07', '01'],
                series: [
                  ChartSeries(
                    name: 'Viagens',
                    values: [5848, 5841, 4496, 3556, 3427],
                    color: AppColors.green,
                  ),
                ],
                height: 190,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: null,
                  icon: Icon(Icons.dataset_outlined, size: 17),
                  label: Text('Ver dados utilizados'),
                ),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: Icon(Icons.open_in_new, size: 17),
                  label: Text('Abrir análise'),
                ),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: Icon(Icons.filter_alt_outlined, size: 17),
                  label: Text('Aplicar filtro'),
                ),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: Icon(Icons.download_outlined, size: 17),
                  label: Text('Exportar'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('Analisando os dados...'),
        ],
      ),
    ),
  );
}

class _ContextPanel extends StatelessWidget {
  const _ContextPanel({required this.filters});
  final GlobalFilters filters;
  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Contexto da análise',
    subtitle: 'Filtros enviados ao assistente',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ContextRow('Período', filters.period),
        _ContextRow('Linha', filters.line),
        _ContextRow('Veículo', filters.vehicle),
        _ContextRow('Faixa', filters.timeRange),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.tune, size: 17),
          label: const Text('Alterar filtros'),
        ),
        const SizedBox(height: 12),
        const Text(
          'A integração com um modelo de IA será feita via API. Nesta versão, as respostas são mocks de interface.',
          style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.4),
        ),
      ],
    ),
  );
}

class _ContextRow extends StatelessWidget {
  const _ContextRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ],
    ),
  );
}

class _CompactContext extends StatelessWidget {
  const _CompactContext({required this.filters});
  final GlobalFilters filters;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.greenLight,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.tune, color: AppColors.green, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            '${filters.period} • ${filters.line} • ${filters.timeRange}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5),
          ),
        ),
      ],
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      AppBreakpoints.isMobile(context) ? 12 : 24,
      12,
      AppBreakpoints.isMobile(context) ? 12 : 24,
      12 + MediaQuery.paddingOf(context).bottom,
    ),
    decoration: const BoxDecoration(
      color: AppColors.white,
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: TextField(
          controller: controller,
          onSubmitted: (_) => onSend(),
          decoration: InputDecoration(
            hintText: 'Pergunte sobre a operação da SEMOB...',
            prefixIcon: const Icon(Icons.auto_awesome, color: AppColors.green),
            suffixIcon: IconButton(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded, color: AppColors.green),
            ),
          ),
        ),
      ),
    ),
  );
}
