# Revisão do código e auditoria de segurança

Revisão da versão original (`tecnoshow_avalia.html` / `template.html`), com o que foi corrigido.

## Bugs na sincronização offline

| # | Problema | Efeito | Correção |
|---|---|---|---|
| 1 | Quando o `localStorage` enchia, a resposta ia para `memQueue`, que nunca era enviada | Respostas perdidas sem aviso | A fila fica na memória e é sempre enviada. O disco é só uma cópia. A barra avisa "memória do tablet cheia" |
| 2 | A fila era guardada por número de tablet (`tsa_q_T01`). Trocar o número escondia a fila antiga | Respostas pendentes ficavam presas no aparelho | Uma fila única por aparelho (`tsa_fila`). Filas antigas são migradas na primeira abertura |
| 3 | Dois aparelhos com o mesmo número gravavam no mesmo documento (`edição_T01_hora`), com leitura e escrita sem trava | Um tablet apagava as respostas do outro | Cada aparelho tem um identificador próprio no nome do documento. No Supabase, cada resposta é uma linha com id único |
| 4 | O envio contava como "enviados" itens que chegavam durante o envio | Uma resposta dada nesse intervalo nunca era enviada | O tamanho é registrado antes do envio |
| 5 | Uma resposta dada durante um envio em andamento esperava até 20 s | Painel atrasado | O envio roda de novo logo em seguida |
| 6 | A edição era lida na hora do envio, não na hora da resposta | Trocar a edição mudava respostas já dadas | A edição fica gravada em cada documento da fila |
| 7 | Documentos já enviados nunca saíam do `localStorage` | Em 5 dias de feira, risco de encher a memória (bug 1) | Documentos enviados de horas passadas são removidos |
| 8 | Sem internet, recarregar a página deixava o tablet sem o app | Coleta parada | Service worker guarda o app e as bibliotecas (site próprio). O navegador é orientado a não apagar os dados (`storage.persist`) |
| 9 | Tela apagava nos tablets e no telão | Interrupções | Pedido de tela sempre ligada (Wake Lock), quando o aparelho permite |

## Bugs no fluxo de coleta

| # | Problema | Correção |
|---|---|---|
| 10 | Tocar uma opção e logo em seguida **Voltar** (ou o tempo de inatividade reiniciar) deixava um avanço agendado, que pulava uma pergunta ou abria pergunta com respostas zeradas | Cada tela tem uma ficha; o avanço só acontece se a tela ainda for a mesma |
| 11 | Depois de escolher, o botão **Avançar** continuava desativado até o avanço automático | Ativado na hora |
| 12 | O comentário voltava para a caixa de texto via `innerHTML` | Usa `value`, o texto nunca vira HTML |
| 13 | Id da resposta gerado com `Math.random` (5 caracteres) | 8 caracteres de `crypto.getRandomValues` |

## Bugs no painel e no relatório

| # | Problema | Correção |
|---|---|---|
| 14 | No painel, chegadas além das 12 últimas não entravam no mapa | Todas entram, só as 12 últimas animam |
| 15 | Filtro De/Até usava a data em UTC: respostas depois das 21h caíam no dia seguinte | Data local |
| 16 | `porDia` ordenava "dd/mm/aaaa" como texto (errado na virada do mês) | Ordenação por data ISO |
| 17 | Filtro de datas sem respostas gerava relatório com zeros e textos sem sentido | Mensagem pedindo para ajustar as datas. Download bloqueado |
| 18 | "Item mais/menos bem avaliado" considerava itens sem nenhuma nota | Considera só itens avaliados |
| 19 | "N na última hora" mostrava a última hora com resposta, mesmo de horas atrás | Diz "às 14h" quando não é a hora atual |
| 20 | Respostas repetidas (reenvio) contavam duas vezes | Respostas repetidas são removidas pelo id ao ler |
| 21 | Fora do claude.ai, nenhum download funcionava | Download direto pelo navegador no site próprio |
| 22 | Leitura limitada a 1.000 documentos | No Supabase, leitura paginada sem limite |

## Auditoria de segurança

| Risco | Situação original | Correção |
|---|---|---|
| **Leitura indevida das respostas** | Qualquer pessoa com acesso ao app lia todas as respostas, incluindo comentários livres que podem ter dados pessoais | Painel e relatório exigem login. Só contas da tabela `equipe` leem (RLS). Cadastro público desligado |
| **Gravação de respostas falsas ou alteração/apagamento** | A base aceitava qualquer documento | A chave pública só chama `enviar_respostas`: exige a chave da coleta da edição (guardada só como hash SHA-256), só insere e nunca altera ou apaga. Edições podem ser encerradas |
| **Dados malformados** | Nenhuma validação | Validação dupla. O banco só aceita os valores exatos do questionário (`_resposta_valida`), com tamanho, faixas e datas plausíveis. O app limpa tudo o que lê (`limpar`) antes de usar |
| **XSS (injeção de HTML/JS)** | O painel inseria campos da base direto no HTML (ex.: `nps`, nome da edição no título). Uma resposta forjada executaria código no telão e no computador da equipe | Todo texto passa por `esc()`, e os dados são limpos ao ler. Teste com `<img onerror>` nos dados confirmou que nada é executado |
| **Content Security Policy** | Não havia | No site: scripts só do próprio domínio e dos blocos embutidos exatos (hash SHA-256); conexões só com o projeto Supabase; `object-src`, `base-uri` e `form-action` bloqueados; `referrer` desligado |
| **Bibliotecas de terceiros** | d3 de CDN, sem verificação | d3 e supabase-js servidos pelo próprio site com SRI (o navegador recusa o arquivo se for alterado) |
| **Injeção de fórmulas no CSV** | Um comentário como `=HYPERLINK(...)` virava fórmula no Excel | Textos que começam com `= + - @` recebem um apóstrofo |
| **Chave errada no build** | — | `build.py` recusa a chave `service_role` / `sb_secret_` |
| **Login no tablet** | — | O README orienta a nunca entrar com a conta da equipe nos tablets. O botão **Sair da conta da equipe** fica na tela inicial |

### Riscos que permanecem (e como reduzir)

- **Chave da coleta no tablet**: fica no `localStorage`. Quem pegar um tablet desbloqueado pode enviar respostas falsas, mas não consegue ler nem apagar nada. Use modo quiosque e troque a chave (novo hash em `edicoes`) se um tablet sumir.
- **Senhas da equipe**: use senhas fortes. Se possível, ative a verificação em duas etapas (MFA) no Supabase.
- **Versão do claude.ai**: segue as permissões do Artifact. Quem tem acesso de edição ou interação grava e lê as respostas. Compartilhe o link só com a equipe e os tablets.

## Editor do questionário e papéis (segunda etapa)

| Item | Como funciona | Proteção |
|---|---|---|
| Papéis | `equipe` (painel e relatório) e `coordenador` (também edita o questionário e a equipe) | Funções `sou_equipe` e `sou_coordenador` no banco. Toda ação de coordenador é conferida no servidor, não só na tela |
| Convites | Link de uso único, válido por 7 dias. O banco guarda só o hash | Convite usado, vencido ou cancelado é recusado. Uma conta sem convite não lê nada |
| Questionário versionado | Tabela `instrumentos` (uma linha por versão). Os tablets leem a versão atual por `instrumento_atual` e guardam uma cópia para uso offline | Só o coordenador publica (`publicar_instrumento`). O formato é validado no banco e no app (`limparInstrumento`) |
| Respostas a perguntas novas | Ficam em `x` (por id da pergunta), com `v` = versão | `enviar_respostas` confere cada resposta contra a versão em que foi dada: pergunta existente, opção válida, nota de 1 a 5, texto de até 400 caracteres |
| Textos editáveis | Perguntas, opções, ajuda, abertura e termo | Sempre exibidos com escape de HTML. Testado com `<img onerror>` num texto de opção |
| Núcleo protegido | Origem, perfil, satisfação, gasto e NPS não podem ser removidas; as opções do núcleo não mudam | Garante que o mapa, os indicadores, o impacto econômico e a comparação entre versões continuem válidos |

## Base multifeira e cadastros editáveis (terceira etapa)

| Item | Como funciona | Proteção |
|---|---|---|
| Papéis | `admin_geral`, `coordenador`, `organizacao`, `equipe` | Conferidos no banco (`meu_papel`, `pode_editar_cadastros`, `sou_admin_geral`) |
| Cadastros | Feiras, categorias, expositores, planta, lotes, locais, estandes, agenda | RLS: a equipe lê; editores inserem e alteram; só o administrador geral apaga de vez |
| Lixeira | Coluna `excluido_em`; restaurar é limpar a coluna | Exclusão definitiva só pelo administrador geral |
| Auditoria | Gatilho em todas as tabelas de cadastro grava quem, o quê, antes e depois | A tabela não aceita escrita pela API; leitura só para administrador geral e coordenação |
| Geometria | Lotes, pontos e georreferência em coordenadas de 0 a 1 sobre a planta | Validada por restrições no banco |
| Chave da coleta | A equipe lê os dados da edição, nunca o hash da chave | Permissão por coluna em `edicoes` |
| Plantas | Pasta pública `plantas` no Storage (imagens até 20 MB) | Só editores enviam ou apagam; a planta não tem dado pessoal |
| Pendências | Visão `pendencias` com `security_invoker` | Segue as mesmas regras de leitura de quem consulta |

Testes: as regras de cada papel foram testadas num Postgres local que imita o Supabase, antes de aplicar em produção. As telas foram testadas no navegador com os dados de partida. Os testes pegaram três defeitos, corrigidos antes da publicação:
- funções de validação sem permissão de uso;
- painel da versão claude.ai pedindo login;
- identificadores repetidos entre as telas de Cadastros e de convite.

## Visitante e página do estande (quarta etapa)

| Item | Como funciona | Proteção |
|---|---|---|
| Identidade do visitante | Credencial aleatória no aparelho; o banco guarda só o SHA-256 | Toda ação passa por `interagir`, que confere a credencial; a chave pública não lê nem grava tabelas |
| WhatsApp | HMAC com segredo do servidor (busca) + cópia cifrada com `pgp_sym_encrypt` | A tabela `_segredos` não é acessível pela API; a equipe não lê as colunas de WhatsApp nem a credencial |
| Perfil | `_perfil_valido` aceita só os valores do questionário | Perfil fora do formato é recusado |
| Interações | Reação, salvar e seguir alternam (fazer/desfazer); uma carinha por estande; check-in a cada 30 minutos | Produto precisa ser do expositor do estande; estande precisa ser da edição do visitante |
| Abuso | No máximo 5 perfis por número por hora, 300 ações e 20 comentários por visitante por hora | Ações acima do limite são recusadas |
| Menores | Perfil "até 17 anos" marca o visitante como menor | Sem pedido de contato e sem comentário público |
| Comentário público | Entra como "pendente" | Só vai a público depois da moderação (aba Moderação, quinta etapa) |

Testes: as funções foram testadas no Postgres local, inclusive com ataques (credencial falsa, produto de outro estande, ação inventada, valor inválido). A tela do visitante foi testada no navegador chamando as funções reais do banco local. O teste pegou um defeito, corrigido antes da publicação: um número brasileiro digitado sem +55 perdia o código do país quando o celular estava em outro idioma.

## Moderação e painel do expositor (quinta etapa)

| Item | Como funciona | Proteção |
|---|---|---|
| Papel de moderação | Novo papel `moderador` na equipe; convite escolhe o papel | Só o administrador geral convida coordenadores; o moderador vê só a aba Moderação |
| Moderação | `listar_moderacao` e `moderar_comentario` | Só administrador, coordenação, organização e moderação; cada decisão é auditada |
| Contas de estande | Tabela `expositor_equipe`, preenchida pelo convite de estande | Não entram em `equipe`, portanto não leem respostas, visitantes nem outros estandes |
| Painel do estande | `painel_expositor` devolve só números do próprio estande | Perfil só com 5 ou mais visitantes; média do segmento só com 5 ou mais estandes |
| WhatsApp no painel | Decifrado só para quem pediu contato àquele estande | Cada consulta à lista de contatos fica registrada na auditoria |
| Revogação | `listar_contas_expositor` e `remover_conta_expositor` | Só a organização |

Testes:
- **Funções no Postgres local:** testadas com cada papel (visitante anônimo, equipe, moderação, coordenação, administrador e conta de estande). Os ataques testados foram:
  - papel inventado;
  - coordenador convidando coordenador;
  - convite usado duas vezes;
  - estande de outra empresa;
  - leitura direta das tabelas.
- **Navegador contra o banco local:**
  - moderação, incluindo um comentário com código, que aparece como texto;
  - convite com papel;
  - painel no computador e no celular;
  - planilha de contatos;
  - convite de estande de ponta a ponta;
  - os testes anteriores do visitante e dos cadastros continuam passando.
- **Pendente:** gestor e atendente têm hoje o mesmo acesso; diferenciar fica para a próxima etapa.

## Navegação, saída dos tablets e fila do visitante (sexta etapa)

| Item | Como funciona | Proteção |
|---|---|---|
| Seta de voltar | Pilha das telas abertas no app; sem tela anterior, vai ao início | Não sai do app para outro site |
| Tablet travado | A trava vale quando o aparelho tem chave da coleta; qualquer outra tela redireciona para a coleta | Saída só com o gesto de 3 segundos mais o código |
| Código de saída | O banco guarda o sha256 de "edição:código"; o tablet busca esse hash com a chave da coleta e confere o código sem internet | Sem a chave da coleta não se obtém o hash; 5 erros bloqueiam por 1 minuto; a coluna não é lida pela API; cada saída vai para a auditoria |
| Fila do visitante | Ações sem sinal ficam no celular (até 300) e são reenviadas quando a conexão volta | O banco confere tudo de novo no reenvio; uma ação recusada (limite, menor de idade) é descartada |

Testes, no navegador contra o banco local:
- seta a partir do início e de um link direto;
- trava do tablet resistindo à recarga e à troca de tela;
- toque curto não abre a saída;
- código errado e código certo sem internet, com o registro na auditoria quando o sinal volta;
- visitante curtindo, salvando e avaliando sem internet, recarregando a página sem sinal, com a sincronização quando volta.

Os ataques ao banco foram recusados:
- chave errada;
- usuário anônimo definindo o código;
- moderador definindo o código;
- código com letras;
- leitura direta do hash.

## Presença em palestras e trilhas (sétima etapa)

| Item | Como funciona | Proteção |
|---|---|---|
| Código da palestra | Os 10 primeiros caracteres do sha256 de "segredo:minuto"; vale no minuto atual e no anterior | O segredo fica numa tabela que a API não lê; só a equipe obtém o código (telão); fora do horário a presença é recusada |
| Presença | `presenca_palestra` confere a credencial do visitante, a edição, o horário e o código | Uma por visitante por palestra; no máximo 20 por hora; o endereço perde o código depois da leitura, para a página não reenviar um código vencido |
| Avaliação da palestra | Só para quem esteve presente; o comentário é sempre privado | Leitura só pela organização (`comentarios_palestra`) |
| Trilhas | Etapas guardadas na própria trilha e validadas pelo banco (1 a 10, tipo e id) | Só a organização cria e altera; o visitante só vê trilhas aprovadas |
| Cupom | Emitido pelo banco quando todas as etapas estão cumpridas, dentro do prazo e do estoque, com trava na trilha | Um por visitante por trilha; o estoque não estoura com acessos simultâneos |
| Baixa do cupom | Só pelo estande doador ou pela organização | Código de outro doador aparece como "não encontrado" (não revela que existe); 30 tentativas a cada 10 minutos por conta; cada baixa é auditada |

Testes:
- **Funções no Postgres local:**
  - etapas inválidas;
  - usuário anônimo lendo o código ou as tabelas;
  - código errado;
  - palestra fora do horário;
  - presença repetida;
  - avaliação sem presença;
  - estoque esgotado;
  - baixa por estande que não é o doador;
  - baixa repetida.
- **Navegador contra o banco local**, do começo ao fim:
  - a coordenação cria a trilha;
  - o telão mostra o QR;
  - o visitante sem perfil lê o QR, passa pela porta de entrada, registra presença e avalia a palestra;
  - o check-in no estande completa a trilha e gera o cupom;
  - o estande doador dá baixa, e a segunda baixa é recusada.
- Os testes anteriores continuam passando.

## Telão social (oitava etapa)

| Item | Como funciona | Proteção |
|---|---|---|
| Publicação | `publicar_mural` confere a credencial, a edição e o estande ou a palestra | Menor de idade recusado; texto até 140 caracteres; até 5 por hora; texto ou foto obrigatórios |
| Foto | Reduzida e regravada em JPEG no celular (lado maior até 1080 px) | O banco aceita só JPEG ou WebP (conferidos pelos primeiros bytes) até 350 KB; regravar apaga o EXIF e o GPS (testado com um EXIF falso de GPS) |
| Moderação | Tudo entra como pendente; aprovar e recusar ficam na auditoria (só a decisão, sem a foto) | Só administração, coordenação, organização e moderação |
| Leitura | A foto pendente só a moderação vê; a aprovada, também o telão (equipe) | A tabela não é lida pela API; não há endereço público da foto |
| Em alta agora | Contagem de pessoas diferentes por estande nos últimos 30 minutos | Só contagens, a partir de 3 pessoas |

Testes:
- **Banco local:**
  - menor de idade;
  - foto PNG;
  - foto grande demais;
  - publicação vazia;
  - estande de outra edição;
  - texto longo;
  - usuário anônimo ou conta de estande lendo o mural.
- **Navegador:**
  - foto de 457 KB com EXIF de GPS chegando ao banco com 112 KB e sem EXIF;
  - menor sem o botão;
  - moderação com a foto à vista;
  - telão com destaque, alternância e "em alta".
- Os testes anteriores continuam passando.

## Tecnoshow na Cidade (nona etapa)

| Item | Como funciona | Proteção |
|---|---|---|
| Visitante na cidade | Mesmo perfil anônimo da feira; check-in pelo QR do balcão, carinhas, "quero na feira" e pesquisa do hóspede | A credencial é conferida; o estabelecimento precisa ser da edição; respostas fora do formato e campos extras são recusados; no máximo 60 check-ins por hora |
| Contas de parceiro | Tabela `estab_equipe`, preenchida por convite | Não entram na equipe; cada conta só vê o próprio estabelecimento |
| Ocupação dos hotéis | Informada pelo próprio hotel (ou pela organização) | Sigilosa: a tabela não é lida pela API; a média da cidade só sai com 3 ou mais hotéis no dia (decisão 16); a diária média só com 3 ou mais valores |
| Painel do parceiro | Contagens do próprio estabelecimento | Perfil e resumo de hóspedes a partir de 5 pessoas; origem só em grupos de 3 ou mais |
| Resumo da organização | Prospecção, hóspedes, transbordamento e demanda | Hóspedes a partir de 5 respostas; município com menos de 3 hotéis entra em "outras cidades" |

Testes:
- **Banco local:**
  - tipo inválido;
  - usuário anônimo lendo as tabelas;
  - ação e valor inválidos;
  - pesquisa com campo extra (como CPF) ou valor fora da faixa;
  - pesquisa de hóspede num bar;
  - ocupados acima do total de quartos;
  - hotel lendo ou gravando dados de outro hotel;
  - demanda com 2 hotéis (não aparece) e com 3 (aparece).
- **Navegador:**
  - cadastro do hotel e do bar com QR e convite;
  - visitante no bar e no hotel;
  - hotel entrando pelo convite e informando a ocupação;
  - aba Cidade.
- Os testes anteriores continuam passando.
