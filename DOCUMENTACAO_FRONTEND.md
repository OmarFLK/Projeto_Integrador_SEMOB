# SEMOB-SCS — Documentação do frontend

## 1. Visão do produto

O **Portal de Operação de Transporte** é uma aplicação interna, responsiva e multiplataforma para gestores, analistas, operadores e administradores da Secretaria de Mobilidade Urbana de São Caetano do Sul. Esta entrega implementa exclusivamente o frontend e usa dados locais derivados dos relatórios fornecidos. Não há backend, persistência, autenticação real ou IA real nesta etapa.

Objetivos atendidos:

- consolidar indicadores operacionais em um dashboard navegável;
- facilitar a consulta de viagens, passageiros, linhas e frota;
- evidenciar ocorrências e diferenças operacionais;
- preparar a aplicação para API, MongoDB e assistente de IA futuros;
- oferecer experiências próprias para desktop, tablet e mobile.

## 2. Fontes analisadas

Foram lidos:

- `Doc_Produto_Software_-_Projeto_Integrador_TTI206_2026-2.docx.pdf` — 15 páginas;
- `Dados de Utilização do Transporte Municipal.zip` — 44 relatórios HTML de julho, agosto e setembro de 2026;
- relatórios mensais e quinzenais de resumo, faixa horária, linhas, viagens, exceções, passageiros e saldos.

### Campos encontrados

| Domínio | Campos da fonte usados pelo frontend |
|---|---|
| Operação diária | Data, dia da semana, número de veículos, máximo de veículos por faixa, viagens programadas, viagens realizadas, diferença, km produtivo, km improdutivo e km total |
| Linhas | Data, linha, km total e número de viagens |
| Viagens | Data, linha, prefixo, atividade, sentido, faixa horária, início realizado, fim realizado, km produtivo, km improdutivo e km total |
| Exceções de viagem | Atendimento, motorista, tabela, status de saída/chegada, início/fim programado e realizado |
| Passageiros | Mês, dia, catraca, antecipados, não pagantes e total de passageiros |
| Financeiro | Créditos transferidos para cartões e saldo final |

### Totais reais usados nos mocks

| Indicador | Julho/2026 | Agosto/2026 |
|---|---:|---:|
| Viagens programadas | 36.387 | 35.050 |
| Viagens realizadas | 36.330 | 34.994 |
| Km produtivo | 248.321,3 | 261.886,8 |
| Km improdutivo | 14.425,5 | 13.807,7 |
| Km total | 262.746,8 | 275.694,5 |
| Passageiros totais | 489.653 | 1.050.248 |

O relatório de passageiros informa explicitamente que os valores são provisórios. Essa ressalva também aparece na interface.

## 3. Decisões sobre integridade dos dados

- Passageiros por linha não são apresentados como valor real, pois a fonte de passageiros possui apenas totais diários do sistema.
- Receita, tarifa média e faturamento não são apresentados como valor real, pois não fazem parte do escopo financeiro solicitado para esta versão.
- Usuários, cargos e permissões são mocks visuais e estão identificados como demonstrativos.
- A resposta do Assistente SEMOB é mockada e identificada como protótipo.
- Os números de linha, viagens, km, prefixos, passageiros, exceções, créditos e saldo usados nos painéis foram transcritos ou agregados a partir dos arquivos fornecidos.
- O arquivo de logo institucional citado no briefing não foi anexado como imagem. O componente `BrandMark` funciona como marca temporária, desenhada em código, e pode ser trocado pelo asset oficial sem alterar os layouts.

## 4. Stack

- Flutter e Dart;
- Riverpod para autenticação, filtros e carregamento dos repositórios;
- `go_router` para rotas protegidas e navegação;
- Dio configurado em `ApiClient` para a futura API REST;
- `fl_chart` para linhas, barras, barras empilhadas e gráfico de distribuição;
- `intl` para formatação numérica e monetária em `pt_BR`.

## 5. Arquitetura

```text
lib/
├── core/
│   ├── responsive/       # breakpoints e detecção de layout
│   ├── theme/            # cores, tema e espaçamento
│   └── utils/            # formatação de números e moeda
├── features/
│   ├── auth/
│   ├── dashboard/
│   ├── operation/
│   ├── trips/
│   ├── passengers/
│   ├── lines/
│   ├── fleet/
│   ├── financial/
│   ├── anomalies/
│   ├── insights/
│   ├── ai_assistant/
│   ├── reports/
│   ├── users/
│   ├── settings/
│   └── help/
├── mocks/                # dados derivados dos relatórios
├── models/               # modelos de domínio
├── repositories/         # contrato e implementação mock
├── router/               # rotas e proteção de sessão
├── services/             # cliente Dio
└── shared/               # providers, shell e componentes reutilizáveis
```

Fluxo atual:

```text
Tela → Riverpod Provider → TransportRepository → MockTransportRepository → dados locais
```

Fluxo futuro:

```text
Tela → Riverpod Provider → TransportRepository → ApiTransportRepository → Dio → API → MongoDB
```

## 6. Rotas

| Rota | Tela |
|---|---|
| `/login` | Autenticação interna |
| `/dashboard` | Visão Geral |
| `/operation` | Operação |
| `/trips` | Viagens detalhadas |
| `/passengers` | Passageiros |
| `/lines` | Linhas |
| `/lines/:code` | Detalhe da linha |
| `/fleet` | Frota |
| `/fleet/:prefix` | Detalhe do veículo |
| `/financial` | Financeiro |
| `/anomalies` | Anomalias |
| `/insights` | Insights |
| `/assistant` | Assistente SEMOB |
| `/reports` | Relatórios |
| `/users` | Usuários e Acessos |
| `/profile` | Meu Perfil |
| `/settings` | Configurações |
| `/help` | Ajuda |

As rotas internas redirecionam para o login quando não há sessão mockada.

## 7. Responsividade

- **Mobile, abaixo de 720 px:** bottom navigation, menu “Mais”, filtros em bottom sheet, cards empilhados e tabelas transformadas em listas.
- **Tablet, de 720 a 1179 px:** rail lateral recolhido, grids de duas colunas e filtros quebrados em linhas.
- **Desktop, a partir de 1180 px:** sidebar completa, topbar, painéis amplos e botão flutuante do assistente.

O login usa um breakpoint próprio de 980 px para evitar comprimir o formulário ao lado do painel institucional.

## 8. Autenticação demonstrativa

```text
Usuário: admin@semob.sp.gov.br
Senha:   semob2026
```

Estados implementados:

- campos obrigatórios;
- credenciais inválidas;
- carregamento;
- sessão expirada;
- lembrar acesso;
- mostrar/ocultar senha;
- recuperação de senha informativa;
- logout.

## 9. Telas e interações

- Dashboard com 8 KPIs, cinco visualizações e consolidado por linha.
- Operação com cumprimento, veículos, km e dias divergentes.
- Viagens com busca, status, ordenação, paginação, exportação visual e cards mobile.
- Passageiros com gráfico empilhado, evolução, composição e pico diário.
- Linhas e frota com busca, listagem e telas de detalhe.
- Financeiro restrito aos campos disponíveis, com placeholders explícitos para dados futuros.
- Anomalias com níveis, filtros e ação de investigação.
- Insights com comparações reais entre julho e agosto.
- Assistente com contexto dos filtros e respostas que demonstram texto, KPI, gráfico, ranking e ações.
- Relatórios com período, visualização e exportações mockadas.
- Usuários com busca, perfil de acesso, status e modal de novo usuário.
- Perfil, preferências e ajuda.

## 10. Estados da interface

Os repositórios simulam pequena latência para exibir carregamento. Componentes compartilhados tratam:

- carregando;
- erro de leitura;
- lista vazia;
- resultado sem correspondência de busca;
- ação preparada para API futura;
- informação indisponível na fonte.

## 11. Execução local

Pré-requisitos:

- Flutter no canal estável, compatível com Dart `^3.12.2`;
- Chrome ou Edge para Web;
- Visual Studio com a carga de desenvolvimento C++ para Windows;
- Android Studio, Android SDK e um emulador ou dispositivo para Android.

Preparação inicial:

```powershell
git clone https://github.com/OmarFLK/Projeto_Integrador_SEMOB.git
cd Projeto_Integrador_SEMOB
flutter doctor -v
flutter pub get
flutter devices
```

Execução Web:

```powershell
flutter run -d chrome
```

Execução Windows:

```powershell
flutter config --enable-windows-desktop
flutter run -d windows
```

Execução Android:

```powershell
flutter run -d <id-do-dispositivo>
```

Servidor Web sem abertura automática do navegador:

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

Acesse `http://127.0.0.1:8080` e autentique-se com as credenciais demonstrativas descritas na seção 8.

Durante `flutter run`, use `r` para hot reload, `R` para hot restart e `q` para encerrar.

O README principal contém instruções adicionais de build, diagnóstico e solução de problemas para cada plataforma.

## 12. Validação executada

```text
flutter analyze
No issues found!

flutter test
6 tests passed

flutter build web --release
build/web/main.dart.js gerado com sucesso
```

Os testes cobrem login, navegação após autenticação, grade de indicadores e ausência de overflow do dashboard em 390 × 844, 900 × 1100 e 1440 × 900.

## 13. Próximos passos

1. Receber e adicionar o logo oficial como asset.
2. Implementar `ApiTransportRepository` mantendo o contrato existente.
3. Adicionar autenticação real e armazenamento seguro de token.
4. Conectar filtros a consultas da API.
5. Substituir exportações visuais por arquivos gerados no backend.
6. Ligar o Assistente SEMOB a um endpoint com autorização e auditoria.
7. Adicionar testes de integração e golden tests com a identidade visual aprovada.
