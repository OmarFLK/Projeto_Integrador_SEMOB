# Publicar o SEMOB: Neon + MongoDB Atlas + Render + Vercel

Atualizado em 15/10/2026. A migração está implementada no código. As etapas abaixo são executadas nas suas contas; nenhum recurso de nuvem foi criado automaticamente.

## 1. Como os serviços ficam conectados

```mermaid
flowchart LR
  Usuario[Navegador] --> Front[Flutter Web na Vercel]
  Front -->|/api/v1 via proxy HTTPS| API[API Dart no Render]
  API --> Neon[(PostgreSQL Neon: identidade SEMOB)]
  API --> Atlas[(MongoDB Atlas: transporte e fontes)]
  API -->|HTTPS e credencial de servidor| IA[API da IA já publicada]
```

| Serviço | Conteúdo |
|---|---|
| Neon, banco `semob_users` | Usuários, hashes de senha, sessões, recuperação, preferências, auditoria e migrações |
| Atlas, banco `semob_data` | Transporte, lotes, fontes e tabelas originais dos HTMLs |
| Render | API autenticada; sem disco de usuários |
| Vercel | Arquivos do Flutter e proxy `/api/` para o Render |
| Outra IA | Continua com seu backend, banco e frontend atuais; SEMOB chama a API dela |

Use banco/credenciais próprios do SEMOB no Neon. O banco da outra IA não precisa ser compartilhado. O MongoDB atende ao requisito de banco não relacional. CSV serve para importar/exportar e também tem sua procedência preservada no MongoDB.

## 2. Preparar o repositório e as ferramentas

É necessário Flutter/Dart (ambiente validado: Flutter 3.47.7, Dart 3.13.5), Git e, para publicar a pasta estática pelo terminal, Node.js/npm e a CLI da Vercel. Docker é opcional para desenvolvimento local. Os comandos desta página usam PowerShell na raiz do repositório, salvo indicação contrária.

```powershell
flutter pub get --enforce-lockfile
Push-Location backend
dart pub get --enforce-lockfile
Pop-Location
```

No Windows, `flutter pub get` pode pedir Modo de Desenvolvedor para criar links dos plugins. Ative essa opção nas configurações do Windows se necessário. O script `scripts/tools.ps1` encontra o SDK em `FLUTTER_ROOT`, no PATH ou em `~/development/flutter`.

O GitHub recebe código, documentação, fontes tipográficas/licenças, scripts, lockfiles e configurações sem segredos. **Não envie os relatórios, ZIPs, CSVs, bancos, backups, `.env` ou chaves.** Toda a pasta `backend/data/` fica ignorada no Git e excluída do contexto Docker. `.env.example` contém apenas nomes de variáveis e placeholders para orientar a configuração. O CI executa `scripts/verify_publishable.ps1` para recusar arquivos privados conhecidos no índice.

## 3. Criar o PostgreSQL no Neon

1. Crie um projeto Neon para o SEMOB, preferencialmente na região próxima ao backend.
2. Crie o banco `semob_users` e um papel próprio para ele. Pode usar o banco padrão do projeto dedicado, desde que o mesmo nome conste nas duas URLs.
3. Em **Connect**, copie duas URLs do mesmo banco/papel: com pooling habilitado e com pooling desabilitado.
4. A URL com `-pooler` no host será `DATABASE_URL`; a direta será `DIRECT_DATABASE_URL` para migrações e backups.
5. Use `sslmode=verify-full`. Se a URL copiada incluir `channel_binding=require`, remova **apenas esse parâmetro**: o driver Dart atual usa SCRAM-SHA-256 e não implementa SCRAM-SHA-256-PLUS. A aplicação rejeita essa opção explicitamente e verifica o certificado e o host em conexões remotas. Caso sua política exija channel binding, será necessário trocar/adaptar o driver antes de publicar.

Formatos ilustrativos, sem credenciais reais:

```text
DATABASE_URL=postgresql://USUARIO:SENHA@ep-SEU-ENDPOINT-pooler.REGIAO.aws.neon.tech/semob_users?sslmode=verify-full
DIRECT_DATABASE_URL=postgresql://USUARIO:SENHA@ep-SEU-ENDPOINT.REGIAO.aws.neon.tech/semob_users?sslmode=verify-full
```

Copie a URL fornecida pelo Neon e mantenha o escape de caracteres especiais da senha. Não coloque a URL no frontend, no Git ou em capturas de tela. O pool da aplicação usa até 5 conexões por processo por padrão; `max_connection_count` na URL permite ajustar isso após medir carga. O timeout de conexão padrão é 30 segundos, incluindo o despertar do banco.

O Neon fornece pooling transacional com PgBouncer. As operações críticas e o bloqueio usado nas migrações ficam dentro de transações. Veja [pooling do Neon](https://neon.com/docs/connect/connection-pooling) e [driver PostgreSQL Dart](https://pub.dev/packages/postgres).

## 4. Criar o esquema ou transferir o SQLite

Faça esta etapa **antes de iniciar o novo backend**, especialmente se tiver usuários reais no SQLite. A API cria o administrador inicial quando encontra o banco vazio; a transferência recusa um destino já preenchido para preservar contas existentes.

Abra um terminal local, configure as URLs como variáveis do processo e rode o migrador. `Read-Host` evita gravar os valores diretamente no histórico; a entrada da URL continua visível no terminal. Use um terminal privado. Arquivos `.env` não são carregados automaticamente pelo Dart.

```powershell
$env:DATABASE_URL = Read-Host 'URL pooled do Neon'
$env:DIRECT_DATABASE_URL = Read-Host 'URL direta do mesmo banco Neon'
Push-Location backend
# Cria/verifica as tabelas e mostra se o banco está vazio; não cria contas.
dart run bin/migrate.dart
if ($LASTEXITCODE -ne 0) { throw 'Corrija a conexão antes de continuar.' }
Pop-Location
```

Se existir um `backend/data/users.sqlite` com a autenticação real implementada anteriormente:

1. Pare a API antiga e mantenha o arquivo original e eventuais arquivos `-wal`/`-shm` juntos. Não apague a origem.
2. Mantenha a configuração do Neon no terminal e execute:

```powershell
Push-Location backend
dart run bin/migrate.dart --sqlite data/users.sqlite
if ($LASTEXITCODE -ne 0) { throw 'Não inicie a nova API enquanto a transferência falhar.' }
Pop-Location
```

O comando abre a origem somente para leitura, transfere as cinco tabelas de identidade numa transação, compara todos os registros transferidos e ajusta a sequência da auditoria. Preserva IDs, hashes, sessões, recuperação e preferências. A saída informa as contagens e `alreadyImported`; repetir a mesma origem não duplica dados. Se houver erro, os registros inseridos são revertidos. O esquema versionado criado antes da transferência pode permanecer vazio.

O antigo `semob.db` da demonstração não possui hashes compatíveis e não é a origem deste migrador. Se só houver esse banco ou nenhum `users.sqlite`, comece com banco novo e crie contas reais pelo administrador. Os relatórios de transporte serão reconstruídos do ZIP, independentemente dessa transferência. A implementação não encontrou um `backend/data/users.sqlite` real para enviar automaticamente ao Neon.

As migrações versionadas estão em `backend/lib/identity_migrations.dart`, com versão/checksum registrados em `schema_migrations`. Novas mudanças recebem versões novas; não edite uma versão já aplicada.

## 5. Criar o banco de transporte no MongoDB Atlas

1. Crie um cluster/projeto Atlas para o SEMOB.
2. Crie um usuário de aplicação com permissão `readWrite` somente em `semob_data`.
3. Em **Connect → Drivers**, obtenha a URI e inclua `semob_data` no caminho. Preserve as opções de autenticação fornecidas pelo Atlas, normalmente `authSource=admin` para o usuário criado no painel.
4. Em **Network Access**, permita os IPs de saída do serviço Render. Para importações/backup pelo seu computador, permita também seu IP atual. As listas de acesso precisam conter a origem que realmente fará a conexão. [Documentação Atlas](https://www.mongodb.com/docs/atlas/security/ip-access-list/).

```text
SEMOB_MONGODB_URI=mongodb+srv://USUARIO:SENHA@SEU-CLUSTER.mongodb.net/semob_data?authSource=admin&retryWrites=true&w=majority
```

As credenciais ficam apenas no backend/terminal de administração. Sembast continua disponível para desenvolvimento; o servidor exige MongoDB em `SEMOB_ENV=production`, pois arquivos locais da hospedagem são efêmeros.

Antes do primeiro deploy, coloque o ZIP original **apenas na sua máquina** em `backend/data/semob_transport_reports.zip` (ou informe outro caminho ao importador). Essa pasta é privada e não vem num clone do GitHub. Para carregar os HTMLs diretamente no Atlas e produzir os CSVs locais:

```powershell
$env:SEMOB_MONGODB_URI = Read-Host 'URI do Atlas com banco semob_data'
Push-Location backend
dart run bin/import_data.dart data/semob_transport_reports.zip data/exports
if ($LASTEXITCODE -ne 0) { throw 'Confira o Atlas e a importação antes de publicar.' }
Pop-Location
```

O resultado esperado do ZIP original é **44 HTMLs, 55 tabelas originais e 91.108 viagens**. Os CSVs ficam em `backend/data/exports/`, além dos documentos gravados no Atlas. **Conclua a importação antes de iniciar o serviço no Render**: a imagem Docker não contém dados. `/ready` permanece indisponível enquanto o MongoDB não tiver uma geração ativa. Em desenvolvimento, a API pode importar automaticamente o ZIP privado quando ele existe no disco local.

Se já houver lotes novos no banco documental atual, transfira um backup com `restore_data.dart` em vez de depender apenas do ZIP inicial. O ZIP contém somente os relatórios originais; novos uploads precisam acompanhar a migração. Veja a etapa de backup abaixo.

## 6. Publicar o backend no Render

Crie um **Web Service** a partir do repositório GitHub:

| Campo | Valor |
|---|---|
| Language/Runtime | Docker |
| Root Directory | `backend` |
| Dockerfile Path | `./Dockerfile` |
| Docker Build Context | `.` dentro de `backend` |
| Health Check Path | `/ready` |
| Região | Próxima dos bancos |
| Disco persistente | Dispensado com Neon + Atlas |

O Dockerfile compila o executável, inclui as fontes tipográficas e roda como usuário sem privilégios. Os relatórios ficam no Atlas, fora do Git e da imagem. Não configure um comando `dart run` no container final: ele contém o bundle compilado. A aplicação lê `PORT` fornecida pelo Render e escuta em `0.0.0.0`. Confira [Docker no Render](https://render.com/docs/docker) e [health checks](https://render.com/docs/health-checks).

Configure no painel **Environment**:

| Variável | Valor |
|---|---|
| `SEMOB_ENV` | `production` |
| `SEMOB_HOST` | `0.0.0.0` |
| `DATABASE_URL` | URL pooled do Neon |
| `DIRECT_DATABASE_URL` | URL direta do mesmo banco, usada nas migrações automáticas |
| `SEMOB_MONGODB_URI` | URI do Atlas, banco `semob_data` |
| `SEMOB_ALLOWED_ORIGINS` | `https://SEU-PORTAL.vercel.app` ou domínio próprio, sem barra final |
| `SEMOB_ADMIN_EMAIL` | E-mail do administrador inicial |
| `SEMOB_ADMIN_PASSWORD` | Senha inicial com 12–256 caracteres; necessária somente se o banco está vazio |

Se ainda não sabe a URL da Vercel, crie o projeto dela para reservar o nome ou use o domínio definitivo planejado. Corrija a origem após a publicação antes de testar login. Não use `*`. Mais de uma origem pode ser separada por vírgulas, sempre com HTTPS e sem barra final.

Se usuários foram transferidos, as senhas preservadas continuam valendo. A senha de bootstrap não altera uma conta existente. Após criar o administrador, remova `SEMOB_ADMIN_PASSWORD` do painel e reinicie para verificar a conexão com o banco já persistido.

No primeiro deploy, consulte os logs e acesse:

```powershell
Invoke-RestMethod https://SEU-BACKEND.onrender.com/health
Invoke-RestMethod https://SEU-BACKEND.onrender.com/ready
```

`/health` confirma o processo; `/ready` deve retornar `status: ok`, `identity: postgresql` e `data: mongodb`. O health check utiliza `/ready` para exigir os bancos e a geração de dados. O acesso aos dados de negócio continua exigindo login.

## 7. Publicar o frontend na Vercel com proxy da API

O script abaixo compila com `API_BASE_URL=/api/v1/` e gera `build/web/vercel.json` encaminhando `/api/` ao Render. Assim, o navegador usa a origem do portal para as chamadas e o cookie de sessão; isso evita depender de cookies entre domínios de hospedagens diferentes. [Rewrites externos na Vercel](https://vercel.com/docs/routing/rewrites).

Na raiz do repositório:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare_web.ps1 -ApiOrigin https://SEU-BACKEND.onrender.com
npm install --global vercel
vercel login
Push-Location build/web
vercel --prod
Pop-Location
```

Na primeira publicação, selecione sua conta e crie/vincule um projeto dedicado ao SEMOB. Se a CLI perguntar, use o diretório atual (`.`), framework **Other**, sem comando de build/install e saída `.`; o Flutter já foi compilado. A configuração gerada também informa esses valores. Não publique a raiz do repositório como se ela fosse o site estático.

Anote o domínio estável do projeto, como `https://semob-portal.vercel.app`. Atualize `SEMOB_ALLOWED_ORIGINS` no Render com esse domínio e aplique o redeploy. Não use a URL variável de cada preview como domínio de produção. Consulte a [CLI de deploy da Vercel](https://vercel.com/docs/cli/deploy).

Para cada atualização do frontend, rode novamente `prepare_web.ps1` e `vercel --prod` dentro de `build/web`. O build pode limpar a pasta; o script recria o proxy depois de compilar. Esse fluxo publica os arquivos prontos pelo terminal; push no GitHub, por si só, não reconstrói esse projeto Vercel. Não há SDK Flutter configurado no build remoto da Vercel.

Em Windows/Android nativos, use URL HTTPS absoluta em `API_BASE_URL` ao compilar; a URL relativa deste script é específica do navegador. Em outras hospedagens estáticas, configure proxy equivalente ou use domínio comum para API e portal. `deploy/nginx.conf` é uma referência para infraestrutura própria.

## 8. Ligar a IA que já existe

No Render, configure:

```text
SEMOB_AI_URL=https://BACKEND-DA-OUTRA-IA/ROTA-EXATA
SEMOB_AI_API_KEY=SEGREDO_SE_A_API_EXIGIR
SEMOB_AI_REQUEST_FIELD=message
SEMOB_AI_RESPONSE_FIELD=answer
```

A ponte envia `message` e `context` com período, filtros, cobertura, insights e fontes; espera `{"answer":"texto"}`. Autenticação opcional usa `Authorization: Bearer ...`, somente entre servidores. Os nomes dos campos principais são configuráveis. Não informe a URL da página Vercel da IA: precisa ser a rota de API do backend que executa a versão desejada, normal ou RAG/fine-tuning.

**Ainda falta confirmar o contrato da IA real.** Se ela exigir sessão própria, campos extras, streaming ou outro formato, o adaptador precisará ser ajustado. A outra IA continua usando o Neon dela. A ponte não compartilha senhas, cadastros de usuários ou o banco de identidade. Não houve chamada ao endpoint real porque a URL/contrato ainda não foram fornecidos. Pode disponibilizar o código em `integrations/ia` para análise; essa pasta está ignorada no Git.

Para recuperação por e-mail, configure `SEMOB_RECOVERY_WEBHOOK` e, se necessário, `SEMOB_RECOVERY_WEBHOOK_KEY`. O serviço recebe `{email,code,expiresInMinutes}` e precisa enviar o e-mail e retornar JSON de sucesso. Sem esse serviço, a interface informa que a recuperação está indisponível. Não habilite `SEMOB_EXPOSE_RECOVERY_CODE` em produção; o servidor recusa essa exposição.

## 9. Backup, restauração e atualizações

Configure as URLs do Neon e a URI do Atlas no terminal antes dos comandos. Para Sembast local, pare a API antes de usar um CLI no mesmo arquivo. Um backup conjunto deve ser feito em janela sem alterações administrativas/importações: os dois bancos não compartilham uma transação.

```powershell
Push-Location backend
dart run bin/backup.dart data/backups/pre-deploy-2026-10-15
Pop-Location
```

A pasta deve ser nova. Contém `identity.json.gz` (snapshot transacional PostgreSQL com hashes/sessões e checksum) e `transport.json.gz` (geração ativa do banco documental com checksum). Trate o backup como sensível e mantenha cópia protegida fora da hospedagem. Agende backups e monitore o sucesso; o script sozinho não cria um agendamento.

Para restaurar, use primeiro bancos de homologação novos, configure suas URLs e mantenha a API de destino parada:

```powershell
Push-Location backend
dart run bin/migrate.dart --restore data/backups/pre-deploy-2026-10-15/identity.json.gz
if ($LASTEXITCODE -ne 0) { throw 'Falha ao restaurar identidade.' }
dart run bin/restore_data.dart data/backups/pre-deploy-2026-10-15/transport.json.gz
if ($LASTEXITCODE -ne 0) { throw 'Falha ao restaurar transporte.' }
Pop-Location
```

O restore de identidade exige destino vazio ou a mesma origem já registrada; não substitui usuários existentes. O restore de transporte publica uma nova geração e não altera usuários. O backup de identidade contém dados da aplicação, não papéis/permissões do servidor PostgreSQL. Para backup completo administrativo e recuperação do provedor, consulte [backup no Neon com pg_dump](https://neon.com/docs/manage/backup-pg-dump), usando conexão direta e um cliente compatível com a versão do servidor.

Antes de atualizar produção: gere backup, valide em homologação e mantenha a versão anterior do backend/frontend disponível. Reverter o código não desfaz migrações de esquema nem novas gravações. Use migrações compatíveis e restauração previamente ensaiada. Snapshots de transporte anteriores são retidos; defina retenção conforme o volume para controlar o crescimento no Atlas.

## 10. Desenvolvimento local e testes

Para um ambiente completo local:

```powershell
Copy-Item .env.example .env
# Edite .env e preencha POSTGRES_PASSWORD, MONGO_ROOT_PASSWORD,
# MONGO_APP_PASSWORD e SEMOB_ADMIN_PASSWORD; use senhas URL-safe no Compose.
docker compose up --build
```

O Compose usa seu PostgreSQL e MongoDB locais, independentemente das URLs Neon/Atlas do exemplo. O Postgres só é publicado em `127.0.0.1:55432`; Mongo não é exposto ao host. Os bancos ficam em volumes próprios. Não rode `down -v` se quiser preservar os dados. O Compose não publica o frontend; rode Flutter local com `API_BASE_URL=http://127.0.0.1:8081/api/v1/`.

Para executar Dart diretamente com PostgreSQL local ou Neon de desenvolvimento:

```powershell
$env:DATABASE_URL = Read-Host 'URL PostgreSQL de desenvolvimento'
# Configure DIRECT_DATABASE_URL apenas se corresponder ao mesmo ambiente.
powershell -ExecutionPolicy Bypass -File .\scripts\run_local.ps1
```

O script verifica as migrações e só pede a senha inicial se o banco estiver vazio. Não reutilize credenciais de produção em testes. Para testar a identidade, `SEMOB_TEST_DATABASE_URL` deve apontar para um servidor **de testes** com permissão `CREATEDB`. A suíte cria/remove somente bancos `semob_test_*` próprios. Exemplo com o PostgreSQL do Compose:

```powershell
# Faça isto antes de docker compose up se quiser só subir os bancos.
docker compose up -d postgres mongo
$semobTestPassword = Read-Host 'POSTGRES_PASSWORD local (URL-safe)'
$env:SEMOB_TEST_DATABASE_URL = "postgresql://semob:${semobTestPassword}@127.0.0.1:55432/postgres?sslmode=disable"
Push-Location backend
dart analyze
dart test
dart build cli --target bin/server.dart
Pop-Location
flutter analyze --no-pub
flutter test --no-pub
```

O teste MongoDB real requer `SEMOB_TEST_MONGODB_URI` e fica explicitamente ignorado sem essa variável. O CI fornece PostgreSQL e MongoDB e usa somente dados sintéticos criados pelos testes. A validação completa dos 44 HTMLs roda quando o ZIP privado está disponível localmente; pode indicar outro caminho por `SEMOB_TEST_DATA_ARCHIVE`. Sem esse arquivo, apenas esse teste é explicitamente ignorado. As credenciais Neon/Atlas reais ainda precisam ser testadas em homologação.

## 11. Conferência antes de liberar aos usuários

- [ ] PostgreSQL Neon e Atlas provisionados, migração/importação sem erros e `/ready` com os dois bancos corretos.
- [ ] Login com conta real, persistência após reload, logout e permissões de operador/analista/gestor/administrador.
- [ ] Conta criada permanece após redeploy do Render; desativação e troca de perfil revogam sessões.
- [ ] Períodos/cobertura, filtros, viagens além da página 30.000, CSV/PDF e upload de novo lote conferidos.
- [ ] IA real conectada à rota escolhida e recuperação recebida por e-mail, se essas funções fizerem parte da liberação.
- [ ] Frontend com proxy real, HTTPS e origem exata autorizada; sem placeholders publicados.
- [ ] Backup fora dos serviços principais, restauração ensaiada e retenção/alertas definidos.
- [ ] Pipeline remoto e imagem Linux aprovados; carga/capacidade verificadas no plano escolhido.

As pendências atuais de produção estão também em [AUDITORIA_E_CHECKLIST_DEPLOY.md](AUDITORIA_E_CHECKLIST_DEPLOY.md). A configuração das contas de nuvem, o contrato da IA e o serviço de e-mail continuam dependendo dos serviços reais da equipe.
