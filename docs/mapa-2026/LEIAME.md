# Mapa da Tecnoshow 2026: base para a reconstrução

Fonte: 4 capturas de tela do mapa do app oficial da Tecnoshow 2026, enviadas pelo coordenador em 06/11/2026. Serve de referência provisória até chegar a planta oficial da Comigo (decisão 1).

| Arquivo | Trecho |
|---|---|
| `1-leste.jpg` | Lado leste: lotes 1 a 98, Estacionamento 1, Portaria principal e Portaria II, bosque, ambulatório, GO-174 |
| `2-centro.jpg` | Centro: lotes 9 a 106, Loja Comigo, auditórios 2 e 3 |
| `3-oeste.jpg` | Oeste: lotes 23 a 113, pavilhões de pecuária, Estacionamento 2, Portarias III e IV |
| `4-estacionamentos-oeste.jpg` | Extremo oeste: Estacionamentos 2 e 3, BR-060 |
| `lotes.csv` | Transcrição dos 113 lotes: tipo, ocupantes, fileira aproximada, observação e confiança da leitura |

## O que o mapa mostra

- **113 lotes numerados**, todos encontrados nas imagens (de 1 a 113, sem lacunas).
- **Malha regular:** 9 fileiras de lotes de leste a oeste, separadas por ruas, com a rodovia passando ao sul (GO-174 a leste, BR-060 a oeste).
- **Faixa norte de demonstração:** helipontos e test drives (Volkswagen, Ford, GWM, GM, Aventura RAM/Dakota) ao norte da fileira 1.
- **Acessos:** Portaria (principal, junto à Administração, lote 06), Portaria II (leste), Portaria III e Portaria IV (oeste).
- **Estacionamentos:** 1 (leste, em duas áreas), 2 e 3 (oeste).
- **Palcos da agenda:**
  - Auditório 1 (lote 1), Auditório 2 (lote 21) e Auditório 3 (lote 18, Embrapa);
  - Dinâmica de Pecuária (lote 78);
  - Espaço Sementinhas do Agro, o teatro infantil (lote 35);
  - Curral de Bovinos (lote 36).
- **Alimentação:**
  - restaurantes: Restaurante 1 Douradão (65), Restaurante 2 Le Petit (23) e Restaurante 3 Casarão (37);
  - praças e áreas: Pamonha Boa (21), Point do Pastel (13), RM Pastéis (75) e as do Bosque (14).
- **Serviços:** ambulatório e ambulância (junto ao lote 06), Imprensa e Rádio Tecnoshow (48), Torre TI (22). Há ícones de banheiro perto dos lotes 06, 35, 57, 67, 89 e da Portaria IV.
- **Áreas verdes e de convivência:** Bosque (14, 3.596 m²), Praça das Flores (7), Praça das Bandeiras (2) e áreas de descanso (22, 75).
- **Lotes compartilhados:** 49 lotes reúnem mais de um expositor (por exemplo, o 72 e o 55, com 7 cada).
- **Expositores em mais de um lote:**
  - Jacto (99, 100), John Deere (97, 98), Stara (103, 104), Vence Tudo (106, 107);
  - Case IH (81, 96), Comigo (33, 47, 60), Corteva (39, 40).

## Como reconstruir (quando formos implementar)

1. Pedir a planta oficial em arquivo vetorial (PDF, AI ou DWG) e com as medidas; as capturas servem só de rascunho.
2. Redesenhar a planta em SVG: lotes como polígonos com o número, ruas, portarias, estacionamentos, palcos e serviços como camadas.
3. Ligar cada lote ao cadastro: `mapa_areas` e `estandes`, um estande por expositor com referência ao lote (ver dúvidas 2 e 3).
4. Georreferenciar a planta com 4 pontos de controle (cantos do parque), para o GPS do celular cair no lugar certo dentro da feira.
5. Usar as cores dos segmentos sobre os lotes (22 categorias do app oficial como ponto de partida).
6. Validar a transcrição de `lotes.csv` com a organização, a começar pelas linhas de confiança "média".

## Dúvidas para resolver depois

1. **Planta 2027:** a Comigo tem a planta oficial em vetor, com medidas? A numeração e a distribuição dos lotes de 2026 se repetem em 2027?
2. **Lote ou expositor:** o QR e a página ficam por expositor (recomendado, porque 49 lotes têm mais de um expositor) com o número do lote como endereço?
3. **Expositor em vários lotes:** Jacto, John Deere, Stara, Comigo e outros ocupam mais de um lote. São estandes diferentes (com painéis separados) ou um estande só?
4. **Leituras incertas:** confirmar os nomes de confiança "média" em `lotes.csv`. Destaques: o "Casa do…" cortado no lote 48, o texto miúdo dos lotes 61, 62, 77 e 78 e as lanchonetes do Bosque.
5. **Categorias:** a categoria de cada expositor no app oficial está correta? Por exemplo, a Adama aparece em "Sementes" e divide o lote 30 com a Limagrain.
6. **Palcos e agenda:** os locais da agenda (Auditórios 1, 2 e 3, Dinâmica de Pecuária, teatro, curral) correspondem a estes lotes? A agenda oficial informa o palco de cada evento?
7. **Georreferência:** quem pode coletar as coordenadas dos 4 cantos do parque, ou a Comigo tem a planta já georreferenciada?
8. **Banheiros, acessibilidade e emergência:** a lista completa de banheiros, rampas e rotas de acessibilidade, pontos de água e rotas de saída de emergência. O mapa só mostra parte deles.
9. **Portaria I:** o mapa mostra "Portaria" (junto à Administração), II, III e IV. A principal é a Portaria I?
10. **Faixa norte:** os test drives e helipontos mudam de lugar a cada edição? Eles entram no mapa como áreas de demonstração com horário?
