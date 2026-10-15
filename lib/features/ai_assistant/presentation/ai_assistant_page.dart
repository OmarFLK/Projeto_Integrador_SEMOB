import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_client.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_components.dart';
import '../../../shared/widgets/global_filter_bar.dart';

class AiAssistantPage extends ConsumerStatefulWidget {
  const AiAssistantPage({super.key});
  @override
  ConsumerState<AiAssistantPage> createState() => _AssistantState();
}

class _AssistantState extends ConsumerState<AiAssistantPage> {
  final input = TextEditingController();
  final messages = <({String question, String answer, List<String> sources})>[];
  bool busy = false;
  String? error;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(remoteProvider('assistant/status'));
    final configured = status.value?['configured'] == true;
    return PageBody(
      children: [
        const PageHeader(
          title: 'Assistente SEMOB',
          subtitle: 'Conexão com a IA institucional',
          action: GlobalFilterBar(),
        ),
        const SizedBox(height: 16),
        status.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, s) => TextButton(
            onPressed: () => ref.invalidate(remoteProvider('assistant/status')),
            child: const Text('Verificar conexão'),
          ),
          data: (value) => DataSourceNote(
            text: configured
                ? 'A IA recebe a pergunta e indicadores do período selecionado. Confira as fontes antes de usar a resposta.'
                : 'A conexão com a IA institucional ainda não foi configurada. Nenhuma resposta simulada será apresentada.',
            provisional: !configured,
          ),
        ),
        const SizedBox(height: 16),
        for (final message in messages) ...[
          Align(
            alignment: Alignment.centerRight,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(message.question),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(
            title: 'Resposta',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(message.answer),
                if (message.sources.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ExpansionTile(
                    title: const Text('Fontes e contexto utilizados'),
                    children: message.sources
                        .map((s) => ListTile(title: Text(s)))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        if (busy) const LinearProgressIndicator(),
        TextField(
          controller: input,
          enabled: configured && !busy,
          minLines: 1,
          maxLines: 5,
          maxLength: 4000,
          decoration: const InputDecoration(
            labelText: 'Pergunte sobre os dados de transporte',
            hintText: 'Ex.: qual linha teve mais viagens no período?',
          ),
          onSubmitted: (_) => _ask(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: configured && !busy ? _ask : null,
            icon: const Icon(Icons.send),
            label: Text(busy ? 'Consultando...' : 'Enviar'),
          ),
        ),
      ],
    );
  }

  Future<void> _ask() async {
    final question = input.text.trim();
    if (question.isEmpty || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .post<Map<String, dynamic>>(
            'assistant',
            data: {
              'message': question,
              'filters': ref
                  .read(globalFiltersProvider)
                  .query(dimensions: false),
            },
          );
      if (!mounted) return;
      setState(() {
        messages.add((
          question: question,
          answer: response.data!['answer'] as String,
          sources: (response.data!['sources'] as List? ?? []).cast<String>(),
        ));
        input.clear();
      });
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
