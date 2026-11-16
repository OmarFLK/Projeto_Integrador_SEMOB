# SEMOB 2.0 — Forest Intelligence

Reformulação local da interface e recuperação de acesso com aprovação administrativa. A aplicação continua em Flutter/Dart, com Shelf, PostgreSQL/Neon e MongoDB/Atlas. Não houve publicação nem alteração de banco de produção.

## Interface

A paleta combina floresta `#0F1F17` / `#1E3A2E`, oliva `#3E5A3F` / `#3D4337`, sálvia `#6B7F67` / `#789575`, marfim `#E5E8CE` / `#C7CBB8` e acento `#CBEA65`. Cores semânticas preservam atenção, erro e informação. Tokens estão em `lib/core/theme/`.

- Menu flutuante com rail de 76 px e expansão para 264 px por mouse, foco ou clique. Expansão temporária sobrepõe o conteúdo; fixação reserva a largura. Escape fecha a expansão temporária.
- Grupos de navegação declarativos, filtrados pelas permissões. Topo com breadcrumb, período, atualização, aparência e perfil. Destinos contextuais dentro do grupo e subabas representadas na URL.
- Claro, escuro e sistema permanecem selecionáveis. `sidebarPinned` e `reduceMotion` são preferências por conta. Redução de movimento do dispositivo também é respeitada.
- Cards com profundidade, gradientes, estados de hover e entrada escalonada. KPIs numéricos têm contagem com formato pt-BR.
- Linhas/áreas, barras, barras empilhadas e donuts usam dados reais da API. Legendas interativas, tooltips, ampliação e exploração por setas no teclado. Lacunas numéricas entre dias não são ligadas como observações contínuas.
- Filtros multidimensionais recolhíveis, chips removíveis e controle de período compacto. Tabelas preservam paginação e consultas no servidor. Viagens abre detalhes do registro e links para linha/veículo. Investigar ocorrência aplica linha/veículo ao abrir viagens.
- Login com fotografia institucional integrada, painel elevado e novos estados. Assistente com entrada fixa, perguntas sugeridas quando a integração estiver disponível e respostas/fontes reais. Ajuda com busca local.

O crédito secundário de produto fica desativado. Se houver autorização institucional, o build pode receber `--dart-define=SEMOB_PRODUCT_CREDIT="Seu crédito"`. Isso não troca a marca SEMOB.

## Rotas e preservação

| Rota existente | Composição / navegação atual |
|---|---|
| `/login` | Login institucional e escolha das opções de recuperação disponíveis |
| `/dashboard` | Hero, cumprimento, KPIs, passageiros, distribuição, viagens, km e linhas |
| `/dashboard?view=indicators` | Indicadores completos, incluindo pagantes, não pagantes e km produtivo |
| `/dashboard?view=lines` | Consolidação e participação por linha |
| `/operation` | Desempenho, indicadores e dias de divergência |
| `/operation?view=trips` | Comparação de viagens e veículos empregados |
| `/operation?view=kilometres` | Quilometragem e dias de atenção |
| `/trips` | Busca, ordenação, filtros, detalhe, paginação de 50 itens e exportação |
| `/passengers` | Resumo da demanda e bilhetagem |
| `/passengers?view=composition` | Composição empilhada |
| `/passengers?view=evolution` | Evolução e destaques |
| `/lines`, `/lines/:code` | Busca, ordenação por viagens e histórico detalhado |
| `/fleet`, `/fleet/:prefix` | Consulta de prefixos, linhas e atividades históricas |
| `/financial` | Créditos, saldo e evolução com cobertura explícita |
| `/financial?view=movements` | Indicadores e tabela de movimentações |
| `/anomalies` | Exceções, níveis da fonte e investigação com filtros |
| `/insights` | Observações calculadas pela API e acesso à IA conforme permissão |
| `/assistant` | Conversa e integração institucional existente |
| `/reports` | Catálogo, visualização e CSV/PDF |
| `/reports?view=import` | Importação e modelos, somente para perfis autorizados |
| `/users` | Contas, papéis, status, criação e edição |
| `/profile` | Foto, dados, credenciais e sessões |
| `/settings` | Aparência, movimento, fixação, chat, IA, contexto e privacidade |
| `/help` | Orientações pesquisáveis |
| `/access-requests` **nova** | Fila administrativa de recuperação |

Links antigos continuam válidos. Subabas inválidas voltam ao resumo. Voltar/avançar e recarga usam o estado da URL. No mobile, Mais contém todos os destinos autorizados. O servidor continua validando permissões independentemente do menu.

## Recuperação manual

1. A pessoa abre Esqueci minha senha, informa nome, acesso e uma nova senha proposta.
2. A API calcula PBKDF2-HMAC-SHA256 pelo método existente, com 600.000 iterações e salt aleatório. A senha não é gravada aberta nem enviada ao e-mail administrativo.
3. O pedido fica pendente. A resposta pública é genérica, com protocolo opaco, inclusive para acesso não localizado. A senha atual permanece válida.
4. Um administrador confere a identidade por um canal previamente conhecido e aprova ou rejeita em `/access-requests`.
5. Ao aprovar, uma transação aplica somente o hash na conta ativa vinculada, revoga sessões/desafios anteriores, cancela propostas concorrentes, elimina hashes propostos e grava auditoria sem segredos.

Pedidos expiram em 24 horas por padrão. A API saneia pedidos expirados na inicialização e de hora em hora; listagem e operações administrativas também saneiam. Metadados de pedidos encerrados são retidos por até 30 dias; a limpeza efetiva ocorre na próxima execução do saneamento. A aprovação sempre confere validade e uso único, mesmo antes da limpeza.

O fluxo anterior por código continua disponível quando `SEMOB_RECOVERY_WEBHOOK` estiver configurado. O novo webhook administrativo é separado e não envia códigos ao titular.

### Variáveis do servidor

| Variável | Padrão / função |
|---|---|
| `SEMOB_MANUAL_RECOVERY_ENABLED` | `true`; `false` desativa novos pedidos manuais |
| `SEMOB_MANUAL_RECOVERY_HOURS` | `24`; limitado entre 1 e 72 horas |
| `SEMOB_RECOVERY_ADMIN_EMAIL` | `omarsalibaescola@gmail.com` |
| `SEMOB_RECOVERY_ADMIN_WEBHOOK` | Opcional; recebe os avisos administrativos |
| `SEMOB_RECOVERY_ADMIN_WEBHOOK_KEY` | Opcional; Bearer usado somente pelo backend |

Em produção o webhook precisa de HTTPS. O notificador deve efetivamente encaminhar a mensagem e retornar JSON de sucesso, por exemplo `{ "ok": true }`. O backend envia:

```json
{
  "to": "omarsalibaescola@gmail.com",
  "subject": "SEMOB | Solicitação de recuperação de acesso",
  "requestId": "ID opaco",
  "declaredName": "Nome declarado pelo solicitante",
  "identifier": "Acesso informado",
  "createdAt": "data UTC em ISO 8601",
  "status": "pending"
}
```

O aviso não contém senha, hash ou credencial de sessão. Sem serviço configurado, a fila funciona e o painel informa que não há avisos automáticos. Uma falha no notificador mantém o pedido; não é apresentada como envio bem-sucedido. Nenhum provedor externo foi configurado ou contratado nesta implementação.

### Ferramenta administrativa e SQL para o Neon

Quando nenhum administrador consegue entrar no portal, um operador autorizado do banco pode revisar os pedidos pelo terminal. Configure `DIRECT_DATABASE_URL` ou `DATABASE_URL` no processo e execute a partir de `backend/`:

```powershell
dart run bin/manual_recovery.dart list --status=pending
dart run bin/manual_recovery.dart inspect --id=ID_DO_PEDIDO
dart run bin/manual_recovery.dart approve --id=ID_DO_PEDIDO --identity-verified --dry-run
```

O dry-run somente lê e mostra o estado; não aplica a senha nem migra o banco. Depois da conferência da identidade, escolha uma das opções:

```powershell
# Aplicar pela conexão administrativa:
dart run bin/manual_recovery.dart approve --id=ID_DO_PEDIDO --identity-verified

# Ou gerar uma transação para revisar e executar manualmente no SQL Editor do Neon:
dart run bin/manual_recovery.dart sql --id=ID_DO_PEDIDO --identity-verified

# Rejeitar ou sanear:
dart run bin/manual_recovery.dart reject --id=ID_DO_PEDIDO
dart run bin/manual_recovery.dart cleanup
```

Não é necessário fornecer a senha proposta ao script: ele usa a proposta protegida no banco. O SQL gerado contém o ID, lê o hash na tabela e exige conta ativa, pedido pendente e não expirado. É uma única instrução transacional com bloqueios e conferência da quantidade alterada. Gerar o SQL não aplica a alteração. Não compartilhe credenciais do Neon com solicitantes.

### Migração e backup

A migração **3** adiciona `manual_recovery_requests`; as migrações 1 e 2 não foram reescritas. O startup existente aplica as migrações, ou elas podem ser aplicadas explicitamente por `dart run bin/migrate.dart`. A ferramenta administrativa exige o esquema já atualizado e não migra implicitamente.

O backup lógico passa a `semob-identity-v3`, incluindo pedidos. A restauração de formatos v1/v2 continua aceita e deixa a tabela nova vazia. Backups de identidade seguem sendo privados.

Para publicar depois da revisão: faça backup, atualize a API e aplique a migração 3 antes de publicar o frontend que consulta os novos endpoints. Siga `TUTORIAL_DEPLOY.md` para Render/Vercel e mantenha `API_BASE_URL=/api/v1/` com o proxy existente. Esta entrega não executou esses passos em produção.

## Execução e validação

### Ver a interface sem banco (demonstração local)

Na raiz do repositório, execute:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_preview.ps1
```

Abra **http://127.0.0.1:8080**. Usuário: **`demo@semob.local`** (ou `demo`). Senha: **`SemobDemo2026!`**.

Esse alvo (`tool/preview.dart`) tem dados totalmente sintéticos em memória e uma faixa de demonstração. Não inicia backend, não usa PostgreSQL/MongoDB e não encaminha chamadas para a rede. Filtros, paginação e preferências podem ser explorados. Alterações de aparência/perfil duram apenas até recarregar a página. Envio de arquivos, exportações, mudanças de credenciais, aprovação de recuperação e integração de IA não são executados nesse modo.

Use Ctrl+C no terminal para encerrar. Para outra porta: `-Port 8082`. Para abrir pelo Edge via Flutter: `-Device edge`. A entrada normal `lib/main.dart` continua usando a API real; o modo de demonstração é iniciado somente pelo alvo explícito.

Comando Flutter equivalente:

```powershell
flutter run --no-pub -d web-server --target tool/preview.dart --web-hostname 127.0.0.1 --web-port 8080
```

### Executar com backend e dados reais de desenvolvimento

O comando habitual continua válido:

```powershell
$env:DATABASE_URL = Read-Host 'URL do PostgreSQL de desenvolvimento'
powershell -ExecutionPolicy Bypass -File .\scripts\run_local.ps1
```

As verificações usam os lockfiles existentes. Testes PostgreSQL exigem `SEMOB_TEST_DATABASE_URL` em banco/servidor exclusivo de testes com permissão CREATEDB. Nunca configure produção nessa variável.

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter build web --release --no-pub --dart-define=API_BASE_URL=/api/v1/
cd backend
dart analyze
dart test
dart build cli --target bin/server.dart
```

Para repetir a revisão visual com dados sintéticos exclusivos dos testes:

```powershell
$env:SEMOB_CAPTURE_DIR = '.dart_tool/visual-review'
flutter test --no-pub test/visual_review_test.dart
Remove-Item Env:SEMOB_CAPTURE_DIR
```

As capturas abrangem 18 destinos autenticados, login, menu fixado, temas claro/escuro e larguras 390/768/1440/1920. Os dados mostrados são fixtures de teste; não são novas fontes de produção. Capturas representativas ficam em `screenshots/forest-*.png` após a revisão.

Os resultados desta execução e limitações específicas do ambiente estão em `SEMOB_2_IMPLEMENTACAO.md`. A interface preserva os alvos Windows/Android, mas compilação nativa dessas plataformas e medição de desempenho em hardware real exigem os respectivos ambientes.

### Prévia otimizada e animações

O comando scripts/run_preview.ps1 usa release por padrão: compila uma vez e abre o servidor em http://127.0.0.1:8080. A compilação inicial pode levar alguns segundos; a navegação não usa o modo debug. Para programar com hot reload, acrescente -DebugMode. O servidor atende apenas localhost e encerra com Ctrl+C.

As subabas ficam na cápsula flutuante central inferior. No celular, deslize a cápsula horizontalmente para acessar opções longas. Os cartões descem em sequência e os gráficos animam quando entram na tela ou quando seus dados mudam. Se estiverem estáticos, confira Configurações → Aparência → Reduzir movimento e a preferência de acessibilidade do sistema.
