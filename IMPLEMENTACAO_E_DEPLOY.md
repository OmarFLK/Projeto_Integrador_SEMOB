# Implementação e preparação do deploy

Atualizado em 15/10/2026. O código foi implementado e validado localmente; nenhum serviço de produção foi criado ou publicado nesta etapa.

## Bancos implementados

| Banco | Tecnologia | Responsabilidade |
|---|---|---|
| Gerenciamento | PostgreSQL relacional, local ou Neon, via `DATABASE_URL` | Usuários, matrícula, cargos, papéis, hashes de senha, sessões, recuperação, preferências e auditoria |
| Transporte local | Sembast, banco de documentos não relacional | Desenvolvimento sem serviço adicional; mesmos documentos e regras do adaptador de nuvem |
| Transporte em nuvem | MongoDB, selecionado por `SEMOB_MONGODB_URI` | Documentos normalizados por domínio, fontes, versões e CSVs brutos divididos em partes |

Na execução são usados **dois bancos**: PostgreSQL + Sembast em desenvolvimento **ou** PostgreSQL/Neon + MongoDB em produção. A escolha do banco documental para transporte atende à exigência de NoSQL e permite armazenar fatos de formatos diferentes junto da origem e dos lotes. Consultas agregadas continuam na API. Produção exige MongoDB e não usa arquivos de banco locais.

O adaptador de identidade foi migrado para PostgreSQL: pool assíncrono, TLS com verificação em conexões remotas, transações e bloqueio transacional para bootstrap/proteção do último administrador entre instâncias. O Render não precisa de volume de usuários. O banco Neon do SEMOB fica separado do banco da IA. O pool usa até 5 conexões por processo por padrão; dimensionamento/carga e limites de requisição distribuídos precisam ser avaliados antes de escalar réplicas.

As migrações PostgreSQL estão em `backend/lib/identity_migrations.dart`, são transacionais e registram versão/checksum em `schema_migrations`. `DIRECT_DATABASE_URL` opcional aplica o esquema pela conexão direta do mesmo banco; a API usa `DATABASE_URL` pooled. `bin/migrate.dart --sqlite data/users.sqlite` transfere a identidade real, sem alterar a origem, preserva hashes/sessões/preferências/auditoria, valida cada registro e recusa um destino preenchido. O antigo `semob.db` demonstrativo é preservado e não contém hashes compatíveis. Veja o passo a passo em [TUTORIAL_DEPLOY.md](TUTORIAL_DEPLOY.md).

## Importação e CSVs

```powershell
cd backend
dart run bin/import_data.dart
# Arquivo e pasta de saída opcionais:
dart run bin/import_data.dart data/semob_transport_reports.zip data/exports
```

A rotina gera dez CSVs de fatos, `source_files.csv`, `manifest.json` e `raw/` com as 55 tabelas extraídas dos 44 HTMLs. Tabelas auxiliares não identificadas também ficam preservadas em CSV. Os mesmos CSVs brutos são armazenados como documentos `source_chunks`, em partes menores que o limite de documento MongoDB. O manifesto informa contagens, período, origem da importação e avisos.

Com Sembast, executar os comandos CLI de importação/backup com a API local parada; pela interface, a importação usa a conexão do processo da API. Sembast não deve ter duas aplicações independentes escrevendo no mesmo arquivo. Com MongoDB, a publicação concorrente é controlada pelo ponteiro de geração.

Não há sobrescrita indiscriminada do histórico. Cada fato possui chave determinística, origem e hash. A prioridade privilegia a fonte do próprio mês, depois mensal sobre quinzenal. CSV enviado é uma correção explícita e tem prioridade maior. Novo lote com mesma prioridade atualiza a chave; fatos fora dele permanecem. As tabelas são gravadas sob uma geração nova e a publicação troca um único ponteiro ativo. No MongoDB, a troca exige a geração esperada; importações concorrentes não conseguem publicar sobre uma versão diferente. Versões anteriores são retidas para restauração; planejar retenção conforme o volume antes do uso prolongado.

Os CSVs consolidados em disco incluem proveniência. Na interface, **Baixar dados normalizados** gera as colunas essenciais para edição/reimportação; **Baixar modelo** fornece o cabeçalho. Exportações de relatório usam nomes de campo da API e são destinadas a leitura, não à reimportação direta.

Contrato de CSV: UTF-8, vírgula, aspas para textos com vírgula/quebra de linha, data `AAAA-MM-DD`, ponto decimal e nenhum separador de milhar. Tipos/colunas estão em `backend/lib/dataset_importer.dart`, constante `schemas`. Em `anomalies`, incluir também `kind` (`notCompleted`, `notStarted`, `notFinished`). Valores financeiros ausentes podem ficar vazios; não são inventados como zero. Contagens exigem inteiros não negativos e passageiros precisam fechar a soma das categorias. Importações inconsistentes retornam 400 e não publicam um lote parcial.

Exemplo de passageiros:

```csv
date,turnstile,advance_sales,non_paying,total
2026-10-01,100,20,30,150
```

ZIP: até 25 MB, até 300 HTMLs e 200 MB descompactados. Manter pastas como `Outubro_2026/Mensal/` ou `Outubro_2026/Quinzenal/`. CSV: até 25 MB e 150 mil linhas. O upload é JSON com conteúdo base64; o proxy deve aceitar até 36 MB. PDFs: até 5.000 registros; usar CSV para exportações maiores.

## API e permissões

Prefixo: `/api/v1/`. Listas são JSON; `/trips` e `/datasets/:dataset` retornam `{items,total,offset,limit}`. Limite de página entre 1 e 500.

| Endpoint | Ação |
|---|---|
| `POST /auth/login` | `{identifier,password,remember}` → usuário, token e cookie de sessão |
| `GET /auth/me`, `POST /auth/logout` | Restaurar identidade e revogar sessão |
| `GET/POST /users`, `PATCH /users/:id` | Listar/criar/editar e ativar/desativar contas |
| `GET/PUT /preferences` | Ler/salvar `{compact:bool}` |
| `GET /audit` | Últimos eventos administrativos |
| `GET /periods`, `/options`, `/coverage`, `/meta` | Opções reais, cobertura e situação do lote |
| `GET /operation`, `/passengers`, `/lines`, `/line-history`, `/trips`, `/vehicles`, `/financial`, `/anomalies`, `/insights` | Dados e agregações |
| `POST /imports` | `{filename,dataset,content}`; `dataset` é usado para CSV |
| `GET /templates/:dataset` | Cabeçalho de CSV para importação |
| `GET /normalized/:dataset` | CSV essencial do período para reimportar |
| `GET /datasets/:dataset` | Fatos normalizados dos dez domínios, paginados |
| `GET /exports/:resource?format=csv\|pdf` | Arquivo real, com os filtros da consulta |
| `GET /assistant/status`, `POST /assistant` | Situação da integração e ponte de IA |
| `POST /auth/password-recovery/request` | Solicitar código sem revelar se a conta existe |
| `POST /auth/password-recovery/verify` | Validar código e obter token restrito de redefinição |
| `POST /auth/password-recovery/reset` | `{challengeId,resetToken,password}`; altera senha e revoga sessões |

Filtros: `period=AAAA-MM`, `from`, `to`; viagens/frota também `line`, `vehicle`, `direction`, `timeRange`. Viagens aceita `search`, `status`, `order=asc|desc`, `offset` e `limit`. Linhas e anomalias usam o recorte que suas fontes permitem. Horários e sentidos usam os códigos retornados em `/options`, sem listas fixas no cliente.

| Perfil | Consultar operação | Financeiro / exportar / IA | Importar | Gerenciar usuários |
|---|---|---|---|---|
| Operador | Sim | Não | Não | Não |
| Analista | Sim | Sim | Não | Não |
| Gestor | Sim | Sim | Sim | Não |
| Administrador | Sim | Sim | Sim | Sim |

O servidor protege todas as ações. Desativar uma conta ou alterar seu perfil revoga suas sessões. O último administrador ativo não pode ser removido do papel. Senhas usam PBKDF2-HMAC-SHA256, salt individual e 600 mil iterações; tokens aleatórios de sessão são armazenados por hash. Limites por IP/conta são locais ao processo, adequados à configuração atual de uma instância. Logs de erro não incluem corpos, senhas ou chaves.

Na web, o cookie é HttpOnly; em produção também Secure/SameSite=None. Requisições com cookie que alteram estado exigem `X-Requested-With: SEMOB`, além da origem permitida. Preferir frontend/API no mesmo domínio ou subdomínios do mesmo site para evitar restrições de cookies de terceiros. Aplicativos nativos usam bearer em memória. “Lembrar acesso” mantém a sessão web por até sete dias; a sessão normal dura até oito horas. Não há token guardado em localStorage.

## Ponte para a IA existente

O SEMOB não treina nem replica a IA. O fluxo é **Flutter → backend SEMOB → endpoint existente da outra IA → backend SEMOB → Flutter**.

Configurar no servidor:

```text
SEMOB_AI_URL=https://SEU-BACKEND-IA/ROTA-EXATA
SEMOB_AI_API_KEY=SEGREDO_SE_O_SERVICO_EXIGIR
SEMOB_AI_REQUEST_FIELD=message
SEMOB_AI_RESPONSE_FIELD=answer
```

Contrato inicial do adaptador:

```json
{
  "message": "Qual linha realizou mais viagens?",
  "context": {
    "period": "2026-08",
    "filters": {"period": "2026-08"},
    "coverage": {},
    "insights": [],
    "sources": []
  }
}
```

Resposta esperada: `{"answer":"texto"}`. A chave, quando configurada, vai em `Authorization: Bearer ...` somente entre servidores. Os nomes dos campos principais são configuráveis, mas este contrato é uma proposta até a análise do código/API do outro projeto. Se o serviço tiver rotas separadas para IA normal e RAG/fine-tuning, usar em `SEMOB_AI_URL` a rota escolhida após conferir o contrato. Não presumir que o endpoint de uma delas funciona como o da outra.

O contexto contém agregados e fontes; não contém credenciais, códigos de recuperação, cadastros de usuários ou a tabela de motoristas. Chamadas têm limites e timeout. Sem configuração, o backend retorna 503 e a interface informa a pendência. Erro/contrato incompatível do serviço retorna erro real; não existe fallback de resposta pronta. Para terminar a ligação, basta disponibilizar o outro repositório em `integrations/ia` ou informar a rota e o contrato. O adaptador pode então ser ajustado e testado no endpoint real.

## Recuperação por e-mail

O fluxo de redefinição está implementado e testado. A entrega depende de um serviço externo configurado em `SEMOB_RECOVERY_WEBHOOK` e, se necessário, `SEMOB_RECOVERY_WEBHOOK_KEY`. O webhook recebe `{email,code,expiresInMinutes}` e deve enviar o e-mail, retornando JSON de sucesso. Sem serviço, a interface informa indisponibilidade e orienta procurar a administração. Em desenvolvimento, pode-se habilitar explicitamente `SEMOB_EXPOSE_RECOVERY_CODE=true`; produção recusa essa configuração. Não há serviço de e-mail contratado nesta etapa.

## Preparação para produção

O roteiro operacional completo está em [TUTORIAL_DEPLOY.md](TUTORIAL_DEPLOY.md): criar Neon e Atlas, migrar usuários antes do bootstrap, importar fontes, configurar Docker no Render e publicar Flutter na Vercel com proxy HTTPS.

Variáveis obrigatórias do backend em produção: `DATABASE_URL`, `SEMOB_MONGODB_URI`, `SEMOB_ENV=production` e `SEMOB_ALLOWED_ORIGINS`. Para o primeiro administrador, configure `SEMOB_ADMIN_EMAIL` e `SEMOB_ADMIN_PASSWORD` se o banco estiver vazio. `DIRECT_DATABASE_URL` opcional aplica as migrações pela conexão direta do mesmo banco. Em conexões remotas o driver verifica certificado/host; remova `channel_binding=require` da URL Neon porque o driver atual não implementa SCRAM-PLUS. Essa opção é rejeitada explicitamente.

O Compose é um ambiente local com PostgreSQL e MongoDB, cada um com seu volume. No Render + Neon + Atlas, a API não usa volume de banco local. O Dockerfile compila o bundle com [dart build cli](https://dart.dev/tools/dart-build), inclui a fonte Noto Sans para PDFs e executa como usuário sem privilégios. O workflow fornece os dois bancos para os testes, mas não publica serviços nem segredos. Docker/Linux e hospedagem precisam ser conferidos no destino; Docker não está instalado nesta máquina.

## Backup e restauração

```powershell
cd backend
dart run bin/backup.dart data/backups/lote-2026-10-15
# Para restaurar dados no banco configurado, publicando uma nova geração:
dart run bin/restore_data.dart data/backups/lote-2026-10-15/transport.json.gz
```

O backup contém `identity.json.gz` (snapshot PostgreSQL consistente por transação de leitura repetível, incluindo hashes e sessões) e `transport.json.gz` (snapshot documental ativo). Ambos têm checksum. Configure `DATABASE_URL`/`DIRECT_DATABASE_URL` e a URI MongoDB no terminal. Para restaurar identidade em um PostgreSQL vazio, com a API parada, execute `dart run bin/migrate.dart --restore CAMINHO/identity.json.gz`; restaure os documentos com `restore_data.dart`. Valide primeiro em homologação. O restore de dados não altera usuários e a identidade recusa sobrepor contas existentes. Conserve fontes e configurações fora do Git, em armazenamento privado; o ZIP original não é versionado nem incluído no Docker.

O backup lógico dos documentos pode ser feito com a API em execução. Para um backup coordenado de identidade e dados, executar em janela sem importações/administração; bancos distintos não compartilham transação. O arquivo inclui dados sensíveis de identidade e deve ter acesso restrito. Agendar cópias fora da máquina/volume principal e definir retenção ainda são tarefas da infraestrutura.

## Pendências externas antes do deploy

- [ ] Receber/analisar o contrato das rotas da IA existente e fazer teste ponta a ponta em homologação.
- [ ] Configurar entrega real dos e-mails de recuperação.
- [ ] Provisionar/configurar Neon, Atlas, Render, Vercel, domínios e segredos de produção; executar migração no Neon real quando houver identidade SQLite.
- [ ] Executar o pipeline no GitHub e validar imagem Linux no destino.
- [ ] Validar HTTPS/cookies/origens no domínio final, capacidade/carga, backups externos agendados, retenção e procedimento de indisponibilidade.
- [ ] Conferir a execução remota do CI após o push autorizado da implementação; dados e segredos permanecem fora do Git.

Os testes locais cobrem dados reais importados, dois mecanismos de documento (Sembast e MongoDB real na validação anterior), identidade PostgreSQL real, transferência SQLite, concorrência, permissões, recuperação, exportação, ponte HTTP de IA e backup/restauração. Os testes Flutter cobrem cliente/repositório e todas as telas em três larguras. Eles não substituem a validação nos domínios e serviços reais de produção.
