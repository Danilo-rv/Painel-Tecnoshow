# Tecnoshow Avalia → Plataforma Tecnoshow: caderno de ideação

Documento vivo. Reúne as ideias discutidas para a evolução do app e as decisões que ainda precisam ser tomadas antes do plano de implantação completo. Nada aqui foi implementado ainda.

Autor da proposta: Prof. Danilo Barbosa (PPG em Administração, IF Goiano; coordenador do Observatório ITA, Inteligência Territorial Analítica).

---

## 1. Visão

Fazer da Tecnoshow uma **plataforma de dois lados**: visitantes de um lado, expositores do outro, e a organização no meio. Cada interação gera dado para gestão, marketing e pesquisa.

O objetivo é que o app se torne **indispensável**, como o Instagram se tornou para o marketing:
- para **lojistas e estandes**, na gestão e na visibilidade;
- para a **organização da Tecnoshow**, na gestão, no planejamento, no engajamento e na visibilidade nacional e internacional;
- para o **Observatório ITA**, como fonte contínua de inteligência territorial sobre o agronegócio.

## 2. Tese que amarra tudo

**"A feira como plataforma de cocriação de valor."**

- **Lógica Dominante de Serviço** (Vargo & Lusch): o valor está na interação, não no estande.
- **Plataformas multilaterais e efeitos de rede** (Rochet & Tirole; Parker, Van Alstyne & Choudary): mais visitantes ativos valorizam o estande, e vice-versa.
- **Servicescape** (Bitner) e **experiência do cliente** (Pine & Gilmore; Lemon & Verhoef): o mapa, as fotos e as mensagens tornam o ambiente físico uma experiência compartilhada.
- **Gamificação pela Teoria da Autodeterminação** (Deci & Ryan): os prêmios funcionam quando atendem a autonomia, competência e pertencimento.
- **Prova social e boca a boca eletrônico** (Cialdini; Hennig-Thurau): o que os visitantes postam e avaliam orienta o fluxo da feira.

Pergunta de pesquisa possível: *como mecanismos de interação digital afetam a atratividade dos estandes e a experiência do visitante em feiras do agronegócio?*

## 3. Módulos propostos

| Módulo | O que faz | Teoria / indicador |
|---|---|---|
| A. Expositores | Cadastro por convite, segmento, posição no mapa, vitrine de produtos e lançamentos, ofertas da feira | Segmentação; mapa de calor de atratividade por setor |
| B. Visitante conectado | Sem baixar app (link ou QR). Check-in no estande pelo QR, avaliação de atendimento, favoritos | EVENTQUAL por estande; jornada do cliente |
| C. Rankings e selos | Melhor atendimento, mais visitado, mais favoritado, destaque por segmento | Reputação e sinalização; benchmarking |
| D. Interação e premiação | Desafios da Tecnoshow ou dos estandes, com sorteios e prêmios | Gamificação; marketing de incentivo |
| E. Agenda ao vivo | Palestras, demonstrações e lançamentos, com lembretes e avaliação por sessão | Gestão de eventos |
| F. Telão social | Mapa da feira com fotos e mensagens dos visitantes em tempo real, no ponto em que foram postadas | Conteúdo gerado pelo usuário; prova social |

O painel atual (mapa do Brasil, bacia de atração) é o painel **macro**: de onde as pessoas vêm. O telão social é o painel **micro**: o que acontece dentro da feira.

## 4. Cuidados já identificados

1. **Vendas não devem ser autodeclaradas para ranking.** Usar indicadores verificáveis: check-ins, favoritos, leads com consentimento, avaliação de atendimento. As vendas entram só como dado sigiloso no relatório agregado.
2. **Antifraude nos rankings:**
   - avaliar só após check-in;
   - um voto por visitante por estande;
   - mínimo de avaliações para entrar no ranking;
   - média bayesiana.
3. **Fotos e mensagens exigem moderação:**
   - imagem de terceiros e de menores (LGPD, ECA);
   - filtro automático e fila de aprovação;
   - termo de uso de imagem no envio.
4. **Visitante anônimo por padrão.** Contato só para concorrer a prêmios ou gerar lead, com consentimento específico.
5. **Funcionar com internet ruim.** Offline, como a coleta atual. QR codes grandes. Prêmios para puxar a adesão.

## 5. Faseamento inicial

| Fase | Conteúdo |
|---|---|
| 1 | Expositores, mapa da feira, check-in por QR, avaliação de atendimento, ranking |
| 2 | Agenda de palestras, painel do expositor, desafios e premiação |
| 3 | Telão social com fotos e mensagens moderadas |

Piloto possível num evento menor do IF Goiano antes da Tecnoshow.

---

## 6. Gerar dependência: o efeito "Instagram"

A dependência deve vir de **valor acumulado**, não de truques de retenção. O Instagram virou indispensável por quatro motivos, e cada um tem um equivalente aqui.

### 6.1 Onde está o público (efeito de rede)
- O expositor precisa estar porque os visitantes estão. Os visitantes usam porque é onde estão as ofertas, a agenda, os prêmios e o mapa.
- **Ponto de virada:** a organização adota o app como **canal oficial** da feira: agenda, mapa, credenciamento e premiação oficial só por ele.

### 6.2 Os dados só existem ali (custo de troca)
- Cada edição acrescenta histórico: visitas, avaliações e leads por estande, comparados ao segmento e às edições anteriores.
- Depois de 2 ou 3 edições, sair da plataforma é perder a série histórica.
- **Painel do expositor com benchmark** ("seu atendimento está 0,4 acima da média do seu segmento; você caiu 3 posições em visitas") é o gatilho mais forte de uso recorrente.

### 6.3 Virou métrica de mercado (moeda de reputação)
- **Selo "Excelência em Atendimento Tecnoshow"**, com ano e segmento, que a loja usa no próprio marketing. Como o selo azul do Instagram, ele passa a ser desejado.
- **Ranking público por segmento** divulgado na imprensa ao fim da feira.

### 6.4 Uso o ano todo, não só 5 dias (hábito)
O maior risco é o app morrer depois da feira. Ciclo anual:
- **Antes:**
  - agenda montada pelo visitante;
  - pré-agendamento de reuniões com expositores;
  - lançamentos anunciados;
  - "quem vai";
  - contagem regressiva.
- **Durante:** check-ins, desafios, telão social, painel ao vivo.
- **Depois:**
  - leads para o expositor dar retorno;
  - relatório pós-feira para cada expositor;
  - pesquisa de 30 dias ("comprou o que viu?");
  - conteúdo técnico das palestras.
- **Entressafra:**
  - boletins do Observatório ITA;
  - ofertas dos expositores;
  - eventos menores da Comigo e do IF Goiano.

### 6.5 Mecanismos complementares
- **Rodada de negócios (matchmaking B2B):** o visitante diz o que procura (pulverizador, bioinsumo, crédito) e o sistema sugere estandes e agenda horários. Gera o dado mais valioso para o expositor: a intenção de compra.
- **Leads qualificados com consentimento:** o visitante toca em "quero contato" e o expositor recebe nome, perfil (porte, cultura, região) e interesse. Isso substitui a ficha de papel e o crachá escaneado.
- **Comprador internacional:**
  - trilha em EN/ES para delegações estrangeiras;
  - agenda com tradutor;
  - indicadores de interesse por país.

  Gera visibilidade internacional e parceria possível com a ApexBrasil.
- **Painel da organização:**
  - ocupação por setor;
  - fluxo por hora;
  - palestras lotadas;
  - estandes sem visita;
  - alertas.

  É a "sala de controle" da feira.
- **Relatórios para patrocinadores:** alcance, interações e perfil do público. Justifica e valoriza a cota de patrocínio.
- **Credenciamento integrado (futuro):** se o ingresso ou credencial gerar o identificador do visitante, a adesão chega perto de 100%.

### 6.6 Limites éticos (para a dependência não virar problema)
- Nada de padrões manipulativos: rolagem infinita, notificações excessivas, escassez falsa.
- O visitante controla seus dados: pode apagar a conta, ver o que compartilhou e retirar consentimentos.
- Regras claras e públicas para rankings e prêmios.
- Isso também é tema de pesquisa: governança de plataformas e confiança.

## 7. Viés do Observatório ITA (Inteligência Territorial Analítica)

A feira como **sensor territorial**: cinco dias por ano em que o agronegócio de uma região inteira se concentra num lugar e gera dados.

- **Atlas da bacia de atração:** fluxos de origem por município, porte e cultura, ano a ano. Mostra a área de influência real de Rio Verde e da Comigo.
- **Difusão de inovações** (Rogers): quem adota o quê, de onde vem e com que intenção. Os check-ins em estandes de tecnologia viram indicador de difusão tecnológica por microrregião.
- **Redes interorganizacionais** (análise de redes sociais): quais estandes compartilham visitantes. Revela complementaridades e possíveis parcerias e clusters (APLs).
- **Impacto econômico territorial:** gasto dos visitantes por município de origem, com multiplicadores regionais e efeito em hotelaria, alimentação e serviços de Rio Verde.
- **Índice Tecnoshow de Inovação Agro:** um indicador anual, com metodologia publicada, sobre intenção de adoção tecnológica, segmentos em alta e regiões emergentes. Dá visibilidade nacional à feira e ao Observatório, como os índices da FGV ou do Cepea.
- **Painel aberto de dados:** dados agregados e anonimizados publicados pelo ITA, para imprensa, prefeituras e pesquisadores. Gera citações, matérias e reputação.
- **Comparação entre feiras:** com o mesmo instrumento aplicado em outras feiras (Agrishow, Show Rural, Coopavel, Bahia Farm Show), o ITA passa a ser referência nacional em inteligência de feiras agro.
- **Cruzamento com dados públicos** (IBGE, PAM, PPM, CAR, Censo Agro): normaliza os fluxos por população e PIB agropecuário. Base do modelo gravitacional, que mostra onde a feira capta abaixo do potencial.
- **Produção acadêmica contínua:** dissertações, artigos e TCCs a partir da mesma base, com dados longitudinais.

## 8. Valor para o visitante (por que o produtor abre o app sem precisar de prêmio)

Princípio: o app precisa resolver **tarefas reais** do visitante (*jobs to be done*, Christensen). O prêmio atrai no primeiro uso; a utilidade é o que faz voltar.

| Tarefa do visitante | O que o app oferece |
|---|---|
| "Quero ver o que é novo para a minha lavoura ou criação" | Filtro por cultura e atividade (soja, milho, algodão, pecuária de corte e de leite…): lançamentos, estandes e palestras que interessam |
| "Não quero me perder nem perder tempo" | Mapa da feira com rota até o estande, agenda pessoal com alerta, informações de estacionamento, filas e clima |
| "Preciso comparar antes de decidir" | Favoritos lado a lado (máquinas, insumos, condições da feira) e um **"caderno da feira"** para levar para casa e decidir com a família ou o sócio (PDF e envio por WhatsApp) |
| "Quero a melhor condição" | Ofertas válidas só na feira, simulação de crédito e consórcio com bancos e a cooperativa |
| "Quero aprender" | Resumos e materiais das palestras e dos estandes, reunidos num lugar só |
| "Quero ser lembrado" | Histórico pessoal ("sua 5ª Tecnoshow"), selo de visitante fiel, contatos dos estandes que visitou |
| "Quero ser ouvido" | Avaliações que viram melhorias visíveis na edição seguinte: "vocês pediram, fizemos" |

Pontos de desenho:
- **WhatsApp como porta de entrada.** O produtor rural vive no WhatsApp. Um assistente oficial no WhatsApp (agenda, mapa, "caderno da feira", ofertas) pode ter mais adesão que qualquer app. O link web continua para o que precisa de tela (mapa, comparação).
- **Sem atrito:** abre por QR ou link, sem baixar nada e sem senha; o cadastro só é pedido quando há benefício claro (prêmio, lead, caderno).
- **Público ampliado:** trilhas para a família, estudantes e delegações estrangeiras.

## 9. Sustentabilidade financeira

Custos esperados: a infraestrutura é barata (dezenas a poucas centenas de dólares por mês). O custo real está em **pessoas** (desenvolvimento, suporte, moderação durante a feira), em material (QR codes, sinalização) e em prêmios.

Fontes de receita, da mais imediata à mais escalável:

| Fonte | Como funciona |
|---|---|
| **Expositor freemium** | Básico grátis (vitrine, check-in, avaliações). Premium: leads, benchmark com o segmento, relatório pós-feira, destaque no mapa, prioridade na rodada de negócios. Pode ser vendido à parte ou incluído no contrato do estande pela organização |
| **Patrocínio** | Telão social com marca, desafios e prêmios patrocinados, "rota patrocinada", cota do Índice Tecnoshow de Inovação Agro |
| **Parceiros na cidade** | Bares, restaurantes e hotéis pagam um valor baixo pelo selo "Parceiro Tecnoshow" e pela vitrine no app (seção 10) |
| **Inteligência e dados agregados** | Relatórios setoriais para empresas, associações e governo; estudos para prefeituras e secretarias de turismo; sempre anonimizados e agregados |
| **Licenciamento para outras feiras (SaaS)** | O mesmo sistema e o mesmo instrumento, oferecidos a outras feiras agro. É a fonte mais escalável e a que leva o nome do ITA para fora de Goiás |
| **Fomento** | FAPEG, CNPq, Finep, Sebrae, editais de inovação e extensão. Financiam o desenvolvimento inicial e a pesquisa |

Arranjo institucional possível:
- O Marco Legal de CT&I (Leis 10.973/2004 e 13.243/2016) permite ao IF Goiano, como ICT:
  - licenciar a tecnologia;
  - firmar acordos de parceria com empresas;
  - ter receitas geridas por uma **fundação de apoio**.
- Mais adiante, uma **spin-off** do Observatório ITA pode assumir a operação comercial, enquanto o ITA mantém a pesquisa e os dados abertos.

Sequência sugerida: 1ª edição gratuita e financiada por fomento e patrocínio (provar valor) → 2ª edição com premium para expositores e parceiros da cidade → 3ª edição em diante com licenciamento para outras feiras.

## 10. Tecnoshow na Cidade: o território expandido durante os 7 dias

A feira não termina no portão. À noite e nos intervalos, o visitante consome a cidade, e esse rastro é o que hoje ninguém mede.

### 10.1 Comércio (bares, restaurantes, lojas)
- Selo **"Parceiro Tecnoshow"** com QR no balcão ou na mesa. O visitante faz check-in, avalia e responde: **"Gostaria de ver este estabelecimento na feira?"**
- Isso vira um **funil de prospecção de novos expositores** (gastronomia, artesanato, serviços), com evidência de demanda para convencê-los: "320 visitantes pediram vocês na feira".
- Os check-ins mostram onde o visitante gasta à noite: **mapa de calor do consumo urbano** durante a feira.

### 10.2 Hospedagem
- Pesquisa curta do hóspede pelo QR do hotel:
  - origem;
  - número de noites e de pessoas;
  - faixa de diária;
  - antecedência da reserva;
  - motivo da viagem;
  - satisfação.
- Com a ocupação diária informada pelos hotéis (sigilosa, publicada só de forma agregada), o ITA consegue:
  - **prever a demanda de hóspedes** da próxima edição;
  - identificar **déficit de leitos** e o transbordamento para cidades vizinhas (Jataí, Santa Helena, Montividiu…);
  - orientar a hospedagem alternativa (casas de família, aluguel por temporada);
  - mostrar o perfil e o gasto real do visitante, que hoje é estimado.

### 10.3 Outras interações na cidade
- **Passaporte da Cidade:** desafios fora da feira (jantar em 2 restaurantes parceiros, visitar um ponto turístico), com prêmios do comércio local. Incentiva o visitante a ficar mais tempo e a gastar na cidade.
- **Agenda noturna:** shows, eventos e happy hours dos expositores.
- **Mobilidade:** pontos de táxi e transporte, estacionamentos, tempo até a feira.
- **Serviços úteis:** farmácias, oficinas, postos, saúde e segurança.
- **Jornada completa:** o mesmo identificador anônimo une feira e cidade. Ele mostra, por exemplo, que quem visita estandes de máquinas fica mais noites e gasta mais em restaurantes.

### 10.4 Base teórica e parceiros
- Turismo de negócios e eventos (MICE), gestão de destinos (DMO) e **Destinos Turísticos Inteligentes** (metodologia do MTur e da SEGITTUR).
- Transbordamento espacial e impacto econômico de eventos com dados observados, não só declarados.
- Parceiros naturais: Prefeitura e Secretaria de Turismo, associação comercial (ACIRV/CDL), Sebrae, sindicato de hotéis e bares. Também são possíveis financiadores (seção 9).

### 10.5 Cuidados
- **Sem rastreamento contínuo por GPS.** Só check-ins pontuais e consentidos por QR, o que preserva a privacidade e evita rejeição.
- **Dados comerciais dos hotéis e bares são sigilosos.** Só publicar agregados com pelo menos 3 estabelecimentos por grupo.
- **Avaliação de comércio pode gerar conflito.** São necessários regras públicas, direito de resposta e avaliação só após check-in.
- **Amostra autosselecionada:** quem usa o app não representa todos. Calibrar com a contagem da portaria e com os dados dos hotéis.

---

## 11. Decisões pendentes (acumuladas)

Perguntas que serão feitas todas de uma vez ao final da ideação.

**Da etapa de módulos**
1. Mapa da feira: existe planta oficial com a numeração dos estandes?
2. Expositores: cadastrar todos ou começar com um grupo piloto de 20 a 40?
3. Prêmios: quem patrocina e quem entrega? (Sorteio pode exigir autorização pela Lei 5.768/71; concurso cultural ou premiação por mérito é mais simples.)
4. Fotos: moderação manual pela equipe durante a feira, ou começar só com mensagens de texto?
5. Plataforma: seguir só com Supabase e site próprio, deixando o Artifact de lado?

**Da etapa de dependência e ITA**
6. Governança: a plataforma é da Tecnoshow/Comigo, do IF Goiano/ITA, ou parceria formal (acordo de cooperação)? Isso define quem é dono e controlador dos dados (LGPD).
7. Modelo de negócio: o painel do expositor é gratuito para todos, tem um plano premium, ou entra no pacote do estande?
8. Canal oficial: a organização aceita usar o app como canal oficial (agenda, mapa, premiação)? Há integração possível com credenciamento e ingressos?
9. Dados abertos: o que o ITA pode publicar, com que nível de agregação e com que periodicidade?
10. Abrangência: o instrumento será oferecido a outras feiras? Isso muda a arquitetura (uma base por feira ou multifeira).

**Da etapa de visitante, sustentabilidade e cidade**
11. Canal principal do visitante: WhatsApp oficial (a API tem custo por conversa), link web, ou os dois?
12. Bancos e cooperativa: há interesse em oferecer simulação de crédito e consórcio dentro do app?
13. Estrutura para receber recursos: fundação de apoio do IF Goiano, convênio com a Comigo, spin-off, ou uma combinação?
14. Preço: cobrar o premium já na 1ª edição ou só depois de provar valor (sugestão: só a partir da 2ª)?
15. Parceiros na cidade: quais podem ser formais desde o início (Prefeitura, Secretaria de Turismo, ACIRV/CDL, Sebrae, sindicato de hotéis e bares)?
16. Hotéis: aceitariam informar a ocupação diária (sigilosa, publicada só de forma agregada)?
17. Alcance territorial: só Rio Verde, ou também as cidades vizinhas que recebem hóspedes durante a feira?

---

## Histórico

- 04/11/2026: módulos A a F, cuidados, faseamento, mecanismos de dependência, viés do Observatório ITA, decisões 1 a 10.
- 05/11/2026: valor para o visitante, sustentabilidade financeira, Tecnoshow na Cidade (comércio, hospedagem, interações urbanas), decisões 11 a 17.
