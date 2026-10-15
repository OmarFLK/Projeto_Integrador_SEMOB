import 'package:flutter/material.dart';
import '../../../shared/widgets/page_components.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});
  @override
  Widget build(BuildContext context) => const PageBody(
    children: [
      PageHeader(
        title: 'Ajuda',
        subtitle: 'Orientações para consultar e atualizar o portal',
      ),
      SizedBox(height: 16),
      SectionCard(
        title: 'Como consultar',
        child: Text(
          'Selecione um período e use os filtros disponíveis em cada tela. Os filtros são oferecidos conforme os campos existentes nas fontes. Viagens tem busca, status e paginação completa. Linhas e veículos possuem consulta detalhada.',
        ),
      ),
      SizedBox(height: 12),
      SectionCard(
        title: 'Cobertura e comparações',
        child: Text(
          'Confira quantos dias foram informados antes de comparar períodos. Dia ausente não significa zero. Passageiros são provisórios e a fonte atual não informa demanda por linha, veículo ou horário. Créditos transferidos não representam receita tarifária.',
        ),
      ),
      SizedBox(height: 12),
      SectionCard(
        title: 'Importar e exportar',
        child: Text(
          'Perfis autorizados encontram a importação na página Relatórios e dados. Use ZIP de HTMLs com as pastas de período originais ou CSV normalizado com os cabeçalhos definidos na documentação. O CSV usa UTF-8 e ponto decimal, sem separador de milhar. Exportações PDF são limitadas a 5.000 registros; para volumes maiores use CSV.',
        ),
      ),
      SizedBox(height: 12),
      SectionCard(
        title: 'Assistente e acesso',
        child: Text(
          'O assistente chama a API institucional quando a integração está configurada. Respostas incluem contexto e fontes. Se o serviço estiver indisponível, o portal apresenta o erro. Para cadastro, alteração de perfil ou indisponibilidade de recuperação, procure a administração do portal.',
        ),
      ),
    ],
  );
}
