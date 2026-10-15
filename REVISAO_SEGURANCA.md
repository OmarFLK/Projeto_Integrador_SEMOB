# Revisão de segurança antes do envio ao GitHub

Revisão local de 15/10/2026, autorizada junto do commit/push na `main`. Escopo: código, configuração de build/deploy, arquivos preparados no índice e histórico Git disponível. A revisão não é um pentest dos serviços de nuvem.

## Correções realizadas

- Toda a pasta `backend/data/` ficou fora do Git e do contexto Docker, incluindo ZIP original, CSVs, bancos, logs e backups. Os arquivos locais foram preservados. A imagem contém código/fontes tipográficas; o transporte deve ser carregado diretamente no Atlas antes do deploy.
- Regras de exclusão também cobrem arquivos usuais de chaves/certificados, credenciais, bancos, backups e metadados locais da Vercel. `.env.example` mantém apenas placeholders; os valores reais ficam no ambiente do servidor.
- O script `scripts/verify_publishable.ps1`, também executado no CI, recusa caminhos/extensões conhecidos de dados e segredos no índice. Isso complementa a varredura de conteúdo; não detecta todo segredo possível.
- Upload ZIP agora inspeciona metadados antes de processar links simbólicos, recusa links/caminhos absolutos/travessia e limita quantidade de entradas/tamanho declarado de todo o arquivo. Conteúdo HTML é conferido por tamanho e CRC; o argumento `verify` do decoder atual não executava essa validação. A biblioteca também limita a expansão ao tamanho declarado durante a descompressão.
- Identificadores de login e e-mails de recuperação têm tamanho/formato limitados antes de entrarem nas consultas e limites de tentativas.
- Redefinição de senha rejeita desafios inválidos antes do cálculo caro do hash. A validade é conferida novamente dentro da transação para impedir replay após uma alteração concorrente.

As verificações de upload e recuperação seguem as recomendações de [upload da OWASP](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html) e [recuperação de senha da OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html).

## Verificações feitas

- Gitleaks 8.30.1 oficial, com checksum do download conferido, executado localmente no conteúdo preparado e nos dois commits do histórico disponível. Nenhum segredo detectado nessas varreduras; não foi necessário apagar ou reescrever o histórico.
- Registro Pub consultado para as dependências Flutter/backend: nenhum alerta de segurança publicado foi indicado para as versões resolvidas. Não foram feitas atualizações indiscriminadas de dependências.
- SQL usa parâmetros; a importação de identidade restringe nomes de tabelas/colunas a uma lista fixa. A API exige sessão/permissão para dados, administração, importação e exportação.
- Senhas usam PBKDF2-SHA256 com salt aleatório e 600.000 iterações; tokens persistidos ficam em hash. Sessões expiram e são revogadas em logout, redefinição e desativação/troca de papel.
- PostgreSQL remoto exige TLS com validação de certificado/host. As chaves da IA/e-mail são usadas somente pelo backend. Erros HTTP não retornam a exceção do driver ou a URL de conexão.
- Cookies são HttpOnly e Secure em produção; a API verifica origens e exige cabeçalho próprio nas alterações com cookie. Há testes de sessão, permissões, CSRF, origem não autorizada, recuperação e concorrência do último administrador.
- Testes de CI usam dados sintéticos. O teste completo com os 44 HTMLs usa arquivo privado local e é explicitamente ignorado num clone que não possua essa fonte.
- Validação local final: 19 testes backend e 11 Flutter aprovados; um teste MongoDB ignorado por falta de conexão configurada. Análises estáticas e compilação nativa do backend aprovadas. O build web já foi validado nesta implementação; nenhuma mudança de frontend foi necessária nesta revisão.

## Verificações ainda necessárias na infraestrutura real

- Conferir URLs, HTTPS, origens exatas, proxy Vercel, persistência do cookie e funcionamento após redeploy no domínio final.
- Provisionar Neon/Atlas com contas próprias, acesso de rede restrito e segredos fora do Git; confirmar TLS e permissões usando as credenciais reais.
- Configurar backup externo, retenção, alertas e ensaiar restauração.
- Medir carga: limites de requisição atuais são por processo; múltiplas réplicas precisam de controle compartilhado. IPs atrás dos proxies devem ser tratados somente a partir de infraestrutura confiável.
- Validar contrato/autenticação da IA real e entrega do e-mail. Não foram fornecidos endpoints/credenciais desses serviços para um teste de produção.
- Conferir o resultado do CI remoto, a imagem Linux e alertas futuros das dependências. Ausência de alertas ou de achados na varredura não garante ausência de vulnerabilidades.

O roteiro operacional atualizado está em [TUTORIAL_DEPLOY.md](TUTORIAL_DEPLOY.md).
