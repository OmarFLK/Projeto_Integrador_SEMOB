import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/page_components.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});
  @override
  State<HelpPage> createState() => _HelpState();
}

class _HelpState extends State<HelpPage> {
  String search = '';
  static const topics = [
    (
      Icons.tune_rounded,
      'Como consultar',
      'Selecione um período e use os filtros disponíveis em cada tela. Os filtros são oferecidos conforme os campos existentes nas fontes. Viagens tem busca, status e paginação completa. Linhas e veículos possuem consulta detalhada.',
    ),
    (
      Icons.data_usage_rounded,
      'Cobertura e comparações',
      'Confira quantos dias foram informados antes de comparar períodos. Dia ausente não significa zero. Passageiros são provisórios e a fonte atual não informa demanda por linha, veículo ou horário. Créditos transferidos não representam receita tarifária.',
    ),
    (
      Icons.file_download_outlined,
      'Importar e exportar',
      'Perfis autorizados encontram a importação na página Relatórios e dados, na aba Importar dados. Use ZIP de HTMLs com as pastas de período originais ou CSV normalizado com os cabeçalhos documentados. CSV usa UTF-8 e ponto decimal, sem separador de milhar. Exportações PDF são limitadas a 5.000 registros; para volumes maiores use CSV.',
    ),
    (
      Icons.auto_awesome_outlined,
      'Assistente e contexto',
      'O assistente chama a API institucional quando a integração está configurada. Respostas incluem contexto e fontes. A interface não inventa respostas quando o serviço está indisponível. Preferências de IA não ativam capacidades que a integração não oferece.',
    ),
    (
      Icons.admin_panel_settings_outlined,
      'Recuperar acesso',
      'No login, selecione Esqueci minha senha. No modo manual, informe sua identificação e proponha uma nova senha. O pedido aguarda conferência administrativa: a senha atual só muda após aprovação. Guarde o protocolo e procure a administração por um canal conhecido, sem enviar sua senha. O pedido não confirma envio de e-mail.',
    ),
    (
      Icons.keyboard_outlined,
      'Navegação e acessibilidade',
      'O menu lateral expande com mouse, foco ou clique. Você pode fixá-lo aberto em Configurações. Escape fecha a expansão temporária. No celular, use Mais para encontrar todos os módulos. A aparência e a redução de movimento podem ser ajustadas na sua conta.',
    ),
  ];
  @override
  Widget build(BuildContext context) {
    final filtered = topics
        .where(
          (t) => '${t.$2} ${t.$3}'.toLowerCase().contains(search.toLowerCase()),
        )
        .toList();
    return PageBody(
      maxWidth: 1100,
      children: [
        const PageHeader(
          title: 'Ajuda',
          subtitle: 'Um guia para explorar o portal com confiança',
        ),
        const SizedBox(height: 20),
        const SemobHeroPanel(
          eyebrow: 'Central de ajuda',
          title: 'Como podemos ajudar?',
          description:
              'Encontre orientações sobre os dados, as ferramentas e seu acesso à plataforma.',
        ),
        const SizedBox(height: 20),
        TextField(
          onChanged: (v) => setState(() => search = v),
          decoration: const InputDecoration(
            labelText: 'Buscar na ajuda',
            hintText: 'Filtros, relatórios, senha…',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 20),
        if (filtered.isEmpty)
          const SemobEmptyState(message: 'Nenhum tópico corresponde à busca.'),
        for (final topic in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SemobGlassCard(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                initiallyExpanded: search.isNotEmpty,
                key: ValueKey('${topic.$2}:$search'),
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Icon(topic.$1, color: context.palette.green, size: 21),
                title: Text(
                  topic.$2,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Text(
                      topic.$3,
                      style: TextStyle(
                        color: context.palette.muted,
                        height: 1.8,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
