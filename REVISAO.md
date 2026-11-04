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
