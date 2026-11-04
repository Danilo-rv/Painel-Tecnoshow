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

---

## 8. Decisões pendentes (acumuladas)

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

---

## Histórico

- 04/11/2026: módulos A a F, cuidados, faseamento, mecanismos de dependência, viés do Observatório ITA, decisões 1 a 10.
