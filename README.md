# Tecnoshow Avalia

App de avaliação da Tecnoshow Comigo (PPG em Administração, IF Goiano). Tem três modos:

- **Coleta**: tablets da sala de avaliação, com questionário em PT, EN e ES. Funciona sem internet: as respostas ficam guardadas no tablet e são enviadas quando a conexão volta.
- **Painel ao vivo**: telão com o mapa das rotas de origem, NPS, satisfação e bacia de atração.
- **Relatório técnico**: relatório pronto para baixar em .doc, e os dados em .csv.

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
3. Em **Authentication → Sign In / Providers**, **desligue** "Allow new users to sign up". Assim só existem as contas que você criar.
4. Gere a chave da coleta: no SQL Editor, rode `select replace(gen_random_uuid()::text, '-', '') as chave_da_coleta;` e guarde o resultado.
5. Cadastre a edição com essa chave. Os comandos estão no fim do `schema.sql`, passo 2. O *slug* tem que bater com o campo **Edição** do app: "Tecnoshow Comigo 2027" vira `tecnoshow-comigo-2027`.
6. Em **Authentication → Users → Add user**, crie as contas da equipe e inclua cada uma na tabela `equipe` (passo 3 no fim do `schema.sql`).
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

## Proteção de dados (LGPD)

- O questionário não pede nome, CPF, telefone nem e-mail. O comentário livre pode conter dados pessoais digitados pelo visitante, e por isso só a equipe lê as respostas.
- Defina por quanto tempo guardar os dados brutos. Depois da análise, apague-os no Supabase (`delete from public.respostas where ed = '...';`) ou exporte o CSV e guarde-o em local institucional.
- Quem sair da equipe deve ser removido: `delete from public.equipe where user_id = '...';` e a conta apagada em Authentication.
