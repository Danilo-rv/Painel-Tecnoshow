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

## 11. Governança dos dados

Com tantos atores (visitante, expositor, comércio, hotel, organização, ITA, público), a confiança é o ativo central. Se um expositor desconfiar que seus dados vão para o concorrente, ou um hotel que sua ocupação vai vazar, a plataforma perde o valor.

### 11.1 Quem é dono de quê

| Dado | Dono / controlador | Quem acessa |
|---|---|---|
| Dados pessoais do visitante (contato, histórico) | O próprio visitante; a plataforma é controladora | Só ele, e o expositor a quem ele **escolheu** enviar contato |
| Leads, visitas e avaliações de um estande | O expositor | O expositor (completo) e a organização (agregado) |
| Dados comerciais de hotéis e bares (ocupação, diária) | O estabelecimento | A organização e o ITA, só agregados (mínimo de 3 a 5 por grupo) |
| Dados operacionais da feira (fluxo, ocupação por setor) | A organização | A organização; o ITA para pesquisa |
| Base de pesquisa anonimizada | O Observatório ITA | Pesquisadores autorizados; versão aberta agregada para o público |

### 11.2 Instrumentos
- **Acordo de cooperação técnica** entre Comigo, IF Goiano e, depois, Prefeitura e parceiros. Define papéis LGPD (controlador, operador), finalidades e o uso para pesquisa.
- **Encarregado de dados (DPO)** nomeado e **Relatório de Impacto à Proteção de Dados (RIPD)**, por envolver localização, imagem e muitos titulares.
- **Bases legais por finalidade:**
  - consentimento para leads, fotos e prêmios;
  - legítimo interesse para métricas operacionais;
  - pesquisa com anonimização (art. 7º, IV, e art. 11, II, c, da LGPD).
- **Aprovação no CEP** para a parte de pesquisa, com o termo de consentimento versionado no próprio sistema.
- **Política de retenção:** dados pessoais apagados ou anonimizados após um prazo definido; a base de pesquisa guarda só o anonimizado.
- **Regra de publicação:** nenhum número aberto com grupos menores que 5 (anonimato k ≥ 5).
- **Comitê gestor** com representantes da organização, do ITA, dos expositores e do comércio. Aprova regras de ranking, prêmios e publicação de dados.
- **Painel de transparência para o visitante:** o que foi coletado, com quem foi compartilhado, botão para apagar.

## 12. Indicadores-chave (o "painel do sucesso")

**Métrica norte sugerida:** *interações qualificadas por visitante*. Conta check-in em estande, avaliação, lead, palestra assistida ou check-in na cidade. Ela resume o valor para os dois lados da plataforma.

| Camada | Indicadores |
|---|---|
| Adoção | % do público da portaria que usa o app; % de expositores ativos; nº de parceiros na cidade |
| Engajamento | Interações por visitante; retorno em 30 dias; uso na entressafra; adesão aos desafios |
| Valor para o expositor | Leads por estande; nota de atendimento; renovação do premium; NPS do expositor |
| Valor para a organização | NPS do visitante; reocupação de estandes; novos expositores vindos do funil da cidade; patrocínio captado |
| Território (ITA) | Gasto na cidade por origem; ocupação hoteleira; transbordamento regional; raio da bacia de atração; difusão tecnológica por microrregião |
| Visibilidade | Matérias na imprensa; citações do Índice; visitas ao painel aberto; feiras que licenciaram o sistema; visitantes estrangeiros |
| Sustentabilidade | Receita sobre custo; % de autossustentação sem fomento |
| Qualidade dos dados | Cobertura da amostra versus portaria; viés por perfil; taxa de respostas inválidas |

Referências para estruturar: framework **HEART** (Google) para experiência e métricas **AARRR** para o funil de adoção. Também é possível usar um **Balanced Scorecard** da plataforma, que conversa bem com o mestrado em administração.

## 13. Estratégia de implantação no território

### 13.1 Cronograma reverso (a partir da data da feira)

| Prazo | Ações |
|---|---|
| 6 meses antes | Acordos institucionais, comitê gestor, encarregado de dados, submissão ao CEP, captação de fomento e patrocínio |
| 4 meses antes | Mapa da feira, cadastro dos expositores, regulamento dos prêmios |
| 3 meses antes | Equipe de campo visita bares, restaurantes e hotéis para adesão ao selo "Parceiro Tecnoshow" |
| 2 meses antes | Materiais com QR, treinamento dos expositores e parceiros, campanha (rádio, sindicatos rurais, base de cooperados, WhatsApp) |
| 1 mês antes | Piloto num evento menor; ajustes; agenda e "quem vai" abertos ao público |
| Durante | Embaixadores nos portões, plantão de moderação e suporte, sala de controle |
| 30 dias depois | Relatórios para expositores, parceiros e organização; devolutiva pública; lançamento do Índice |

### 13.2 Papel dos alunos do mestrado
- **Agentes de campo:** adesão de comércio e hotéis, embaixadores na feira e coleta qualitativa (entrevistas com expositores e hoteleiros).
- **Cada mestrando adota um eixo** (hotelaria, comércio noturno, um segmento de expositores, difusão tecnológica, mobilidade), que vira capítulo ou dissertação inteira.
- **Método:** pesquisa-ação. O grupo intervém (cria e ajusta a plataforma) e estuda os efeitos da intervenção, o que é muito adequado a um mestrado profissional.
- Envolver graduação e técnico (bolsas de extensão, disciplina prática), com certificação de horas.

## 14. Carona para a feira: viável, mas com desenho cuidadoso

**Riscos de uma carona aberta entre desconhecidos:**
- **Segurança pessoal:** assalto, assédio, violência. Um incidente grave associado à marca Tecnoshow, Comigo ou IF Goiano seria muito danoso.
- **Segurança viária:** rodovias com tráfego pesado de caminhões e consumo de álcool à noite.
- **Responsabilidade:** a plataforma pode ser questionada se não tiver verificação mínima.
- **Regulação:** cobrar além da divisão de custos vira transporte remunerado irregular (Lei 12.587/2012 e regras municipais). A divisão de custos sem lucro, como faz o BlaBlaCar, é aceita.

**O que recomendo, em vez de uma carona aberta:**
1. **Transporte oficial planejado com os dados da plataforma.** O ITA sabe de onde vêm os visitantes e onde se hospedam. Isso permite planejar **vans e ônibus** de cidades vizinhas e de hotéis, com horários e pontos de embarque. É o uso mais seguro e o mais "inteligência territorial".
2. **Caravanas institucionais:** sindicatos rurais, cooperativas, prefeituras e escolas cadastram suas caravanas, e o visitante se inscreve. O responsável é identificado.
3. **Carona só em grupos fechados e verificados** (opcional, numa segunda fase):
   - cooperados, funcionários de expositores, alunos e servidores com e-mail institucional;
   - perfil verificado e avaliação mútua;
   - compartilhamento da viagem com um contato de confiança;
   - só divisão de custos, sem menores desacompanhados, e termo de uso claro;
   - ou parceria com um app já existente, em vez de operação própria.

**Ganhos extras:** dados de demanda de transporte por origem e um indicador de **pegada de carbono da feira** (km × modo de transporte). É um indicador ESG que a organização pode divulgar e reduzir a cada edição.

## 15. Identidade e nome

**Proposta: ITA-e (Inteligência Territorial em Eventos).**

Pontos fortes:
- Liga a plataforma ao Observatório ITA e transfere a reputação acadêmica para o produto (e vice-versa).
- "Em eventos" deixa claro que serve a qualquer feira, o que favorece o licenciamento (seção 9).
- O "-e" sugere ao mesmo tempo *eventos* e *eletrônico*, como e-mail ou e-commerce.

Pontos de atenção:
- **Confusão com o ITA** (Instituto Tecnológico de Aeronáutica), marca muito conhecida no Brasil. Fora de Goiás, "ITA" remete primeiro a ele. Vale uma busca de anterioridade no INPI (classes 9, 35, 41 e 42) antes de adotar.
- **Hífen:** atrapalha domínio, hashtag e a forma de falar ("ita-é" ou "ita-ê"?). Uma forma sem hífen (ITAe) ou uma pronúncia oficial definida resolve.
- **Para o visitante, a sigla não diz nada.** O produtor não vai abrir "ITA-e"; ele abre "a Tecnoshow".

**Sugestão de arquitetura de marca em dois níveis:**
- **Marca-mãe (institucional, científica e comercial):** ITA-e. Aparece para organizadores, expositores, patrocinadores, imprensa e outras feiras: "Plataforma ITA-e", "Índice ITA-e de Inovação Agro", "powered by ITA-e".
- **Marca do evento (para o visitante):** com o nome da feira, por exemplo "Tecnoshow Conecta", "Tecnoshow+", "Minha Tecnoshow". Cada feira que licenciar o sistema tem a sua: "Agrishow Conecta, com tecnologia ITA-e".

**Alternativas na mesma linha, caso a busca no INPI ou a confusão com o ITA pesem:**

| Nome | Ideia |
|---|---|
| ITE (Inteligência Territorial de Eventos) | Mais curta, sem hífen; perde o elo direto com o ITA |
| ITA Eventos / ITA Feiras | Mais explícita, menos marca |
| Radar ITA | Monitoramento ao vivo; boa para o painel e para o Índice |
| Pulso | "O pulso da feira", em tempo real; fácil de falar em PT/EN/ES |
| Bacia | Referência à bacia de atração, conceito central do projeto |
| Rota | Origens, deslocamentos e jornada do visitante; combina com o mapa de arcos |
| Atlas ITA | Acento cartográfico e territorial; ótimo para o produto de dados abertos |
| Elo | Conexão entre visitante, expositor, cidade e organização |

Combinações possíveis: "ITA-e" como plataforma, "Radar ITA-e" como painel ao vivo, "Atlas ITA-e" como portal de dados abertos, "Tecnoshow Conecta" como app do visitante.

### 15.1 Variação "iTA" e nomes com "eventos" em inglês

**iTA (i minúsculo):**
- Lê-se como *intelligence* ou *interativo* e tem cara de produto digital.
- Resolve o hífen.
- Ainda carrega a confusão com o ITA da Aeronáutica.
- Fica muito próximo do **"iti"**, o banco digital do Itaú, com risco de confusão de marca no INPI.
- O "i" minúsculo também lembra a Apple (iPhone, iPad), o que dá sensação de imitação.

**Critério para o inglês:** o público principal é o produtor brasileiro. As palavras que ele já pronuncia sem esforço são **show** e **expo** (o próprio nome "Tecnoshow" prova isso). *Event* e *fair* são menos naturais em português; *hub*, *map* e *IQ* são conhecidas no meio de negócios.

| Grupo | Nome | Ideia | Observação |
|---|---|---|---|
| ITA + inglês | **ITA Events** | Direto: Inteligência Territorial Analítica em eventos | Claro em qualquer país; pouco distintivo como marca |
| | **ITAvents** | Fusão de ITA + *events* | Distintivo e registrável; pronúncia "itavents" pede costume |
| | **ITA Expo** | ITA + *expo* | Fácil em PT, EN e ES |
| | **ITA Hub** | Plataforma que conecta todos os atores | "Hub" já é usado por muitos |
| Só inglês | **Expolytics** | *Expo* + *analytics* | Muito descritivo do que o sistema faz; bom para vender a outras feiras |
| | **ExpoIQ** / **ShowIQ** | A "inteligência" da feira | Curto, internacional, tom de produto de dados |
| | **FairSense** | A feira "sentida" em tempo real (sensor territorial) | Bom conceito; "fair" é menos natural no Brasil |
| | **EventScape** | *Event* + *landscape*, remetendo ao *servicescape* (Bitner) | Forte base teórica; mais difícil de falar |
| Agro + território | **TerraExpo** / **TerraShow** | *Terra* (território e agro) + feira | Funciona igual em PT, EN e ES |
| | **AgroPulse** | O pulso do agro na feira | Bom para o painel ao vivo |

**Recomendação provisória:**
- **Marca-mãe:** **Expolytics** (ou **ExpoIQ**), com a assinatura "by Observatório ITA". O nome diz o que o produto faz para qualquer feira, no Brasil ou fora, e o ITA aparece como a autoridade científica por trás.
- **Para o visitante:** "Tecnoshow Conecta".
- **Alternativa, se o nome ITA precisar estar na marca:** **ITAvents** é a opção mais registrável dessa família.

Antes de escolher, verificar a disponibilidade dos finalistas:
- INPI e USPTO;
- domínios `.com.br` e `.com`;
- perfis nas redes sociais.

## 16. Requisitos de usabilidade (registrados para a próxima versão)

### 16.1 Navegação: seta de voltar em todas as telas
Situação atual:
- **Painel:** sem nenhuma forma de voltar.
- **Coleta:** só volta entre perguntas, nunca para a tela inicial.
- **Relatório:** tem um botão "Voltar", mas fica no meio dos botões de download, sem destaque.
- **Administração:** tem um botão "Voltar ao início".

Requisito:
- Uma **seta de voltar (←) no canto superior esquerdo**, no mesmo lugar e com o mesmo estilo em todas as telas, além do botão "voltar" do navegador.
- Cada tela volta para a anterior do caminho: por exemplo, relatório → início, prévia → administração.

A seta muda conforme o uso de cada tela:

| Tela | Comportamento da seta |
|---|---|
| Painel ao vivo (telão) | Aparece ao mover o mouse ou tocar na tela e some sozinha depois de alguns segundos, para não poluir o telão |
| Coleta (tablet com visitante) | **Escondida do visitante**, para ele não sair do questionário. Saída da equipe por um gesto (tocar e segurar o logotipo por 3 segundos) seguido de um código numérico definido na Administração |
| Relatório, Administração, Convite, telas da plataforma futura | Seta sempre visível |

### 16.2 Outros pontos a manter na plataforma futura
- **Breadcrumb** (início › administração › questionário) nas áreas com vários níveis: expositor, organização, ITA.
- **Botão de tela cheia** no painel e no telão social.
- **Endereços próprios para cada tela,** para guardar como favorito ou abrir direto no telão (já existe: `#painel`, `#coleta`, `#relatorio`).

## 17. Interação instantânea no QR do estande

Ao ler o QR, o visitante já cai numa tela de **um toque**, sem cadastro. É a interação de menor atrito da plataforma, e por isso a que mais gera volume de dados para o estande.

### 17.1 Dois termômetros separados
Curtir e amar medem **interesse** (quero isso); as carinhas medem **satisfação** (como fui atendido). Misturar os dois numa fileira só confunde o visitante e a análise. Por isso, dois blocos:

| Bloco | Opções | Onde se aplica | O que mede |
|---|---|---|---|
| **Interesse** | 👍 Curti · ❤️ Amei | Cada produto ou lançamento, e a loja | Atratividade e intenção de compra |
| **Atendimento** | 😀 Bom · 😐 Neutro · ☹️ Ruim | A loja (o atendimento recebido) | Satisfação (escala de carinhas, como os terminais *Happy or Not* dos aeroportos) |

- **Carinha triste pede um motivo em um toque:** fila, demora, preço, falta do produto, atendimento. Sem motivo, a nota negativa não ajuda o expositor a melhorar.
- **Comentário opcional** com emojis rápidos (🔥 👏 💡 💰 🤝) e texto. O visitante escolhe se o comentário é sobre o **produto** ou sobre a **loja**, e se é **público** ou **só para a loja**.

### 17.2 Compartilhar no Instagram e no WhatsApp
- Botão **Compartilhar** que gera um **cartão vertical para story** (1080×1920) com:
  - a foto do produto ou o perfil da loja;
  - "Estou na Tecnoshow 2027";
  - o nome do estande e a moldura oficial da feira;
  - um link curto ou QR.
- **Funcionamento técnico:** no celular, o compartilhamento nativo (Web Share) abre direto o Instagram, o WhatsApp ou outro app. Não precisa de integração com a Meta.
- **Variante "moldura":** o visitante tira uma selfie no estande com a moldura da feira e da loja. Ela alimenta o telão social (com moderação) e o story.
- **O link compartilhado é rastreável** (por exemplo, `?ref=estande-123`). Com ele, a plataforma mede quantas pessoas chegaram ao estande por causa de um compartilhamento: **alcance e efeito viral**.

### 17.3 Novas métricas para o estande

| Métrica | Leitura |
|---|---|
| Taxa de reação por visita (reações ÷ check-ins) | Quanto o estande engaja quem passa |
| Índice de "amei" (❤️ ÷ todas as reações de interesse) | Intensidade do interesse, por produto |
| Ranking de produtos por interesse | Qual lançamento atraiu mais; serve ao planejamento do expositor |
| Índice de satisfação (% 😀 − % ☹️) e motivos de ☹️ | Atendimento e o que corrigir, hora a hora |
| Compartilhamentos e alcance (cliques no link) | Visibilidade gerada fora da feira |
| Conversão do compartilhamento (cliques que viraram check-in) | Boca a boca que trouxe gente de verdade |
| Curva por horário | Pico de interesse e momento de reforçar a equipe |

Base teórica: escalas de satisfação com carinhas (CSAT), resposta afetiva ao serviço, **boca a boca eletrônico** e **marketing viral** (coeficiente viral). O ranking de produtos por interesse dialoga com o modelo AIDA: atenção → interesse → desejo → ação.

### 17.4 Cuidados
- **Uma reação por visitante, por item.** Ela pode ser trocada, mas não repetida, e é atrelada ao check-in, o que evita "torcida organizada" e robôs.
- **Negativos:**
  - a carinha triste e os comentários negativos vão **só para o painel da loja e da organização**;
  - em público aparecem apenas os indicadores agregados, e só com um número mínimo de avaliações;
  - isso protege o expositor de exposição injusta e mantém a adesão.
- **Comentários públicos passam pela moderação** (filtro automático + fila), como no telão social.
- **Imagem:** a selfie com moldura segue o termo de uso de imagem. Fotos com menores não vão ao telão.

## 18. Administração geral, papéis e habilitação de aparelhos

### 18.1 Tela de login do administrador geral
- Entrada própria (por exemplo, `#admin-geral`), separada do app do visitante.
- **Verificação em duas etapas obrigatória** (aplicativo autenticador) para o administrador geral e para a organização. São as contas mais sensíveis da plataforma.
- Sessão com tempo limite e encerramento remoto ("sair de todos os aparelhos").

### 18.2 Hierarquia de papéis (controle de acesso por papel)

| Papel | Pode | Não pode |
|---|---|---|
| **Administrador geral** | Inserir, editar e excluir tudo: edições, expositores, segmentos, mapa, agenda, desafios, prêmios, parceiros da cidade, usuários e papéis; configurar aparelhos; ver auditoria | Ver dados pessoais de visitantes além do necessário (acesso registrado e justificado) |
| **Coordenação de pesquisa (ITA)** | Questionário, relatórios, base anonimizada, dados abertos | Alterar expositores, prêmios e aparelhos |
| **Organização da feira** | Expositores, mapa, agenda, desafios, moderação, sala de controle | Alterar papéis de outros administradores |
| **Equipe operacional treinada** | **Habilitar e desabilitar aparelhos** (tablets de coleta, painel central, painéis de estande), ver o estado deles, dar suporte no local | Editar conteúdo, ver respostas individuais |
| **Moderador** | Aprovar ou recusar fotos, mensagens e comentários públicos | Todo o resto |
| **Expositor (gestor da loja)** | Perfil da loja, produtos, ofertas, sua equipe de atendentes, seu painel e seus leads | Dados de outras lojas |
| **Atendente do estande** | Ver o painel da loja durante a feira, registrar atendimento | Editar a loja |
| **Patrocinador** | Ver os resultados das próprias cotas: alcance, interações, desafios e molduras patrocinadas | Dados de visitantes, expositores e outros patrocinadores |
| **Parceiro da cidade** | Perfil do estabelecimento, seu painel | Dados de outros parceiros |
| **Visitante** | Interagir, gerenciar e apagar seus dados | — |

Princípio do **menor privilégio**: cada pessoa recebe só o papel de que precisa. Uma pessoa pode ter mais de um papel. O papel "coordenador" do app atual vira "Coordenação de pesquisa" nessa hierarquia.

### 18.3 Editar, inserir e excluir com segurança
- **Cadastros com CRUD completo** para edições, expositores, segmentos, estandes no mapa, produtos, agenda, desafios, prêmios, parceiros, usuários, aparelhos e questionário.
- **Exclusão vai para a lixeira** (pode ser restaurada por 30 dias). Exclusão definitiva só pelo administrador geral, com confirmação.
- **Importação em lote** por planilha (expositores, estandes, agenda), porque cadastrar centenas de estandes um a um não é viável.
- **Registro de auditoria:** quem fez o quê, quando e de qual aparelho. Ninguém consegue apagar esse registro, nem o administrador geral.

### 18.4 Habilitação de aparelhos pela equipe treinada
Três tipos de aparelho:

| Aparelho | Função |
|---|---|
| **Tablet de coleta** | Questionário da sala de avaliação |
| **Painel central (telão)** | Mapa de arcos, indicadores, telão social |
| **Painel de estande** | Tela no estande (TV ou tablet) com os números da loja ao vivo: reações, satisfação, fila, QR para interagir |

Como habilitar:
1. A pessoa da equipe operacional entra no app com sua conta e abre **Aparelhos → Habilitar**.
2. O aparelho novo mostra um **código de pareamento** (6 dígitos ou QR), que vale por poucos minutos.
3. A equipe digita ou lê o código e escolhe o tipo, o número (Tablet 3) e, para painel de estande, qual estande.
4. O aparelho recebe uma **credencial própria**, limitada à sua função. O tablet de coleta só envia respostas; o painel de estande só lê os números daquele estande. Nenhuma senha pessoal fica guardada no aparelho.
5. O aparelho entra **travado na função** (modo quiosque). A saída exige o gesto + código da equipe (decisão 24).

O administrador geral e a equipe veem a **lista de aparelhos ao vivo**: online ou offline, respostas na fila, última sincronização, versão do questionário, bateria quando disponível. Um aparelho perdido é **desabilitado com um toque**, e a credencial dele deixa de valer na hora.

Isso substitui o "chave da coleta" de hoje (uma chave igual em todos os tablets) por uma credencial por aparelho, que é mais seguro e mais fácil de controlar.

### 18.5 Equipe treinada
- Só quem tem o selo **"treinado"** no cadastro pode habilitar aparelhos. O selo é dado pelo administrador geral ou pela organização depois do treinamento.
- **Módulo de treinamento no próprio app:** vídeos curtos, um passo a passo e um teste rápido. O selo pode ser liberado automaticamente com aprovação no teste.
- **Escala da equipe por dia e turno**, com quem está de plantão em cada setor da feira.
- Para o ITA: o treinamento e a escala também documentam a equipe de campo da pesquisa (seção 13.2).

## 18-A. Benchmark: app oficial da Tecnoshow 2026

Análise feita em 06/11/2026 a partir de 18 capturas de tela enviadas pelo coordenador.

**O que o app tem:** início com clima, busca, atalhos (Estacionar, Locais, Mapa), carrossel de patrocinadores, 24 categorias com ícones, agenda por dia (6 a 9 de abril de 2026), lista de expositores com categoria e distância, locais (auditórios, banheiros, praças de alimentação), rota a pé até o local, "Onde estacionei" offline e faixa de apoio institucional.

**Pontos fortes a manter ou reaproveitar**
- Visual limpo, barra inferior com 4 abas, ícones claros por categoria.
- "Onde estacionei" funcionando sem internet: muito útil e alinhado ao nosso princípio offline.
- Agenda por dia com foto e palestrante.
- As **24 categorias** servem de taxonomia inicial dos segmentos (seção 3, módulo A).
- Espaço de patrocínio já aceito pelo público.

**Problemas observados**
| Problema | Onde | Efeito |
|---|---|---|
| Distância e rota calculadas da cidade como se fosse dentro da feira ("A 7,8 km" em todos os itens; "123 min · 10.327 m" a pé) | Locais, Expositores, navegação | Fora da feira, a informação não ajuda; dentro dela, faltam metros e a planta |
| "Modo mapa" sobre o mapa de ruas, sem a planta da feira | Locais | Não orienta entre estandes e pavilhões |
| Tags HTML aparecendo no texto (`<p>…</p>`) | Detalhe de evento | Falha de tratamento do conteúdo |
| Eventos sem descrição e sem local (qual auditório?) | Detalhe de evento | O visitante não sabe aonde ir |
| Título repetido duas vezes no detalhe do evento | Detalhe de evento | Ocupa a tela sem informação nova |
| Grafia "Technoshow 2026" | Início | Erro na própria marca |
| Capitalização irregular ("Automóveis E Utilitários", "AGENER SAUDE ANIMAL", "(comigo)") | Categorias, expositores, agenda | Aparência de cadastro sem revisão |
| Categorias possivelmente trocadas (ADAMA, empresa de defensivos, aparece como "Sementes") | Expositores | Busca por segmento falha |
| Locais e alguns expositores sem foto ou logo | Locais, Expositores | Lista pouco atrativa |
| Sem idiomas, apesar de "Diálogo com Embaixadas" na agenda | Todo o app | Exclui o público estrangeiro |
| Sem lembrete, sem "adicionar à agenda", sem compartilhar | Agenda | Nenhum hábito de uso |
| Nenhuma interação: não há avaliação, curtida, favorito, contato, check-in ou QR | Todo o app | O app é um catálogo de mão única e não gera dados para ninguém |

**Leitura estratégica**
- O app oficial é um **guia informativo**: diz o que existe e onde está.
- A plataforma ITex é a **camada de interação e inteligência**: o que o visitante fez, o que achou e de onde veio.
- **Posicionamento decidido (decisão 31):** a ITex **não é um aplicativo da feira e não compete com o app oficial**. Ela é uma camada de dados e inteligência que agrega valor ao app e à feira, para ser comercializada no futuro (a organizadores, expositores, patrocinadores, governo e outras feiras).
- Para o visitante, a ITex aparece só em **pontos de contato leves**, sempre abertos por QR ou link e sem instalação: página do estande (check-in, reações, carinhas, contato), check-in em palestra, desafios, pesquisa do hóspede e do comércio, e o questionário. Agenda, locais, estacionamento e navegação continuam no app oficial.
- O app oficial pode apontar para esses pontos de contato (link ou QR), se a Comigo quiser, mas a ITex não depende disso.
- Do app oficial, a ITex aproveita **informação complementar**: o mapa (base da planta dos lotes, em `docs/mapa-2026/`), a agenda de eventos (base dos check-ins e desafios), as categorias e o cadastro de expositores e locais.

**Ajustes que isso gera na plataforma**
- Mapa com **duas escalas**: fora da feira, rota de carro ou transporte e link para o app de mapas do celular; dentro dela, a planta oficial com distâncias em metros.
- Detalhe de evento sempre com local (ligado à planta), descrição, lembrete, "adicionar à agenda" e avaliação da sessão.
- Revisão de cadastro (grafia, capitalização, categoria) antes de publicar, com o expositor confirmando os próprios dados.
- **Número de dias configurável por edição.** A Tecnoshow 2026 teve 4 dias (6 a 9 de abril), mas o questionário atual oferece "Todos os 5 dias". A opção de dias precisa vir do cadastro da edição.
- Manter "Onde estacionei" offline e o clima no início.

## 18-B. Agenda como mecanismo de gamificação

A agenda oficial vira a base de **trilhas**: combinações de check-ins que dão um brinde a quem completa.

**Exemplo proposto pelo coordenador:** ler o QR de duas palestras específicas e visitar o estande da Prefeitura de Rio Verde (lote 51) → brinde da Prefeitura.

**Como funciona**
1. **Quem lança a trilha:** a organização, um estande, um patrocinador ou um parceiro (a Prefeitura, no exemplo). A trilha define as etapas, o prêmio, o estoque e o prazo, e a organização aprova.
2. **Check-in em palestra:**
   - um QR projetado no telão ou na entrada do auditório, válido só durante a sessão (do início até 15 minutos após o fim);
   - um código que muda a cada poucos minutos, para não valer uma foto do QR enviada pelo WhatsApp;
   - só conta uma vez por visitante.
3. **Check-in no estande:** o QR do estande, que já existe na plataforma.
4. **Progresso:** o visitante vê as etapas cumpridas na página da trilha e recebe aviso pelo WhatsApp ao completar.
5. **Resgate do brinde:** um cupom de uso único, mostrado no celular. O atendente do estande doador lê o cupom e dá baixa, e o estoque é controlado pelo banco.

**Tipos de trilha**

| Tipo | Exemplo |
|---|---|
| Conteúdo + estande | 2 palestras de bioinsumos + estande da Embrapa → brinde |
| Institucional | 2 palestras + estande da Prefeitura → brinde da Prefeitura |
| Setorial | Visitar 5 estandes de máquinas → prêmio por ordem de chegada ou por pontos, sem sorteio (decisão 3) |
| Território | Palestra + jantar num restaurante parceiro → desconto no parceiro |
| Família | Teatro Sementinhas do Agro + Praça das Flores → brinde infantil |

**Dados que a trilha gera (e que têm valor comercial)**
- Para o patrocinador da trilha:
  - quantos começaram e quantos completaram;
  - perfil e origem de quem completou;
  - em que etapa as pessoas desistiram;
  - custo por participante.
- Para a organização: público por palestra (contado por check-in, não estimado), lotação por palco e horário, e quais temas atraem quais perfis.
- Para o expositor do estande da trilha: o fluxo extra que a trilha trouxe.
- Para o ITA: a relação entre conteúdo (palestra) e visita a estandes, uma evidência de difusão de inovações.

**Cuidados**
- Prêmio por mérito ou por ordem de chegada, sem sorteio, conforme a decisão 3, e regulamento público de cada trilha.
- Brindes da Prefeitura e de outros órgãos públicos seguem as regras de doação do próprio órgão.
- O check-in em palestra só funciona no local e no horário, para os dados de público serem confiáveis.

## 18-C. Avaliação de palestras e serviços; mecanismos do Instagram

Detalhado na seção 16 do plano de implantação (documento "Plano de implantação ITex / ShowPulse"), para revisão.

- **Avaliação com carinhas e comentários**, como nos estandes, também em:
  - palestras;
  - estacionamento (QR nas saídas e portarias);
  - banheiros (alerta em tempo real para a limpeza);
  - restaurantes e praças de alimentação;
  - portarias e transporte oficial.
- **Análise de sentimento e de temas dos comentários**, visível em detalhe **só para a organização**. Palestrantes e estandes recebem só agregados. A análise usa um modelo de linguagem com vocabulário do agro, conferido por amostra pelo ITA.
- **Mecanismos do Instagram adaptados pelo dado que geram:**
  - seguir o estande, que cria uma audiência própria entre edições;
  - salvar o produto, que mede intenção de compra;
  - perguntas e enquetes ao vivo nas palestras;
  - stories "acontecendo agora";
  - assuntos em alta;
  - marcar o estande na foto;
  - insights;
  - destaques da edição;
  - trilhas em colaboração;
  - recomendações "para você".

  Prioridade: seguir, salvar, perguntas e enquetes nas palestras, e assuntos em alta.

---

## 19. Decisões pendentes (acumuladas)

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

**Da etapa de governança, indicadores, implantação e transporte**
18. Comitê gestor e encarregado de dados: quem compõe o comitê e quem será o encarregado (DPO)?
19. Métrica norte: "interações qualificadas por visitante" serve, ou a organização prefere outra (por exemplo, leads gerados)?
20. Calendário: qual a data da próxima edição? Ela define o cronograma reverso e o que cabe na 1ª fase.
21. Equipe: quantos mestrandos e bolsistas podem atuar como agentes de campo e embaixadores?
22. Transporte: começar com transporte oficial e caravanas, e deixar a carona em grupos verificados para depois? Há interesse de prefeituras vizinhas em vans?

**Da etapa de identidade**
23. ~~Nome~~ → **decidida** (ver seção 20). Texto original: escolher 2 ou 3 finalistas da seção 15 (ITA-e, iTA, ITAvents, Expolytics, ExpoIQ…) para a busca no INPI, USPTO e domínios. A sigla ITA precisa estar na marca ou basta a assinatura "by Observatório ITA"?

**Da etapa de usabilidade**
24. Saída da coleta pela equipe: gesto + código numérico serve? Quem define e guarda o código?

**Da etapa de interação no QR do estande**
25. ~~Visibilidade dos negativos~~ → **decidida** (ver seção 20).
26. Cartão de story: a logo do app já é obrigatória (seção 20). Falta decidir quem desenha a moldura, se cada estande pode ter a sua versão e se há espaço para patrocinador.

**Do benchmark do app oficial**
31. ~~Relação com o app oficial~~ → **decidida** (ver seção 20). Fica em aberto só: há como receber da Comigo, em planilha ou API, o cadastro de expositores, locais e agenda?

**Do mapa da feira (detalhe em `docs/mapa-2026/LEIAME.md`)**
32. Dez dúvidas para a reconstrução do mapa: planta oficial em vetor para 2027, QR por expositor ou por lote, expositores em vários lotes, leituras incertas, categorias, palcos da agenda, georreferência, banheiros e acessibilidade, Portaria I, faixa de test drives.

**Da etapa de administração geral e aparelhos**
27. Administrador geral: quem será (uma pessoa ou mais)? Fica na organização da feira, no ITA, ou um de cada?
28. Papéis: a hierarquia da seção 18.2 atende? Falta ou sobra algum papel?
29. Painel de estande: é uma TV ou tablet físico no estande, a tela do celular do expositor, ou os dois? Quem fornece o aparelho?
30. Treinamento: presencial, pelo módulo no app, ou os dois? Quem dá o selo "treinado"?

---

## 20. Decisões tomadas

| Nº | Decisão | Data | Consequência no desenho |
|---|---|---|---|
| 25 | **Negativos só para a loja e a organização.** Carinha triste, motivos e comentários negativos nunca aparecem em público | 05/11/2026 | Em telas públicas (rankings, telão, perfil da loja) só entram indicadores agregados. O detalhe negativo fica no painel da loja e no da organização. Rankings públicos seguem com número mínimo de avaliações |
| 26 (parcial) | **Toda postagem e toda moldura levam a logo do app** (logo ainda a definir, ver seção 15) | 05/11/2026 | Cartões de story, selfies com moldura, fotos do telão social e qualquer imagem gerada pela plataforma recebem a logo num lugar fixo. Cada compartilhamento divulga a plataforma, além da feira e do estande. A logo entra na lista de entregas da identidade visual |
| 6 | **Dono e controlador dos dados: IF Goiano/Observatório ITA.** A Tecnoshow/Comigo é parceira que usa a plataforma | 06/11/2026 | O ITA é o controlador (LGPD) e nomeia o encarregado. Acordo com a Comigo define o uso dos dados operacionais pela organização. Combina com licenciar a plataforma para outras feiras |
| 5 | **Supabase + site próprio.** O Artifact do claude.ai fica só como demonstração | 06/11/2026 | Toda a plataforma nova é desenhada sobre o Supabase |
| 27 | **Dois administradores gerais:** um da organização da feira e um do ITA | 06/11/2026 | Ninguém depende de uma pessoa só. Ambos com verificação em duas etapas |
| 20 | **Piloto num evento menor no 1º semestre**, depois a plataforma completa na Tecnoshow 2027 (ou 2028, se o prazo apertar) | 06/11/2026 | O cronograma reverso parte da data do piloto |
| 1 | **Pedir à organização a planta oficial** com a numeração dos estandes | 06/11/2026 | O mapa digital da feira é desenhado sobre a planta oficial |
| 2 | **Piloto com 20 a 40 expositores** parceiros, de segmentos variados | 06/11/2026 | Importação por planilha fica pronta, mas a fase 1 atende esse grupo |
| 13 | **Fundação de apoio do IF Goiano agora; spin-off do ITA depois**, quando houver receita recorrente | 06/11/2026 | Projetos e contratos passam pela fundação. A arquitetura já separa o que for comercial |
| 7 | **Painel do expositor freemium:** básico grátis, premium pago (leads, benchmark, relatório, destaque) | 06/11/2026 | O sistema precisa controlar planos por expositor |
| 14 | **Cobrança do premium só a partir da 2ª edição** | 06/11/2026 | Na 1ª edição, todos recebem o premium grátis, e os resultados viram argumento de venda |
| 3 | **Prêmios doados por patrocinadores e estandes, por mérito** (pontuação ou concurso cultural), sem sorteio | 06/11/2026 | Dispensa a autorização de sorteio (Lei 5.768/71). Regulamento público com critérios de pontuação |
| 4 | **Fotos de visitantes no telão, com moderação** (filtro automático + aprovação de moderador) e termo de uso de imagem | 06/11/2026 | O papel "Moderador" e a fila de aprovação entram na fase do telão social |
| 8 | **O app será proposto à Comigo como canal oficial** (agenda, mapa, premiação), estudando a integração com o credenciamento para depois | 06/11/2026 | Proposta formal à organização entra no cronograma |
| 9 | **Dados abertos agregados também ao vivo**, durante a feira (por exemplo, o mapa de origens), além dos relatórios anuais | 06/11/2026 | Painel público ao vivo, só com agregados de grupos de 5 ou mais. O painel completo continua restrito à equipe |
| 10 | **Multifeira desde já:** cada feira com seus dados separados, mesmo usando só a Tecnoshow no começo | 06/11/2026 | Todas as tabelas levam a feira e a edição. Permite licenciar sem refazer o sistema |
| 11 | **Canal do visitante: link web (QR, sem baixar) + assistente oficial no WhatsApp** | 06/11/2026 | Prever custo da API do WhatsApp Business no orçamento |
| 12 | **Simulação de crédito e consórcio na 2ª fase.** Na 1ª, só um link para os estandes dos bancos e da cooperativa | 06/11/2026 | Acordo com bancos e Comigo antes da 2ª fase |
| 15 | **Todos os parceiros da cidade formais desde o início:** Prefeitura (Turismo e Desenvolvimento), ACIRV/CDL, Sebrae e sindicatos de hotéis e de bares | 06/11/2026 | Um acordo multilateral entra no cronograma de 6 meses antes. Mais negociação, e também mais força e cofinanciamento |
| 16 | **Ocupação dos hotéis informada de forma voluntária e sigilosa** por formulário, publicada só em agregados de 3 ou mais hotéis; em troca, o hotel recebe um relatório de demanda | 06/11/2026 | Formulário do parceiro hoteleiro e termo de sigilo entram no módulo da cidade |
| 17 | **Alcance: Rio Verde e as cidades vizinhas que recebem hóspedes** (Jataí, Santa Helena de Goiás, Montividiu…) | 06/11/2026 | Parceiros e QR codes também nessas cidades. Base para medir o transbordamento regional |
| 18 | **Comitê gestor misto** (ITA, organização, um representante dos expositores e um do comércio); **encarregado de dados do IF Goiano** | 06/11/2026 | Regimento do comitê e indicação formal do encarregado entram nos acordos |
| 19 | **Métrica norte: interações qualificadas por visitante** | 06/11/2026 | O painel da organização e o do ITA abrem com esse número |
| 21 | **De 6 a 10 mestrandos**, cada um com um eixo de pesquisa, **mais bolsistas** de extensão (graduação e técnico) | 06/11/2026 | Prever bolsas e certificação de horas. Cada eixo vira capítulo ou dissertação |
| 22 | **Transporte oficial e caravanas institucionais primeiro;** carona só depois, em grupos verificados | 06/11/2026 | O módulo de transporte da fase 1 cadastra rotas oficiais e caravanas, sem carona entre desconhecidos |
| 24 | **Saída da coleta: tocar e segurar o logotipo por 3 segundos + código de 4 a 6 dígitos**, definido pelo administrador e trocado a cada edição | 06/11/2026 | O código fica na Administração, com registro de uso na auditoria |
| 26 | **Moldura oficial da plataforma** (logo do app + marca da feira), **com espaço reservado para a logo de cada estande**; patrocinador só em moldura especial de campanha | 06/11/2026 | Gerador de cartões com camadas fixas (logo do app e da feira) e uma camada do estande |
| 29 | **Painel de estande no celular do expositor e dos atendentes, com exibição opcional numa TV ou tablet** do próprio expositor, habilitada pela equipe treinada | 06/11/2026 | O painel tem uma versão para celular e outra para tela grande, com o QR de interação |
| 30 | **Treinamento pelo app (vídeos, passo a passo, teste) + uma sessão prática presencial;** o selo "treinado" é liberado pelo administrador geral ou pela organização depois das duas etapas | 06/11/2026 | Módulo de treinamento e controle do selo entram na Administração |
| 28 | **Hierarquia com 10 papéis:** os 9 da seção 18.2 **+ Patrocinador** (vê só os resultados das próprias cotas) | 06/11/2026 | Painel do patrocinador entra junto com os relatórios de patrocínio |
| 23 | **Nomes de trabalho: ITex** (marca-mãe: Inteligência Territorial + expo/eventos, ligada ao Observatório ITA) **e ShowPulse** (painel ao vivo). Pendentes de busca no INPI; se houver conflito, usar grafia distintiva (ITexpo, ShowPulso) | 06/11/2026 | Busca web preliminar: "ITEX" é usado por várias empresas no exterior (bolsa de permutas e uma feira de TI nos EUA, têxteis); "ShowPulse" é um software de palco para músicos (show-pulse.com). Nada encontrado no Brasil. A logo e a moldura (decisões 26 e 26-parcial) seguem esses nomes |
| 31 | **A ITex não é um aplicativo da Tecnoshow e não compete com o app oficial.** É uma camada de dados e inteligência que agrega valor ao app e à feira, para ser comercializada no futuro. O visitante só a encontra em pontos de contato abertos por QR ou link, sem instalação | 06/11/2026 | Agenda, locais e navegação ficam no app oficial. Do app, a ITex aproveita o mapa, a agenda, as categorias e os cadastros. O plano de implantação precisa ser ajustado nas seções 1, 3, 6.1 e 9 |

---

## Histórico

- 04/11/2026: módulos A a F, cuidados, faseamento, mecanismos de dependência, viés do Observatório ITA, decisões 1 a 10.
- 05/11/2026: valor para o visitante, sustentabilidade financeira, Tecnoshow na Cidade (comércio, hospedagem, interações urbanas), decisões 11 a 17.
- 05/11/2026: governança dos dados, indicadores-chave, implantação no território, carona e transporte, decisões 18 a 22.
- 05/11/2026: identidade e nome (ITA-e e alternativas), decisão 23.
- 05/11/2026: variação iTA e nomes com "eventos" em inglês; decisão 23 revista.
- 05/11/2026: requisito de navegação (seta de voltar em todas as telas), decisão 24.
- 05/11/2026: interação instantânea no QR do estande (reações, carinhas, comentários, story), decisões 25 e 26.
- 05/11/2026: decisão 25 tomada (negativos só para loja e organização); decisão 26 em parte (logo do app em toda postagem e moldura).
- 06/11/2026: administração geral, hierarquia de papéis, habilitação de aparelhos pela equipe treinada, decisões 27 a 30.
- 06/11/2026: decisões 1 a 14, 20 e 27 tomadas.
- 06/11/2026: decisões 15 a 19, 21, 22 e 24 tomadas.
- 06/11/2026: decisões 26, 29 e 30 tomadas; decisão 23 adiada para o final, com mais opções de nomes.
- 06/11/2026: decisão 28 tomada (papel Patrocinador incluído).
- 06/11/2026: decisão 23 tomada (ITex + ShowPulse, pendentes de INPI). Todas as 30 decisões tomadas; ideação encerrada.
- 06/11/2026: benchmark do app oficial da Tecnoshow 2026 (seção 18-A), decisão 31.
- 06/11/2026: mosaico do mapa 2026 guardado e transcrito (113 lotes em `docs/mapa-2026/`); decisão 32 com as dúvidas do mapa.
- 06/11/2026: decisão 31 tomada (ITex é camada de dados, sem app próprio nem competição); agenda como mecanismo de gamificação (seção 18-B).
- 06/11/2026: avaliação de palestras e serviços com análise de sentimento só para a organização; mecanismos do Instagram (seção 18-C e seção 16 do plano).
