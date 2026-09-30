import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/page_components.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const PageHeader(
        title: 'Ajuda',
        subtitle: 'Orientações rápidas para usar o Portal SEMOB',
      ),
      const SizedBox(height: 16),
      const TwoColumnLayout(
        left: SectionCard(
          title: 'Primeiros passos',
          child: Column(
            children: [
              _HelpItem(
                number: '1',
                title: 'Escolha o período',
                description: 'Use os filtros globais para delimitar a análise.',
              ),
              _HelpItem(
                number: '2',
                title: 'Explore os indicadores',
                description:
                    'Abra linhas, veículos e viagens para mais detalhes.',
              ),
              _HelpItem(
                number: '3',
                title: 'Investigue ocorrências',
                description:
                    'A Central de Anomalias reúne os desvios detectados.',
              ),
            ],
          ),
        ),
        right: SectionCard(
          title: 'Suporte',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.mail_outline, color: AppColors.green),
                title: Text('Suporte de TI'),
                subtitle: Text('suporte.ti@semob.scs.gov.br'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.schedule, color: AppColors.green),
                title: Text('Atendimento'),
                subtitle: Text('Segunda a sexta, 8h às 18h'),
              ),
              DataSourceNote(text: 'Versão demonstrativa do frontend • 2026.2'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      const SectionCard(
        title: 'Perguntas frequentes',
        child: Column(
          children: [
            ExpansionTile(
              title: Text('Os dados são atualizados em tempo real?'),
              children: [
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Ainda não. Esta versão usa modelos derivados dos relatórios anexados. A atualização será feita pela API futura.',
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: Text('Por que passageiros por linha não aparecem?'),
              children: [
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'O relatório de passageiros disponibilizado possui totais diários do sistema, sem associação direta à linha.',
                  ),
                ),
              ],
            ),
            ExpansionTile(
              title: Text('A IA já está conectada?'),
              children: [
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Não. O Assistente SEMOB apresenta a experiência planejada com respostas mockadas.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class _HelpItem extends StatelessWidget {
  const _HelpItem({
    required this.number,
    required this.title,
    required this.description,
  });
  final String number;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.greenLight,
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.greenDark,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
