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
2. Abra **SQL Editor**, cole todo o conteúdo de `supabase/schema.sql` e clique em **Run**.
3. Em **Authentication → Sign In / Providers**, deixe **ligado** "Allow new users to sign up" (a equipe se cadastra pelo link de convite; uma conta criada sem convite não acessa nada) e mantenha "Confirm email" ligado.
   Em **Authentication → URL Configuration**, coloque o endereço do site em **Site URL** e em **Redirect URLs** (ex.: `https://danilo-rv.github.io/Painel-Tecnoshow/**`), para o e-mail de confirmação voltar ao app.
4. Gere a chave da coleta: no SQL Editor, rode `select replace(gen_random_uuid()::text, '-', '') as chave_da_coleta;` e guarde o resultado.
5. Cadastre a edição com essa chave. Os comandos estão no fim do `schema.sql`, passo 2. O *slug* tem que bater com o campo **Edição** do app: "Tecnoshow Comigo 2027" vira `tecnoshow-comigo-2027`.
6. Crie a **sua** conta em **Authentication → Users → Add user** (marque "Auto Confirm User") e dê a ela o papel de coordenador (passo 3 no fim do `schema.sql`). O resto da equipe entra pelos convites do app.
7. Em **Project Settings → API**, copie a **Project URL** e a chave **anon** (ou *publishable*).
   Nunca use a chave `service_role` ou `sb_secret_...` no app. O `build.py` recusa essas chaves.

## 2. Publicar o site

### Opção A: GitHub Pages (automático)

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

## Proteção de dados (LGPD)

- O questionário não pede nome, CPF, telefone nem e-mail. O comentário livre pode conter dados pessoais digitados pelo visitante, e por isso só a equipe lê as respostas.
- Defina por quanto tempo guardar os dados brutos. Depois da análise, apague-os no Supabase (`delete from public.respostas where ed = '...';`) ou exporte o CSV e guarde-o em local institucional.
- Quem sair da equipe deve ser removido em **Administração → Equipe**. Se quiser, apague também a conta em Authentication.
- Se o termo de consentimento for aprovado pelo CEP, cole o texto aprovado em **Administração → Tela de abertura e termo de consentimento**. Cada versão publicada fica registrada, o que documenta qual termo cada respondente viu.
