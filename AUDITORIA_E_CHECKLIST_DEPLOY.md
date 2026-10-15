# SEMOB — acompanhamento da auditoria e do deploy

Atualização de 15/10/2026, após a implementação solicitada. Este arquivo substitui o checklist inicial de diagnóstico. Detalhes técnicos e operação: [IMPLEMENTACAO_E_DEPLOY.md](IMPLEMENTACAO_E_DEPLOY.md).

## Requisito de persistência atualizado

O pedido final é **um banco relacional e um não relacional**, sem banco vetorial. Implementado: PostgreSQL/Neon para gerenciamento de usuários e MongoDB para transporte em nuvem; Sembast é a alternativa documental de desenvolvimento. As conexões e responsabilidades são separadas. Não foi criado banco em uma conta de nuvem. Tutorial completo: [TUTORIAL_DEPLOY.md](TUTORIAL_DEPLOY.md).

## Entregas no código

- [x] Remover autenticação demonstrativa do frontend e adicionar login real por API.
- [x] Persistir usuários, matrícula, perfil funcional, papéis, sessões, preferências e auditoria em banco relacional separado.
- [x] Migrar o adaptador de identidade SQLite para PostgreSQL, com pool, TLS, migrações versionadas e transações entre instâncias.
- [x] Transferir identidade SQLite por CLI, preservando hashes, IDs e vínculos, com verificação, rollback e repetição sem duplicação.
- [x] Preparar frontend Vercel com proxy para API Render e tutorial Neon/Atlas/Render/Vercel.
- [x] Senhas com KDF/salt, tokens por hash, expiração, logout e revogação de sessão.
- [x] Proteger API, menu e rotas por permissão; impedir a perda do último administrador.
- [x] Cadastro/edição/ativação/desativação reais na interface.
- [x] Implementar solicitação, verificação e redefinição efetiva de senha; integração de entrega por webhook configurável.
- [x] Remover exposição padrão do código de recuperação; rejeitar essa exposição em produção.
- [x] Padronizar erros JSON, validar tipos/datas/filtros, restringir origens e limitar requisições/tentativas.
- [x] Migrar o uso operacional do SQLite misto para banco documental, com adaptadores Sembast/MongoDB e versionamento de snapshots.
- [x] Manter o banco antigo intacto como legado, sem usá-lo no runtime novo.
- [x] Converter os 44 HTMLs em CSVs consolidados e 55 tabelas originais, preservando proveniência e hashes.
- [x] Armazenar também CSVs brutos em partes no banco documental.
- [x] Importar novos ZIPs/CSVs pela interface com autorização, validação e publicação atômica.
- [x] Resolver precedência por fato e mês da fonte, sem depender da ordem do ZIP; preservar histórico fora das atualizações.
- [x] Corrigir rótulos de agosto, percentuais fixos, contagens de frota e KPIs constantes.
- [x] Informar cobertura parcial; remover a comparação inválida de 17 dias de julho com 31 dias de agosto.
- [x] Tratar campos financeiros ausentes e manter centavos para agregações monetárias.
- [x] Carregar opções de filtro pela API e enviar filtros suportados por domínio.
- [x] Paginação remota de viagens, busca, status e ordenação; consultas de detalhe por linha/veículo.
- [x] Insights calculados no período; detalhes de linhas com evolução e ocorrências reais.
- [x] CSV/PDF reais, modelos de CSV e download normalizado para reimportação.
- [x] Preferência compacta persistida e aplicada; remover controles de funcionalidades inexistentes.
- [x] Remover respostas fixas do assistente e implementar ponte servidor a servidor para IA externa.
- [x] Integrar fonte livre no frontend/PDF e documentar sua licença.
- [x] Criar configuração de Docker/Compose, exemplo de ambiente, proxy e workflow de verificação.
- [x] Criar backup consistente de usuários e backup/restore lógico dos documentos com checksum.
- [x] Atualizar scripts, README, documentação frontend e guia de deploy.

## Fatos que continuam sendo limitações da fonte

| Domínio | Situação |
|---|---|
| Passageiros de julho | Somente 15–31/07; não é mês completo |
| Setembro | Registros até 14/09 |
| Viagens detalhadas de agosto | 36.751 atividades; não são o mesmo universo do resumo de viagens normais |
| Frota de agosto | 57 prefixos distintos nos registros |
| Demanda por linha/horário | Relação ausente na fonte de passageiros |
| Receita tarifária | Não pode ser inferida apenas de créditos transferidos |

Essas ausências são apresentadas na interface; o código não inventa dados para preenchê-las.

## Falta configurar ou validar externamente

- [ ] Disponibilizar o código/documentação da outra IA (por exemplo, `integrations/ia`) ou a rota exata de produção, formato e autenticação. Confirmar qual rota corresponde à IA normal e qual à versão RAG/fine-tuning.
- [ ] Ajustar o adaptador ao contrato confirmado e testar SEMOB → IA real em homologação. O teste atual da ponte usa servidor HTTP de teste, não a IA da equipe.
- [ ] Configurar entrega dos e-mails de recuperação e validar o recebimento real.
- [ ] Provisionar Neon e Atlas, configurar Render/Vercel, DNS, HTTPS e segredos. Executar migrador no Neon real antes de iniciar a API, se houver SQLite de usuários.
- [ ] Validar a imagem Linux, executar o CI remoto e publicar build com `API_BASE_URL` real.
- [ ] Validar cookies/recarga de sessão no domínio final e preferir API e frontend no mesmo site.
- [ ] Medir carga/capacidade e configurar alertas, retenção de snapshots e backups externos agendados.
- [ ] Executar restauração e rollback no ambiente de homologação antes da promoção.
- [ ] Conferir o CI remoto após a publicação autorizada na main. Bancos, relatórios, ZIPs, CSVs, backups e segredos ficam fora do Git.

## Critério de liberação

Validação após a revisão de segurança: **11 testes Flutter e 19 testes backend aprovados**, incluindo PostgreSQL real 17.11, transferência SQLite, backup/restore de identidade, rollback, bootstrap/último administrador concorrentes, importação completa em Sembast, ZIP sintético e malformado, permissões, recuperação, origens, CSV/PDF e ponte HTTP de IA. O teste de MongoDB ficou explicitamente ignorado nesta rodada, pois a variável de conexão de testes não estava configurada; a importação completa em MongoDB real 8.0.32 foi validada na etapa anterior. Análises estáticas sem problemas; build web release e bundle nativo Windows do backend compilados. A validação dos provedores de nuvem e da imagem Linux continua pendente.

O executável PostgreSQL foi conferido por HTTP com login/cookie, consulta de viagens após o registro 30.000, preferências e logout. Os CLIs de migração, backup e restauração foram executados contra bancos temporários reais, incluindo repetição do restore sem duplicação. O script Vercel gerou o build web e o proxy com URL ilustrativa; rode-o com a origem real antes de publicar. Os processos temporários foram encerrados. Nenhum dado existente do usuário foi enviado para a nuvem.

Publicar após concluir as pendências externas do escopo escolhido e validar login, permissões, filtros, importação, exportação, recuperação e IA na URL de homologação. PostgreSQL/Neon e MongoDB dispensam o volume de identidade no Render. Antes de escalar múltiplas réplicas, medir carga e substituir os limites de requisição por processo por controle compartilhado.

O código pode ser executado localmente sem IA/e-mail configurados; a interface informa claramente a indisponibilidade dessas integrações. Isso não equivale a anunciar os dois serviços como concluídos em produção.

Revisão antes da publicação: [REVISAO_SEGURANCA.md](REVISAO_SEGURANCA.md). Dados, ZIP original, CSVs, bancos, backups e segredos foram excluídos do índice e do contexto Docker. A varredura local Gitleaks não encontrou segredos no conteúdo preparado ou no histórico disponível. Os relatórios continuam na máquina e devem ser importados diretamente no Atlas antes do deploy.
