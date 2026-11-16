import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../services/api_client.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/page_components.dart';
import '../../../shared/widgets/global_filter_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/responsive/breakpoints.dart';

class AiAssistantPage extends ConsumerStatefulWidget {
  const AiAssistantPage({super.key});
  @override
  ConsumerState<AiAssistantPage> createState() => _AssistantState();
}

class _AssistantState extends ConsumerState<AiAssistantPage> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final messages =
      <({String question, String answer, List<String> sources, DateTime at})>[];
  bool busy = false;
  String? error;
  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(remoteProvider('assistant/status'));
    final configured = status.value?['configured'] == true;
    final prefs = ref.watch(preferencesProvider).value ?? {};
    final inset = prefs['compact'] == true
        ? AppSpacing.sm
        : AppBreakpoints.isMobile(context)
        ? AppSpacing.md
        : AppSpacing.lg;
    final fontSize = switch (prefs['chatTextSize']) {
      'small' => 13.0,
      'large' => 18.0,
      _ => 15.0,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: PageBody(
            controller: scroll,
            maxWidth: double.infinity,
            children: [
              const PageHeader(
                title: 'Assistente SEMOB',
                subtitle: 'Um olhar conectado aos dados da operação',
                action: GlobalFilterBar(),
              ),
              const SizedBox(height: 20),
              if (messages.isEmpty) ...[
                const SemobHeroPanel(
                  eyebrow: 'Inteligência / Assistente',
                  title: 'Pergunte. Explore. Compreenda.',
                  description:
                      'Converse com a IA institucional sobre o período selecionado. Use as fontes e a cobertura para interpretar cada resposta.',
                ),
                const SizedBox(height: 20),
              ],
              status.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => SemobEmptyState(
                  message: 'Não foi possível verificar a integração.',
                  icon: Icons.cloud_off_outlined,
                  action: TextButton(
                    onPressed: () =>
                        ref.invalidate(remoteProvider('assistant/status')),
                    child: const Text('Verificar conexão'),
                  ),
                ),
                data: (_) => DataSourceNote(
                  text: configured
                      ? 'Sua pergunta será enviada com o contexto permitido nas preferências da conta. Confira as fontes da resposta.'
                      : 'A conexão com a IA institucional ainda não foi configurada. Procure a administração para habilitar a integração.',
                  provisional: !configured,
                ),
              ),
              const SizedBox(height: 20),
              if (messages.isEmpty && configured)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final question in [
                      'Como foi o cumprimento de viagens?',
                      'Quais dias exigem atenção?',
                      'Resuma a demanda de passageiros.',
                    ])
                      ActionChip(
                        label: Text(question),
                        avatar: const Icon(Icons.north_east, size: 15),
                        onPressed: busy
                            ? null
                            : () {
                                input.text = question;
                                _ask();
                              },
                      ),
                  ],
                ),
              for (final message in messages) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.only(top: 20, left: 24),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: context.palette.greenLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          message.question,
                          style: TextStyle(fontSize: fontSize, height: 1.6),
                        ),
                        if (prefs['chatShowTimestamps'] == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat(
                                '${prefs['chatDateFormat'] == 'yyyy-MM-dd' ? 'yyyy-MM-dd' : 'dd/MM/yyyy'} · HH:mm',
                              ).format(message.at),
                              style: TextStyle(
                                color: context.palette.muted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Assistente SEMOB',
                  subtitle: 'Resposta da integração institucional',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        message.answer,
                        style: TextStyle(fontSize: fontSize, height: 1.8),
                      ),
                      if (message.sources.isNotEmpty)
                        ExpansionTile(
                          title: const Text('Fontes e contexto utilizados'),
                          children: [
                            for (final source in message.sources)
                              ListTile(title: Text(source)),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
              if (busy) const SemobLoadingSkeleton(height: 170, lines: 2),
              if (error != null)
                SemobEmptyState(message: error!, icon: Icons.error_outline),
            ],
          ),
        ),
        Container(
          key: const Key('assistant_composer'),
          margin: EdgeInsets.fromLTRB(inset, 0, inset, 96),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.palette.surface,
            border: Border.all(color: context.palette.line),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('assistant_input'),
                    controller: input,
                    enabled: configured && !busy,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 4000,
                    decoration: InputDecoration(
                      hintText: 'Pergunte sobre os dados de transporte',
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: context.palette.line),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: context.palette.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: context.palette.green,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _ask(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: busy ? 'Consultando' : 'Enviar pergunta',
                  onPressed: configured && !busy ? _ask : null,
                  icon: Icon(
                    busy
                        ? Icons.hourglass_top_rounded
                        : Icons.arrow_upward_rounded,
                  ),
                ),
              ],
            ),
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
          at: DateTime.now(),
        ));
        input.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) {
          scroll.animateTo(
            scroll.position.maxScrollExtent,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
