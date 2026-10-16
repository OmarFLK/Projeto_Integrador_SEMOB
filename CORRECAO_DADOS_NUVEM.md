# Falha das consultas de transporte em nuvem

Diagnóstico de 15/10/2026: login funcionava, mas períodos, filtros, operação,
cobertura, passageiros e linhas retornavam HTTP 500. O Render registrava
`MongoDartError`.

## Causa reproduzida

Com `mongo_dart 0.10.10`, seis consultas simultâneas ao Atlas real causaram
`ConnectionException: connection closed: The socket connection has been reset by peer`
na primeira rodada. O driver perdia a conexão primária e a aplicação não a
reabria. A inicialização do dashboard dispara várias consultas simultâneas.

O próprio driver oferece `safeAtlas=true` para serializar os comandos no
socket. Repetindo o mesmo cenário com essa opção, seis rodadas completas
passaram e a conexão permaneceu aberta. TLS e validação de certificados foram
preservados. A correção é aplicada automaticamente ao abrir o adaptador; não
exige alterar a URI no painel nem reimportar os relatórios.

## Mudanças

- Ativar `safeAtlas=true` no adaptador MongoDB.
- Reabrir uma conexão perdida com uma tentativa compartilhada entre leituras
  simultâneas; repetir a leitura uma vez para falhas de conexão. Não repetir
  automaticamente publicação/importação, erros de autenticação ou consultas inválidas.
- Calcular os valores dos filtros por agregação no Atlas e manter cache por
  geração/período. Abrir os filtros deixa de transferir todas as viagens do mês.
- Mostrar mensagem compreensível e ação para tentar novamente no dashboard,
  em vez do texto interno completo do Dio.
- Desabilitar deploy automático da raiz na Vercel: este projeto publica Flutter
  já compilado pelo CLI. O Render continua recebendo atualizações do Git.

## Verificação antes da publicação

No computador local com o Atlas real, o conjunto de cinco consultas do
dashboard passou nos três meses, com 173–448 ms na primeira leitura de cada
mês e 52–62 ms nas repetições com cache. São medições deste ambiente, não um
SLA do serviço publicado.

As opções agregadas de agosto foram comparadas à leitura completa das viagens:
linhas, veículos, sentidos e faixas de horário coincidiram. A consulta após o
registro 30.000 retornou cinco viagens. Após fechar a conexão deliberadamente,
oito leituras simultâneas recuperaram a mesma geração em 443 ms.

Análises Dart/Flutter sem problemas; oito testes afetados de conexão e dados
aprovados, incluindo os 44 HTMLs privados; 11 testes Flutter aprovados e backend
compilado. O teste sintético MongoDB também passa a cobrir simultaneidade e
reconexão no CI, quando existe `SEMOB_TEST_MONGODB_URI`.

O Render Free pode demorar cerca de um minuto para despertar após 15 minutos
sem tráfego. Isso é separado da falha de consultas reproduzida acima.
Referências: [Render Free](https://render.com/docs/free) e
[configuração Git da Vercel](https://vercel.com/docs/project-configuration/git-configuration).
