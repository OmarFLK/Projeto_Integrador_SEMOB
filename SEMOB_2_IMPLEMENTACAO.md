# SEMOB 2.0 — Forest Intelligence

Implementação local em `feat/semob-forest-intelligence`, a partir de `1737294`.

## Integração dos briefings

Verdan orienta a composição; Forest/Sage define temas; Curved Sidebar define navegação. Em conflitos, o primeiro briefing tem prioridade: rail flutuante com grupos e topo contextual, sem uma segunda coluna permanente reduzindo a área dos gráficos. Referências azuis de login contribuem com fotografia integrada e painel elevado, mantendo a identidade SEMOB verde.

Recuperação manual aceita senha proposta, armazena apenas hash e exige aprovação administrativa. O fluxo existente por código continua disponível. Não há alteração na senha ao criar a solicitação. Não há publicação nem alteração de bancos de produção nesta execução.

## Checklist

- [x] Tokens, temas e movimento compartilhados
- [x] Shell, grupos, expansão, fixação, teclado e mobile
- [x] Componentes analíticos, filtros e estados
- [x] Todas as páginas e detalhes
- [x] Recuperação manual, painel, API, migração e CLI/SQL
- [x] Testes, build, revisão visual e documentação

## Ambiente

Flutter 3.47.7 / Dart 3.13.5. Dependências mantidas pelos lockfiles. `pub get` resolveu as dependências, mas a criação de symlinks dos plugins desktop está bloqueada pelo Windows sem Modo de Desenvolvedor. Essa configuração não foi alterada.

## Resultado das verificações em 15/11/2026

| Verificação | Resultado |
|---|---|
| Análise Dart do frontend, backend, ferramentas e testes | Sem problemas |
| Suíte Flutter, incluindo revisão visual opt-in | **22 testes aprovados** |
| Suíte backend contra PostgreSQL local isolado | **29 aprovados; 2 ignorados** |
| Build web release, API relativa `/api/v1/` | Aprovado; saída em `build/web` |
| Build CLI do servidor | Aprovado; `backend/build/cli/windows_x64/bundle/bin/server.exe` |
| Build da ferramenta administrativa e comandos help/sql | Aprovados; o bundle final foi recompilado para o servidor |
| Verificação de arquivos publicáveis do projeto | Aprovada no índice existente |
| `git diff --check` | Sem erros |
| Capturas de interface com fixtures | **78 PNGs**, em `.dart_tool/visual-review` |

Os dois testes backend ignorados exigem MongoDB real e o ZIP privado dos 44 relatórios, ausentes no ambiente. Os testes PostgreSQL usaram exclusivamente uma instância portátil local em loopback, com bancos temporários criados pelo fixture. Ao fim, o processo, os binários baixados, o banco temporário e a credencial de teste foram removidos.

As capturas cobrem login, 18 destinos autenticados e navegação fixada, em 390/768/1440/1920 px, com temas claro e escuro. Exemplos revisados foram exportados para `screenshots/forest-*.png`. Os dados das imagens são sintéticos de teste e não entram nas consultas de produção.

Os testes novos comprovam expansão sem deslocamento ou novas consultas, preferência de fixação, URLs de subabas, proposta manual sem redefinição imediata, confirmação administrativa e navegação dos pontos de gráficos pelo teclado. No backend cobrem hash compatível, aprovação, expiração, rejeição, conta inexistente/inativa, uso único, concorrência, sessões, códigos anteriores, falha de notificação e backup v3/v2.

Contraste calculado dos pares principais: texto escuro 12,66:1; texto auxiliar escuro 7,27:1; texto claro 14,68:1; texto auxiliar claro 5,95:1; botão lima 12,61:1; texto do menu 7,45:1. Isso verifica os tokens principais; não constitui uma auditoria completa de acessibilidade de cada estado sobre fotografia.

## Entrega e limites

O [guia de operação](SEMOB_2_GUIA.md) contém a matriz de rotas, variáveis, migração 3, processo manual no Neon e instruções de execução. O notificador administrativo está implementado e foi testado contra um servidor HTTP local com falha controlada. Um serviço real de envio não foi configurado, e nenhum e-mail de produção foi enviado.

O código preserva Windows e Android, mas seus builds nativos não foram executados; não houve mudança do Modo de Desenvolvedor. As capturas são renderizações de widget tests, sem sessão autenticada no deploy. Não foram medidas taxas de quadros em hardware real nem validada a integração de IA externa sem endpoint configurado.

As alterações ficam na branch de revisão, sem commit/push ou publicação automáticos. Nenhum banco, credencial ou conta de produção foi alterado.

## Prévia sem banco — 16/11/2026

Foi adicionada uma entrada explícita `tool/preview.dart`, iniciada por `scripts/run_preview.ps1`. Ela usa um adaptador Dio exclusivamente em memória, dados sintéticos gerados por período e a conta `demo@semob.local` / `SemobDemo2026!`. O adaptador é instalado depois da configuração HTTP do cliente, inclusive na Web; nenhuma requisição de aplicação é encaminhada à API real. `lib/main.dart` não foi alterado.

Há identificação permanente de demonstração. Preferências e nome/cargo/setor podem mudar em memória; operações de servidor (importar, exportar, alterar credenciais, aprovar recuperações e chamar IA) ficam indisponíveis de forma explícita. Recarregar a página reinicia os dados e o login.

Validação específica: três testes novos aprovados, incluindo login e navegação por todos os módulos em 390/1440 px, filtros/paginação e bloqueio de operações não suportadas. Análise estática sem problemas e sintaxe do script PowerShell validada. A prévia não exige PostgreSQL, MongoDB ou credenciais de nuvem.

## Ajuste de movimento, navegação e prévia — 16/11/2026

- Subabas migradas para cápsula flutuante central inferior, com gradiente floresta/oliva, seleção marfim e rolagem horizontal. Fixa sobre a área de conteúdo, acima da navegação mobile. Módulos sem subabas usam os destinos autorizados do grupo; Perfil/Configurações usam suas seções por URL. Removidos os menus contextuais duplicados do topo e da conta.
- KPIs entram em sequência com deslocamento descendente e leve dobra em perspectiva. Linhas são reveladas horizontalmente, barras de baixo para cima e donuts com escala/rotação discreta. As animações começam ao entrar no viewport, repetem para novos dados/subabas e respeitam reduzir movimento. Gráficos abaixo da dobra têm construção adiada; não há timer de polling nem animações contínuas.
- Removida a camada de opacidade sobre a página inteira. Conteúdo, cartões e gráficos têm isolamento de pintura; formatação dos gráficos reutiliza NumberFormat.
- A prévia anterior era Flutter Web debug. run_preview.ps1 agora compila a entrada de demonstração em release por padrão e serve arquivos em loopback, com compressão, ETag e atendimento concorrente. -DebugMode mantém a opção de desenvolvimento. O bootstrap carrega o CanvasKit distribuído com o app, sem depender de CDN do motor gráfico. Nenhum dado sintético foi incorporado à entrada de produção.
- Verificação: analyze sem problemas, 28 testes Flutter aprovados, 78 capturas geradas em 390/768/1440/1920 px e build release da prévia concluído. Novos testes cobrem construção adiada, início por visibilidade, não repetição em rebuild, replay com novos dados, redução de movimento, posição estável do dock, ausência de consultas durante scroll e URLs de configurações.

Não foi medida uma taxa de quadros real nem uma aceleração percentual. Debug e release não são comparáveis pelo tamanho de main.dart.js isoladamente: o debug usa vários módulos adicionais. Os testes comprovam a eliminação de trabalho fora do viewport e de animação ociosa, sem estabelecer um benchmark de dispositivo ou da API de produção.

Verificação final deste ajuste: build release da entrada de produção também aprovado com API_BASE_URL=/api/v1/. Prévia release substituiu o processo debug em localhost:8080; HTML/JavaScript responderam HTTP 200, CanvasKit local com application/wasm, compressão gzip e revalidação ETag retornando 304. Analyze sem problemas e verificação de arquivos publicáveis aprovada. Nenhum deploy ou acesso ao banco de produção foi feito.

## Revisão de alinhamento e dimensões — 16/11/2026

A revisão dos nove casos relatados passou a usar EqualHeightGrid: mede a altura natural na largura disponível e iguala as células, preservando atualização de layout quando o conteúdo muda. Não usa IntrinsicHeight em gráficos/LayoutBuilder nem alturas fixas por página. A segunda passagem mantém a altura máxima aberta, para que texto animado e validações não fiquem presos a uma medida anterior.

- Todas as grades de KPIs têm alturas uniformes, inclusive entre linhas; valores longos cabem sem quebra, rótulos aceitam duas linhas e textos auxiliares mantêm seu espaço.
- Todos os pares de TwoColumnLayout alinham topo e base no desktop, mantendo as proporções de largura; no mobile empilham com espaçamento. O par de informações do perfil/acesso institucional usa a mesma regra. Cards da listagem de linhas também compartilham altura e espaçamento.
- Insights: hero ocupa a largura do conteúdo, observações ficam em duas colunas no desktop e uma no mobile. Os dois cartões da demonstração aparecem lado a lado e com a mesma altura.
- Assistente: título, hero e estado da integração ocupam a largura disponível; entrada com bordas arredondadas inclusive desabilitada, margens coerentes com o conteúdo e espaço reservado acima do dock para evitar sobreposição.
- Usuários: intervalo de 16 px entre cards, espaçamento nos campos do diálogo e ação de criação com largura natural.

Validação: analyze sem problemas; suíte completa com 31 testes aprovada, mais um teste visual dedicado aprovado para os nove casos com dados da demonstração (32 testes verificados). As 78 capturas gerais foram atualizadas em 390/768/1440/1920 px e foram geradas nove capturas adicionais, incluindo as áreas roladas de Operação, Passageiros e Perfil. Verificações medem igualdade das alturas, texto ampliado em 1,5x, ausência de corte no tablet, margens/larguras do Assistente, chat separado do dock, duas colunas dos Insights e 16 px entre os usuários. Exemplos revisados em screenshots/forest-layout-*.png. Build release da demonstração aprovado e servido pelo mesmo localhost:8080. Nenhuma alteração de dados ou deploy de produção foi executada.
