# Tecnoshow Avalia

App de avaliação da Tecnoshow Comigo (PPG em Administração, IF Goiano). Tem três modos:

- **Coleta**: tablets da sala de avaliação, com questionário em PT, EN e ES. Funciona sem internet: as respostas ficam guardadas no tablet e são enviadas quando a conexão volta.
- **Painel ao vivo**: telão com o mapa das rotas de origem, NPS, satisfação e bacia de atração.
- **Relatório técnico**: relatório pronto para baixar em .doc, e os dados em .csv.
- **Administração**: o coordenador edita o questionário (textos nos 3 idiomas, perguntas novas, versões) e gerencia a equipe por links de convite.

As respostas ficam num banco **Supabase** do próprio projeto. Uma versão alternativa roda dentro do claude.ai como Artifact e usa a base do próprio Artifact.

## Estrutura

| Caminho | O que é |
|---|---|
| `src/template.html` | Código do app (HTML, CSS e JS) com marcadores `__GEO__`, `__CONFIG__` e `__LIBS__` |
| `src/sw.js` | Service worker: guarda o app no tablet para ele abrir mesmo sem internet |
| `data/geo.json` | 5.571 municípios, 250 países (PT/EN/ES), malha do mundo e dos estados |
| `vendor/` | d3 7.8.5 e supabase-js 2.45.4, servidos pelo próprio site, com verificação de integridade (SRI) |
| `supabase/schema.sql` | Tabelas, regras de acesso (RLS) e função de envio dos tablets |
| `build.py` | Gera `dist/` (site) ou a versão para o claude.ai |
| `.github/workflows/deploy.yml` | Publica no GitHub Pages a cada push na `main` |
| `REVISAO.md` | Bugs corrigidos e auditoria de segurança |

## 1. Configurar o Supabase (uma vez)

1. Crie um projeto em <https://supabase.com> (região São Paulo, `sa-east-1`).
2. Abra **SQL Editor**, cole todo o conteúdo de `supabase/schema.sql` e clique em **Run**. Depois rode, na ordem, os arquivos de `supabase/migracoes/` (hoje, `002_multifeira.sql`, `003_visitante_estande.sql`, `004_moderacao_painel_expositor.sql`, `005_saida_tablets.sql`, `006_presenca_trilhas.sql`, `007_mural.sql`, `008_cidade.sql` e `009_passaporte_ao_vivo.sql`). Para começar com os dados do mapa de 2026, rode também `supabase/sementes/tecnoshow-comigo-2027.sql` (gerado por `gerar_tecnoshow_2027.py`).
3. Em **Authentication → Sign In / Providers**, deixe **ligado** "Allow new users to sign up" (a equipe se cadastra pelo link de convite; uma conta criada sem convite não acessa nada) e mantenha "Confirm email" ligado.
   Em **Authentication → URL Configuration**, coloque o endereço do site em **Site URL** e em **Redirect URLs** (ex.: `https://danilo-rv.github.io/Painel-Tecnoshow/**`), para o e-mail de confirmação voltar ao app.
4. Gere a chave da coleta: no SQL Editor, rode `select replace(gen_random_uuid()::text, '-', '') as chave_da_coleta;` e guarde o resultado.
5. Cadastre a edição com essa chave. Os comandos estão no fim do `schema.sql`, passo 2. O *slug* tem que bater com o campo **Edição** do app: "Tecnoshow Comigo 2027" vira `tecnoshow-comigo-2027`.
6. Crie a **sua** conta em **Authentication → Users → Add user** (marque "Auto Confirm User") e dê a ela o papel de coordenador (passo 3 no fim do `schema.sql`). O resto da equipe entra pelos convites do app.
7. Em **Project Settings → API**, copie a **Project URL** e a chave **anon** (ou *publishable*).
   Nunca use a chave `service_role` ou `sb_secret_...` no app. O `build.py` recusa essas chaves.

## 2. Publicar o site

### Opção A: GitHub Pages (automático)

O arquivo `config.json`, na raiz do repositório, já traz a URL do projeto e a chave **anon**. Essa chave é pública por definição: ela vai dentro do site, e a proteção dos dados está nas regras do banco. As variáveis abaixo são opcionais e, quando existem, têm prioridade sobre o arquivo.


1. No repositório, abra **Settings → Secrets and variables → Actions → aba Variables** e crie:
   - `SUPABASE_URL`: a Project URL
   - `SUPABASE_ANON_KEY`: a chave anon
2. Em **Settings → Pages → Build and deployment → Source**, escolha **GitHub Actions**.
3. Faça push na `main`. O endereço aparece em **Actions** e em **Settings → Pages**.

> Num repositório **privado**, o GitHub Pages só funciona em contas pagas (Pro, Team ou Enterprise). Contas de estudante (GitHub Education) costumam ter o Pro de graça.
> Tornar o repositório público é seguro, porque o código não contém nenhum segredo: a chave anon é pública por natureza e as respostas ficam no Supabase, protegidas pelas regras do banco.
> Para mudar: **Settings → General → Danger Zone → Change repository visibility → Make public**.

### Opção B: Netlify ou Cloudflare Pages (funciona com repositório privado, de graça)

Conecte o repositório e configure:

- Comando de build: `python3 build.py`
- Pasta publicada: `dist`
- Variáveis de ambiente: `SUPABASE_URL` e `SUPABASE_ANON_KEY`

### Gerar localmente

```bash
cp config.example.json config.json   # preencha a URL e a chave anon
python3 build.py                     # site em dist/
python3 build.py --artifact          # versão para o claude.ai em dist/tecnoshow_avalia_claude.html
```

Para testar no computador, sirva a pasta `dist/` com `python3 -m http.server -d dist 8000` e abra <http://localhost:8000>. O service worker só liga em HTTPS.

## 3. Preparar os tablets

1. Abra o site no tablet, com internet. Na tela inicial, escolha **Tablet 1, 2…**, confira a **Edição** e cole a **chave da coleta**.
2. Toque em **Coleta**. A barra do topo mostra `online` e `0 na fila`.
3. Deixe o navegador em modo quiosque (Android: "Fixar tela"; iPad: "Acesso Guiado"), para o visitante não sair do questionário.
4. **Não faça login da equipe nos tablets.** O login dá acesso a todas as respostas.

Se a internet cair, a barra mostra `sem internet · guardando aqui` e o número de respostas na fila. Elas são enviadas sozinhas quando a conexão volta (a cada 20 s, e logo que o aparelho fica online). Não limpe os dados do navegador enquanto houver respostas na fila.

### Tablet travado na coleta

- Depois que o tablet recebe a chave da coleta e abre a Coleta, ele fica travado nela, mesmo se alguém recarregar a página ou tentar abrir outra tela.
- **Para sair:** toque e segure o logotipo "TECNOSHOW AVALIA", no alto da tela, por 3 segundos, e digite o código de saída.
  - O código, de 4 a 6 dígitos, é definido pela coordenação em **Administração → Equipe → Código de saída dos tablets**. Troque-o a cada edição.
  - O tablet confere o código sem precisar de internet.
  - Cada saída fica registrada na auditoria, assim que o tablet tiver sinal.
  - Cinco códigos errados bloqueiam novas tentativas por um minuto.
  - Sem código definido, segurar o logotipo e confirmar já basta.

## 4. Painel e relatório

Abra o site no computador do telão, escolha **Telão / computador** e entre em **Painel ao vivo** com uma conta da equipe. O painel busca respostas novas a cada 8 segundos. O relatório lê todas as respostas da edição e permite filtrar por data.

Ao fim da feira, encerre a coleta com `update public.edicoes set aberta = false where slug = '...';`.

## 5. Administração: editar o questionário e a equipe

Na tela inicial, toque em **Administração** e entre com a conta de coordenador.

**Questionário**
- Escolha o idioma no seletor (Português, English, Español) e edite os textos de cada pergunta, das opções, da tela de abertura e do termo de consentimento. Texto vazio em inglês ou espanhol aparece em português no tablet.
- **Perguntas do núcleo** (as originais) têm as opções fixas, porque o mapa, o painel e o relatório dependem delas. Os textos podem ser editados, e as que não são essenciais podem ser desativadas. Origem, perfil, satisfação, gasto e NPS não podem ser desativadas.
- Na pergunta de satisfação, você pode **acrescentar itens** (ex.: "Banheiros"). Eles entram no painel e no relatório.
- **Perguntas novas**: escolha única, múltipla escolha, notas de 1 a 5 por item, escala de 0 a 10 ou texto livre. Podem ser obrigatórias ou não, reordenadas e excluídas. O relatório ganha a seção "Perguntas adicionais" e o CSV, uma coluna para cada uma.
- As alterações ficam num **rascunho** guardado no seu aparelho. Use **Pré-visualizar** para responder como no tablet, sem gravar nada.
- **Publicar versão** cria a versão seguinte (v1, v2…). Os tablets passam a usá-la a partir da próxima pessoa que começar o questionário. Cada resposta guarda a versão em que foi dada, e o relatório informa quantas respostas há em cada uma.
- Em **Versões publicadas**, dá para copiar uma versão antiga para o rascunho e publicá-la de novo.

**Equipe**
- **Gerar link de convite** cria um link de uso único, válido por 7 dias. Envie-o por e-mail ou WhatsApp. A pessoa cria a conta (ou entra com uma que já tem) e passa a ver o painel e o relatório.
- A lista mostra quem está na equipe. **Remover** tira o acesso na hora. Convites não usados podem ser cancelados.

Na versão do claude.ai, a equipe é quem você convida pelo menu **Compartilhar** do Artifact: quem tem permissão de edição também edita o questionário.

## 6. Cadastros, mapa e pendências (base multifeira)

Na **Administração**, as abas **Cadastros**, **Mapa** e **Pendências** aparecem para o administrador geral, a coordenação e a organização da feira.

- **Cadastros:** expositores (com os lotes que ocupam na edição), lotes, locais e palcos, agenda e categorias.
  - Busca, filtro "só a confirmar" e lixeira, que permite restaurar.
  - Importação por planilha, com modelo para baixar e relatório de erros por linha.
  - Tudo se liga por identificador: renomear uma categoria ou mudar um expositor de lote aparece em todas as telas.
- **Mapa:**
  - envio da planta (PNG, JPG ou WEBP);
  - desenho dos lotes por retângulo;
  - posição dos locais;
  - georreferência com 3 ou 4 pontos e as coordenadas coletadas em campo.
- **Pendências:** o que está "a confirmar", sem posição, sem categoria, sem palco ou sem planta, com um botão para abrir cada item. A lista é recalculada a cada consulta.
- **Clonar edição** (administrador geral e coordenação): cria a próxima edição com planta, lotes, locais e estandes, e mostra uma única vez a chave da coleta nova.

Papéis: `admin_geral` (tudo, inclusive apagar de vez e criar feiras), `coordenador` (questionário, equipe, cadastros, clonar edição), `organizacao` (cadastros e mapa) e `equipe` (painel e relatório). Toda alteração fica na tabela `auditoria`.

## 7. Visitante: porta de entrada e página do estande

Cada estande tem um QR (em **Administração → Cadastros → Expositores**, abra o expositor: o QR aparece com os botões para copiar o link e baixar a imagem). O QR abre `…/#e-<id do estande>` no celular do visitante, sem instalar nada.

- **Porta de entrada:**
  - na primeira leitura de QR da edição, o visitante responde o perfil curto (origem, perfil, faixa etária, culturas, primeira vez, dias, pernoite, WhatsApp e aceite do termo), em português, inglês ou espanhol;
  - recebe uma credencial guardada só no aparelho e não precisa responder de novo.
- **Página do estande:**
  - vitrine de produtos (preço ou condição, pagamento e financiamento, validade);
  - 👍 ❤️ na loja e em cada produto, salvar produto, seguir o estande;
  - carinhas de atendimento (☹️ pede o motivo);
  - comentário só para a loja ou público (fica pendente de moderação);
  - "quero contato" e compartilhar.
- **Menores de 18 anos:** não pedem contato nem publicam comentários.
- **WhatsApp:**
  - guardado cifrado, com uma versão irreversível (HMAC) para busca;
  - só sai do banco quando o visitante pede contato a um estande;
  - a confirmação por código depende de um provedor da API do WhatsApp Business (ainda não contratado), e até lá o número fica como "não confirmado".
- **Produtos:** cadastrados em **Administração → Cadastros → Produtos** ou importados por planilha.

## 8. Moderação e área do expositor

- **Papéis da equipe** (convite em **Administração → Equipe**, escolhendo o papel):
  - **Equipe:** painel e relatório.
  - **Moderação:** só a aba Moderação.
  - **Organização da feira:** cadastros, mapa, pendências e moderação.
  - **Coordenação:** tudo isso mais questionário e equipe. Só o administrador geral convida coordenadores.
- **Moderação** (aba **Moderação**):
  - comentários que o visitante marcou como públicos ficam pendentes até alguém aprovar ou recusar;
  - um comentário recusado continua visível para o estande, como comentário privado;
  - cada decisão fica na auditoria.
- **Área do expositor** (botão **Área do expositor** na tela inicial, ou `…/#expositor`):
  - em **Cadastros → Expositores**, abra o expositor e toque em **Gerar convite para o estande**; envie o link ao responsável, que cria a conta (o link vale 14 dias e funciona uma vez);
  - a conta do estande não entra na equipe da pesquisa: ela só vê o painel do próprio estande;
  - o painel mostra:
    - visitantes, curtidas, amei, seguidores, produtos salvos e pedidos de contato;
    - avaliação do atendimento, inclusive as negativas e os motivos;
    - visitantes por hora e reações por produto;
    - comentários;
    - os pedidos de contato com WhatsApp, com planilha para baixar;
  - o perfil de quem visitou só aparece com 5 ou mais visitantes; a média do segmento, com 5 ou mais estandes da mesma categoria;
  - na mesma tela do expositor, a organização vê quem tem acesso e pode remover uma conta (quando a pessoa sai da empresa);
  - a organização também abre o painel de qualquer estande por **Ver painel do estande**.

## 9. Navegação e uso sem internet

- **Seta de voltar (←):** está no painel, no relatório, na Administração, na área do expositor e na página do estande (quando o visitante veio de outra tela). Ela volta para a tela anterior do app ou, se a pessoa chegou direto por um link, para o início.
- **Visitante sem sinal no estande:**
  - curtir, amei, salvar, seguir, avaliar, comentar e pedir contato ficam guardados no celular e aparecem na tela na hora;
  - quando o sinal volta, tudo é enviado sozinho, e a página avisa quantas ações ainda esperam internet;
  - um estande já aberto antes continua aparecendo sem internet;
  - um estande nunca aberto mostra o aviso para tentar de novo quando o sinal voltar.

## 10. Presença em palestras e trilhas

### Presença em palestras

- Cadastre a palestra em **Cadastros → Agenda**, com início, fim e local.
- No formulário da palestra, toque em **Abrir telão de presença** e abra o link no computador do auditório, com uma conta da equipe.
- O telão mostra:
  - o QR de presença, cujo código muda a cada minuto (uma foto enviada por WhatsApp para quem não está na sala expira logo);
  - o número de presenças registradas.
- O QR só vale de 15 minutos antes do início até 15 minutos depois do fim.
- O visitante lê o QR:
  - se ainda não tem perfil, responde a porta de entrada;
  - a presença fica registrada, e quem esteve presente pode avaliar a palestra (carinhas) e deixar um comentário.
- A avaliação e os comentários da palestra só a organização vê: aparecem no formulário da palestra. A lista da agenda mostra o público de cada palestra.

### Trilhas

- Em **Cadastros → Trilhas**, cadastre:
  - o nome e o prêmio;
  - o estande que entrega o prêmio;
  - a quantidade de prêmios e o prazo;
  - as etapas (palestras e estandes, até 10), a descrição e o regulamento.
- Só trilhas com a situação **Aprovada** aparecem para o visitante. O formulário traz o link e o QR da trilha para divulgar, e os números: quantos começaram, quantos completaram, quantos retiraram e quantos cumpriram cada etapa.
- O visitante vê as trilhas que passam pelo estande ou pela palestra em que está, e acompanha o progresso em `…/#trilhas`.
- Ao completar todas as etapas, recebe um cupom de uso único, por ordem de chegada, até acabar a quantidade de prêmios (decisão 3: sem sorteio).
- O estande doador digita o código do cupom em **Área do expositor → Prêmios de trilhas** e entrega o prêmio. Um cupom já usado é recusado, com a data em que foi usado. A organização também pode dar baixa.

**Pendente:** o aviso por WhatsApp ao completar a trilha (depende do provedor da API do WhatsApp Business) e a proposta de trilha feita pelo próprio estande para aprovação da organização.

## 11. Telão social (mural dos visitantes)

- **Visitante:**
  - na página do estande ou da palestra, toca em **Publicar no telão** e escreve uma mensagem de até 140 caracteres, com uma foto se quiser;
  - o celular reduz a foto e a regrava antes de enviar, o que apaga os dados embutidos, inclusive a localização do GPS;
  - menores de 18 anos não veem o botão;
  - cada visitante publica no máximo 5 vezes por hora.
- **Moderação:** em **Administração → Moderação → Mural**, aprove ou recuse cada publicação, com a foto à vista (decisão 4). Nada aparece sem aprovação.
- **Telão:** abra `…/#mural` numa TV ou num computador da organização, com uma conta da equipe (há um atalho na aba Moderação). Ele mostra:
  - o mapa da feira, com cada publicação no lote do estande ou no local da palestra;
  - um destaque que troca a cada 8 segundos, sempre com a marca da plataforma;
  - "Em alta agora": os estandes com mais pessoas diferentes nos últimos 30 minutos, a partir de 3 pessoas.
  O mapa usa a planta e os lotes desenhados em Administração → Mapa.
- **Onde a foto fica:** no banco, sem endereço público. Só a moderação e o telão a leem. No piloto, cada foto ocupa cerca de 100 KB; para volumes maiores, o plano é passar as fotos para o Storage.

## 12. Tecnoshow na Cidade

- **Cadastro:** em **Cadastros → Cidade**, cadastre bares, restaurantes, hotéis, lojas, serviços e pontos turísticos parceiros de Rio Verde e das cidades vizinhas, num raio de 250 km da feira (decisão 17). O formulário de cada parceiro traz:
  - o QR do balcão;
  - o botão **Gerar convite para o parceiro**;
  - a lista de contas com acesso, com a opção de remover.
- **Visitante:** lê o QR com o mesmo perfil anônimo da feira (quem ainda não tem perfil responde a porta de entrada) e faz check-in.
  - **Bar, restaurante e loja:** avalia com as carinhas e responde "Gostaria de ver este lugar na Tecnoshow?".
  - **Hotel:** responde a pesquisa do hóspede (noites, pessoas, faixa de diária, antecedência da reserva, motivo e satisfação), em cerca de 20 segundos.
- **Área do parceiro** (`…/#parceiro`, também pelo botão na tela inicial): o estabelecimento vê visitantes, check-ins, avaliação e visitantes por dia. O perfil e a origem dos visitantes aparecem a partir de 5 pessoas, e a origem só em grupos de 3 ou mais.
- **Hotel:**
  - informa a ocupação do dia (quartos, ocupados e diária média), que é sigilosa (decisão 16);
  - recebe a demanda da cidade: ocupação e diária média, só nos dias com 3 ou mais hotéis informantes;
  - vê o resumo dos próprios hóspedes a partir de 5 respostas.
- **Organização** (**Administração → Cidade**):
  - visitantes na cidade e quantos passaram pela feira e pela cidade;
  - prospecção de expositores, com os estabelecimentos mais pedidos para expor na feira;
  - perfil dos hóspedes (a partir de 5 respostas);
  - transbordamento por município do hotel (municípios com menos de 3 hotéis entram em "outras cidades");
  - ocupação média da cidade;
  - tabela dos parceiros.

## 13. Ao vivo: perguntas, assuntos em alta e "acontecendo agora"

- **Perguntas ao vivo:**
  - na página da palestra, quem registrou presença envia até 3 perguntas (menores de 18 anos não perguntam);
  - a pessoa da equipe que media abre **Cadastros → Agenda → (palestra) → Mediar perguntas ao vivo** (`…/#mediar-<id>`), de preferência no celular, e aprova, oculta ou marca como respondida;
  - as perguntas aprovadas aparecem para o público, que vota (▲), e as 3 mais votadas aparecem no telão de presença do auditório.
- **Assuntos em alta:** palavras citadas por 3 ou mais pessoas nas últimas 3 horas, só em textos públicos já aprovados (comentários públicos, mural e perguntas no ar). Palavras comuns são ignoradas. Aparecem no telão social e na página "Acontecendo agora".
- **Acontecendo agora** (`…/#agora`, com atalho nas páginas do estande, da palestra, da cidade e das trilhas): página aberta, que se atualiza sozinha a cada minuto, com:
  - palestras em andamento e nas próximas 3 horas;
  - estandes em alta (3 ou mais pessoas na última meia hora);
  - assuntos em alta;
  - trilhas abertas.

## 14. Passaporte da Cidade

- Em **Cadastros → Trilhas**, as etapas podem incluir estabelecimentos da cidade (grupo "Cidade (Passaporte)"), e o prêmio pode ser entregue por um parceiro da cidade (campo "Ou: parceiro da cidade que entrega o prêmio").
- O visitante cumpre a etapa da cidade fazendo check-in pelo QR do balcão, e vê as trilhas que passam por ali na própria página do estabelecimento.
- O parceiro doador dá baixa no cupom em **Área do parceiro → Prêmios do Passaporte**, onde também vê quantos começaram, completaram e retiraram o prêmio.

## Proteção de dados (LGPD)

- O questionário não pede nome, CPF, telefone nem e-mail. O comentário livre pode conter dados pessoais digitados pelo visitante, e por isso só a equipe lê as respostas.
- Defina por quanto tempo guardar os dados brutos. Depois da análise, apague-os no Supabase (`delete from public.respostas where ed = '...';`) ou exporte o CSV e guarde-o em local institucional.
- Quem sair da equipe deve ser removido em **Administração → Equipe**. Se quiser, apague também a conta em Authentication.
- Se o termo de consentimento for aprovado pelo CEP, cole o texto aprovado em **Administração → Tela de abertura e termo de consentimento**. Cada versão publicada fica registrada, o que documenta qual termo cada respondente viu.
