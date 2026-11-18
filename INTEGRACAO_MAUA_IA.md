# Assistente SEMOB conectado ao MAUA_IA

O Flutter existente chama `/api/v1/assistant` no backend SEMOB. O Dart autentica a sessão, verifica a permissão `assistant`, constrói o contexto selecionado e chama a API exclusiva CMob do MAUA_IA.

## Variáveis no Render do SEMOB

| Variável | Valor |
|---|---|
| `SEMOB_AI_URL` | `https://cmob-ai-backend.onrender.com/api/integrations/semob/chat` |
| `SEMOB_AI_API_KEY` | Credencial exclusiva gerada no MAUA_IA |
| `SEMOB_AI_REQUEST_FIELD` | `message` |
| `SEMOB_AI_RESPONSE_FIELD` | `answer` |

No Render do MAUA_IA, configure `SEMOB_INTEGRATION_KEY_SHA256` com o digest correspondente. O script `python -m scripts.create_integration_key --output ..\semob-credentials.private.json`, no repositório MAUA_IA, gera as duas configurações sem mostrar os segredos no terminal. Não reutilize a chave Barô.

Publique novamente os dois backends após configurar as variáveis. A integração mantém o contrato do Flutter; não é necessário incluir credenciais ou mudar o proxy da Vercel. Nenhuma base de identidade é compartilhada.

O navegador não recebe a chave do serviço e não pode definir `user_id`. O Dart insere a identidade autenticada, fixa a preferência RAG e recusa respostas com `assistant` diferente de `cmob`. A resposta exibe as fontes realmente recuperadas pelo MAUA_IA, em vez de atribuir ao modelo todas as fontes do dashboard.

O campo opcional `conversation_id` permite conversas separadas; clientes atuais usam `workspace`. O provedor separa memória por usuário e contexto de datas, com a retenção existente de até 14 dias. Perguntas com data explícita prevalecem sobre o período padrão do dashboard. Os resultados numéricos são calculados no MAUA_IA; respostas conceituais usam seu RAG e modelo.

## Verificar

- Sem sessão, `/api/v1/assistant` retorna 401.
- Com sessão autorizada, `/api/v1/assistant/status` mostra se URL e chave foram configuradas; isso não substitui uma pergunta real para verificar a disponibilidade do provedor.
- Faça uma pergunta sobre passageiros de agosto de 2026 e confira a fonte `CMob: passengers_daily`, os totais e a cobertura.
- Faça uma pergunta conceitual sobre quilometragem improdutiva e confira as fontes documentais do RAG.
- Erros de autenticação/configuração do provedor não são convertidos em respostas simuladas.

Teste local dos dois servidores: configure `SEMOB_TEST_DATABASE_URL` com um PostgreSQL exclusivo de testes, `SEMOB_TEST_MAUA_URL` com a API local de teste e `SEMOB_TEST_MAUA_KEY` com sua credencial exclusiva; rode `dart test test/api_test.dart --plain-name "live MAUA API"` na pasta `backend`. A suíte comum também testa identidade forjada, ausência de chave, resposta sem CMob e proteção dos segredos.

Mais detalhes do contrato, geração, rotação e revogação: [MAUA_IA/docs/SEMOB_INTEGRATION.md](https://github.com/OmarFLK/MAUA_IA/blob/main/docs/SEMOB_INTEGRATION.md).
