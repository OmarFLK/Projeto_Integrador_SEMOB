# Frontend SEMOB — implementação atual

Atualização: 15/10/2026. Flutter/Riverpod/go_router/Dio. A documentação de operação e deploy está em [IMPLEMENTACAO_E_DEPLOY.md](IMPLEMENTACAO_E_DEPLOY.md).

## Sessão e permissões

`AuthController` chama `AuthRepository`; a implementação padrão usa a API. Não há credencial fixa no aplicativo. Na web, o servidor emite cookie HttpOnly e o cliente envia credenciais nas chamadas; o token da resposta fica apenas em memória. Ao recarregar, `/auth/me` restaura a sessão pelo cookie. Aplicativos nativos usam token em memória e precisam entrar novamente após fechar o processo.

Rotas e navegação respeitam as permissões do usuário autenticado. O servidor também valida cada ação. Login inválido, indisponibilidade, expiração e recuperação de senha possuem estados de interface. O perfil e a barra superior mostram a conta real.

## Telas

| Rota | Comportamento |
|---|---|
| `/dashboard` | Totais calculados, gráficos e cobertura de passageiros |
| `/operation` | Programadas/realizadas, km, veículos e dias com diferença |
| `/trips` | Paginação remota de 50 itens, busca, status, ordenação e filtros combinados |
| `/passengers` | Totais por categoria, gráficos e aviso de cobertura/provisoriedade |
| `/lines`, `/lines/:code` | Consolidação, participação no volume, evolução diária e ocorrências reais |
| `/fleet`, `/fleet/:prefix` | Prefixos, km, linhas atendidas e histórico consultado pelo veículo |
| `/financial` | Créditos/saldos calculados; valores ausentes sinalizados |
| `/anomalies` | Contagens do recorte, níveis e ocorrências das fontes |
| `/insights` | Descrições calculadas pela API sobre o período |
| `/assistant` | Chamada à IA externa ou indicação explícita de conexão pendente |
| `/reports` | CSV/PDF, visualização, modelos e importação ZIP/CSV conforme perfil |
| `/users` | Cadastro, edição de perfil funcional, permissões e ativação/desativação |
| `/profile` | Identidade, permissões e logout |
| `/settings` | Modo compacto persistido no backend e aplicado ao espaçamento |
| `/help` | Orientações sobre fontes, cobertura, importação e acesso |

Os filtros são carregados pela API. Operação, passageiros e financeiro usam o período; linhas e anomalias também oferecem linha; viagens/frota oferecem linha, veículo, sentido e faixa. Os controles não prometem relações ausentes nas fontes. Relatórios e IA usam o contexto de período correspondente.

## Estado e erros

Providers dependem do período/filtros e da identidade, evitando compartilhar dados de uma conta com outra. Viagens usa um provider de páginas com chave de consulta estável e busca com debounce. Detalhes não dependem da primeira página global. Após importação, os providers são invalidados para recarregar o novo lote.

Campos e datas vêm da API; textos fixos de agosto e percentuais demonstrativos foram removidos. Gráficos protegem os intervalos quando todos os valores são zero. Coleções sem registros mostram estado vazio. As exportações tratam erros JSON mesmo quando a resposta esperada é binária.

## Layout e validação

Mobile abaixo de 720 px, tablet até 1179 px, desktop a partir de 1180 px. Navegação adaptativa, tabelas com rolagem horizontal e cards de viagens no mobile. Noto Sans é incluída no bundle e usada também nos PDFs, com licença em `backend/assets/fonts/OFL.txt`.

Os testes usam uma implementação de autenticação e adaptador HTTP isolados **somente em `test/`**, exercitando o cliente/repositório real do frontend. Cobrem login, dashboard, todas as rotas nas três larguras, paginação/filtros remotos e bloqueio por perfil. A integração externa de IA exige validação adicional contra o serviço real quando seu contrato estiver disponível.
