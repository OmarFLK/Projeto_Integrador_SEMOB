import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/auth/presentation/auth_controller.dart';
import '../../../services/api_client.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../shared/widgets/account_layout.dart';
import '../../../shared/widgets/page_components.dart';

const preferenceDefaults = <String, dynamic>{
  'compact': false,
  'theme': 'system',
  'chatTextSize': 'normal',
  'chatAssistant': 'last',
  'chatStreaming': true,
  'chatShowTimestamps': false,
  'chatDateFormat': 'dd/MM/yyyy',
  'aiPreset': 'balanced',
  'aiTemperature': .25,
  'aiMaxTokens': 1200,
  'aiReasoning': false,
  'aiResponseMode': 'balanced',
  'aiDepth': 'normal',
  'aiUseContext': true,
};

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.initialSection = 'appearance'});
  final String initialSection;
  @override
  ConsumerState<SettingsPage> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<SettingsPage> {
  late String section;
  bool saving = false;
  double? temperature;
  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection &&
        accountSections.any(
          (s) => s.key == widget.initialSection && s.key != 'profile',
        )) {
      section = widget.initialSection;
    }
  }

  @override
  void initState() {
    super.initState();
    section =
        accountSections.any(
          (s) => s.key == widget.initialSection && s.key != 'profile',
        )
        ? widget.initialSection
        : 'appearance';
  }

  Future<void> save(Map<String, dynamic> patch) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await ref.read(preferencesProvider.notifier).save(patch);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferências salvas na sua conta.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiError(e))));
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
          temperature = null;
        });
      }
    }
  }

  Widget dropdown(
    String key,
    Map<String, String> options,
    Map<String, dynamic> p,
  ) => SizedBox(
    width: 250,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$key:${p[key]}'),
      initialValue: p[key].toString(),
      isExpanded: true,
      decoration: const InputDecoration(isDense: true),
      items: options.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: saving
          ? null
          : (v) {
              if (v != null) save({key: v});
            },
    ),
  );
  Widget toggle(String key, Map<String, dynamic> p) => Switch(
    value: p[key] == true,
    onChanged: saving ? null : (v) => save({key: v}),
  );
  Widget rows(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const Divider(height: 1),
        children[i],
      ],
    ],
  );
  List<String> get sectionKeys => switch (section) {
    'appearance' => ['theme', 'compact', 'chatTextSize'],
    'chat' => [
      'chatAssistant',
      'chatStreaming',
      'chatShowTimestamps',
      'chatDateFormat',
    ],
    'ai' => [
      'aiPreset',
      'aiTemperature',
      'aiMaxTokens',
      'aiReasoning',
      'aiResponseMode',
      'aiDepth',
    ],
    'memory' => ['aiUseContext'],
    _ => [],
  };
  @override
  Widget build(BuildContext context) {
    final value = ref.watch(preferencesProvider);
    final entry = accountSections.firstWhere((e) => e.key == section);
    return AccountLayout(
      selected: section,
      title: 'Configurações',
      subtitle: 'Personalize o portal para o seu jeito de trabalhar.',
      onSelect: (key) => setState(() {
        section = key;
        temperature = null;
      }),
      action: sectionKeys.isEmpty
          ? null
          : OutlinedButton.icon(
              onPressed: saving
                  ? null
                  : () => save({
                      for (final key in sectionKeys)
                        key: preferenceDefaults[key],
                    }),
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Restaurar padrões'),
            ),
      child: value.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, s) => SectionCard(
          title: 'Preferências indisponíveis',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(apiError(e)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(preferencesProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (stored) {
          final p = {...preferenceDefaults, ...stored};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (saving) const LinearProgressIndicator(minHeight: 2),
              AccountBanner(
                title: entry.label,
                subtitle: switch (section) {
                  'appearance' =>
                    'Uma experiência confortável, de dia ou à noite.',
                  'chat' =>
                    'Defina como você prefere conversar com o assistente.',
                  'ai' =>
                    'Escolha o equilíbrio entre objetividade e profundidade.',
                  'memory' =>
                    'Você decide quais dados acompanham suas perguntas.',
                  _ =>
                    'Saiba como sua conta e suas preferências são utilizadas.',
                },
                icon: entry.icon,
              ),
              const SizedBox(height: 20),
              switch (section) {
                'appearance' => appearance(p),
                'chat' => chat(p),
                'ai' => ai(p),
                'memory' => memory(p),
                _ => privacy(),
              },
            ],
          );
        },
      ),
    );
  }

  Widget appearance(Map<String, dynamic> p) => SectionCard(
    title: 'Aparência do portal',
    subtitle: 'As escolhas são sincronizadas com sua conta.',
    child: rows([
      PreferenceRow(
        title: 'Tema',
        subtitle: 'Escolha o modo claro, escuro ou acompanhe seu dispositivo.',
        control: SizedBox(
          width: 280,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'system', label: Text('Sistema')),
              ButtonSegment(value: 'light', label: Text('Claro')),
              ButtonSegment(value: 'dark', label: Text('Escuro')),
            ],
            selected: {p['theme'] as String},
            onSelectionChanged: saving
                ? null
                : (v) => save({'theme': v.single}),
          ),
        ),
      ),
      PreferenceRow(
        title: 'Densidade da interface',
        subtitle:
            'O modo compacto reduz os espaços e deixa mais dados visíveis.',
        control: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(p['compact'] == true ? 'Compacta' : 'Confortável'),
            const SizedBox(width: 10),
            toggle('compact', p),
          ],
        ),
      ),
      PreferenceRow(
        title: 'Texto do chat',
        subtitle: 'Ajuste o tamanho das mensagens do assistente.',
        control: dropdown('chatTextSize', {
          'small': 'Pequeno',
          'normal': 'Normal',
          'large': 'Grande',
        }, p),
      ),
    ]),
  );
  Widget chat(Map<String, dynamic> p) => SectionCard(
    title: 'Conversas',
    subtitle:
        'As preferências de integração serão usadas quando a IA estiver conectada.',
    child: rows([
      PreferenceRow(
        title: 'Assistente padrão',
        subtitle: 'Escolha o ambiente de IA que você prefere abrir.',
        control: dropdown('chatAssistant', {
          'last': 'Último utilizado',
          'standard': 'Assistente padrão',
          'rag': 'Assistente com documentos (RAG)',
        }, p),
      ),
      PreferenceRow(
        title: 'Resposta em tempo real',
        subtitle:
            'Preferência salva para quando a IA oferecer respostas progressivas.',
        control: toggle('chatStreaming', p),
      ),
      PreferenceRow(
        title: 'Horário das mensagens',
        subtitle:
            'Mostre a data e o horário junto das mensagens do assistente.',
        control: toggle('chatShowTimestamps', p),
      ),
      const PreferenceRow(
        title: 'Idioma',
        subtitle: 'Idioma utilizado no portal.',
        control: Text('Português (Brasil)'),
      ),
      PreferenceRow(
        title: 'Formato de data',
        subtitle: 'Formato das datas nas mensagens do assistente.',
        control: dropdown('chatDateFormat', {
          'dd/MM/yyyy': 'DD/MM/AAAA',
          'yyyy-MM-dd': 'AAAA-MM-DD',
        }, p),
      ),
    ]),
  );
  Widget ai(Map<String, dynamic> p) {
    final canUse = ref.watch(authProvider).user?.can('assistant') == true;
    final status = canUse
        ? ref.watch(remoteProvider('assistant/status'))
        : null;
    final connected =
        status?.value is Map && status!.value['configured'] == true;
    const presets = [
      (
        key: 'precise',
        label: 'Preciso',
        description: 'Respostas diretas para consultas numéricas.',
        temperature: .1,
        tokens: 600,
        mode: 'concise',
        depth: 'normal',
        icon: Icons.gps_fixed,
      ),
      (
        key: 'balanced',
        label: 'Balanceado',
        description: 'Equilíbrio entre objetividade e contexto.',
        temperature: .25,
        tokens: 1200,
        mode: 'balanced',
        depth: 'normal',
        icon: Icons.balance,
      ),
      (
        key: 'explanatory',
        label: 'Explicativo',
        description: 'Mais detalhes para entender os resultados.',
        temperature: .45,
        tokens: 2400,
        mode: 'detailed',
        depth: 'normal',
        icon: Icons.notes_outlined,
      ),
      (
        key: 'deep',
        label: 'Análise profunda',
        description: 'Mais espaço para explorar questões complexas.',
        temperature: .3,
        tokens: 4096,
        mode: 'detailed',
        depth: 'deep',
        icon: Icons.travel_explore,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DataSourceNote(
          text: connected
              ? 'As preferências acompanham suas perguntas. A aplicação de cada opção depende do modelo conectado.'
              : 'Preferências preparadas para a integração com a IA. A conexão ainda não foi configurada.',
          provisional: !connected,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final count = c.maxWidth >= 820
                ? 4
                : c.maxWidth >= 420
                ? 2
                : 1;
            final width = (c.maxWidth - 12 * (count - 1)) / count;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final preset in presets)
                  SizedBox(
                    width: width,
                    child: Material(
                      color: p['aiPreset'] == preset.key
                          ? context.palette.greenLight
                          : context.palette.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: p['aiPreset'] == preset.key
                              ? context.palette.green
                              : context.palette.line,
                          width: p['aiPreset'] == preset.key ? 1.5 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: saving
                            ? null
                            : () => save({
                                'aiPreset': preset.key,
                                'aiTemperature': preset.temperature,
                                'aiMaxTokens': preset.tokens,
                                'aiResponseMode': preset.mode,
                                'aiDepth': preset.depth,
                              }),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                preset.icon,
                                color: context.palette.green,
                                size: 22,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                preset.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                preset.description,
                                style: TextStyle(
                                  color: context.palette.muted,
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        SectionCard(
          title: 'Personalizar respostas',
          child: rows([
            PreferenceRow(
              title: 'Temperatura',
              subtitle:
                  'Valores baixos priorizam consistência; valores altos permitem mais variação.',
              control: SizedBox(
                width: 270,
                child: Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value:
                            temperature ??
                            (p['aiTemperature'] as num).toDouble(),
                        min: 0,
                        max: 1,
                        divisions: 20,
                        onChanged: saving
                            ? null
                            : (v) => setState(() => temperature = v),
                        onChangeEnd: saving
                            ? null
                            : (v) => save({'aiTemperature': v}),
                      ),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text(
                        (temperature ?? (p['aiTemperature'] as num).toDouble())
                            .toStringAsFixed(2)
                            .replaceAll('.', ','),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PreferenceRow(
              title: 'Máximo de saída',
              subtitle: 'Limite solicitado para o tamanho da resposta.',
              control: SizedBox(
                width: 250,
                child: DropdownButtonFormField<int>(
                  key: ValueKey(p['aiMaxTokens']),
                  initialValue: p['aiMaxTokens'] as int,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
                  items: const [
                    DropdownMenuItem(
                      value: 600,
                      child: Text('Curta · até 600 tokens'),
                    ),
                    DropdownMenuItem(
                      value: 1200,
                      child: Text('Média · até 1.200 tokens'),
                    ),
                    DropdownMenuItem(
                      value: 2400,
                      child: Text('Longa · até 2.400 tokens'),
                    ),
                    DropdownMenuItem(
                      value: 4096,
                      child: Text('Ampla · até 4.096 tokens'),
                    ),
                  ],
                  onChanged: saving
                      ? null
                      : (v) {
                          if (v != null) save({'aiMaxTokens': v});
                        },
                ),
              ),
            ),
            PreferenceRow(
              title: 'Raciocínio do modelo',
              subtitle:
                  'Preferência preparada para um modelo compatível com esse recurso.',
              control: toggle('aiReasoning', p),
            ),
            PreferenceRow(
              title: 'Modo de resposta',
              subtitle: 'Defina o nível de detalhe que você prefere receber.',
              control: dropdown('aiResponseMode', {
                'concise': 'Objetivo',
                'balanced': 'Equilibrado',
                'detailed': 'Detalhado',
              }, p),
            ),
            PreferenceRow(
              title: 'Profundidade da análise',
              subtitle: 'Escolha quanto contexto explorar nas respostas.',
              control: dropdown('aiDepth', {
                'normal': 'Normal',
                'deep': 'Aprofundada',
              }, p),
            ),
          ]),
        ),
      ],
    );
  }

  Widget memory(Map<String, dynamic> p) => SectionCard(
    title: 'Contexto das perguntas',
    subtitle:
        'Controle quais informações do portal podem acompanhar uma consulta à IA.',
    child: rows([
      PreferenceRow(
        title: 'Usar contexto do portal',
        subtitle:
            'Inclui o período, filtros, indicadores e fontes dos dados na pergunta.',
        control: toggle('aiUseContext', p),
      ),
      const PreferenceRow(
        title: 'Memória entre conversas',
        subtitle: 'Ainda não há memória persistente de conversas no SEMOB.',
        control: Text('Não habilitada'),
      ),
    ]),
  );
  Widget privacy() => SectionCard(
    title: 'Seus dados no SEMOB',
    child: rows([
      const PreferenceRow(
        title: 'Perfil e foto',
        subtitle: 'Salvos na sua conta e acessíveis após entrar no portal.',
        control: Icon(Icons.account_circle_outlined),
      ),
      const PreferenceRow(
        title: 'Preferências',
        subtitle:
            'Tema, densidade e escolhas do assistente são sincronizados com sua conta.',
        control: Text('Por usuário'),
      ),
      const PreferenceRow(
        title: 'Histórico de conversas',
        subtitle:
            'O SEMOB não grava o conteúdo das conversas no banco. As mensagens permanecem apenas enquanto a tela do assistente está aberta.',
        control: Text('Nesta sessão'),
      ),
      const PreferenceRow(
        title: 'Compartilhamento com a IA',
        subtitle:
            'Quando conectada, a IA recebe sua pergunta e o contexto que você permitir. Sua senha e sua foto não acompanham a consulta.',
        control: Icon(Icons.shield_outlined),
      ),
    ]),
  );
}
