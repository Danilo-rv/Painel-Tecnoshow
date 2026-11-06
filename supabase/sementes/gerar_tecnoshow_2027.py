#!/usr/bin/env python3
"""Gera supabase/sementes/tecnoshow-comigo-2027.sql a partir de docs/mapa-2026/lotes.csv.

Tudo entra com status "a_confirmar": é um rascunho feito das capturas do mapa de 2026,
para a organização revisar na Administração (painel de pendências).

    python3 supabase/sementes/gerar_tecnoshow_2027.py
"""
import csv, re
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
ED = 'tecnoshow-comigo-2027'
FEIRA = "(select id from public.feiras where slug = 'tecnoshow-comigo')"

# 22 categorias do app oficial da Tecnoshow 2026 (grafia revisada)
CATEGORIAS = [
    ('Alimentação', 'alimentacao', '#e07b39'), ('Armazenagem', 'armazenagem', '#8d6e63'),
    ('Automóveis e utilitários', 'automoveis', '#546e7a'), ('Comércio', 'comercio', '#ab47bc'),
    ('Cooperativismo', 'cooperativismo', '#2e7d32'), ('Defensivos', 'defensivos', '#c62828'),
    ('Drones', 'drones', '#0288d1'), ('Energia', 'energia', '#f9a825'),
    ('Engenharia e construção', 'engenharia', '#6d4c41'), ('Fertilizantes', 'fertilizantes', '#558b2f'),
    ('Instituições financeiras', 'financeiras', '#1565c0'), ('Insumos', 'insumos', '#7cb342'),
    ('Irrigação', 'irrigacao', '#00838f'), ('Lubrificantes', 'lubrificantes', '#4e342e'),
    ('Máquinas e equipamentos', 'maquinas', '#ef6c00'), ('Outros', 'outros', '#757575'),
    ('Pecuária', 'pecuaria', '#a1887f'), ('Sementes', 'sementes', '#9e9d24'),
    ('Serviço', 'servico', '#5c6bc0'), ('Tecnologia', 'tecnologia', '#00acc1'),
    ('Treinamento e capacitação', 'treinamento', '#8e24aa'), ('Veículos pesados', 'veiculos_pesados', '#37474f'),
]

TIPO_LOTE = {'expositor': 'expositores', 'expositores': 'expositores', 'auditorio': 'auditorio', 'praca': 'praca',
             'administracao': 'administracao', 'alimentacao': 'alimentacao', 'pavilhao': 'pavilhao',
             'pecuaria': 'pecuaria', 'bosque': 'bosque', 'descanso': 'descanso', 'imprensa': 'imprensa'}

# ocupantes que são locais (serviços, palcos, áreas), não expositores
LOCAL = [
    (r'^Auditório', 'palco'), (r'^Espaço Sementinhas', 'palco'), (r'^Dinâmica de Pecuária', 'palco'),
    (r'Curral Bovinos', 'palco'), (r'^Restaurante', 'alimentacao'), (r'^Área de alimentação', 'alimentacao'),
    (r'^RM Pastéis', 'alimentacao'), (r'^Pamonha Boa', 'alimentacao'), (r'^Estefânia Lima', 'alimentacao'),
    (r'^Praça', 'outro'), (r'^Pavilhão', 'outro'), (r'^Pav\.', 'outro'), (r'^Piquete', 'outro'),
    (r'^Área de descanso', 'outro'), (r'Torre TI', 'servico'), (r'^Administração', 'servico'),
    (r'^Imprensa', 'servico'), (r'^Rádio Tecnoshow', 'servico'), (r'^Ambulância', 'ambulatorio'),
    (r"^Caixas d'água", 'servico'), (r'^Loja Primos Agro', None),
]

# locais vistos no mapa que não ocupam um lote numerado
EXTRAS = [
    ('Portaria (principal, junto à Administração)', 'portaria', '06'), ('Portaria II', 'portaria', '50'),
    ('Portaria III', 'portaria', '113'), ('Portaria IV', 'portaria', '95'),
    ('Estacionamento 1', 'estacionamento', None), ('Estacionamento 2', 'estacionamento', None),
    ('Estacionamento 3', 'estacionamento', None), ('Ambulatório', 'ambulatorio', '06'),
    ('Heliponto (próximo aos lotes 99 e 100)', 'heliponto', '100'),
    ('Test drive Volkswagen', 'test_drive', '103'), ('Test drive Ford', 'test_drive', '102'),
    ('Test drive GWM', 'test_drive', '101'), ('Test drive GM', 'test_drive', '97'),
    ('Test drive Aventura RAM/Dakota', 'test_drive', '98'),
    ('Banheiro (Administração)', 'banheiro', '06'), ('Banheiro (lote 35)', 'banheiro', '35'),
    ('Banheiro (lote 57)', 'banheiro', '57'), ('Banheiro (lote 67)', 'banheiro', '67'),
    ('Banheiro (lote 89)', 'banheiro', '89'), ('Banheiro (Portaria IV)', 'banheiro', '95'),
]


def q(s):
    return 'null' if s is None or s == '' else "'" + str(s).replace("'", "''") + "'"


def classifica(nome):
    for padrao, tipo in LOCAL:
        if re.search(padrao, nome):
            return tipo if tipo else 'expositor'
    return 'expositor'


def main():
    linhas = list(csv.DictReader(open(RAIZ / 'docs/mapa-2026/lotes.csv', encoding='utf-8'), delimiter=';'))
    sql = ['-- Gerado por supabase/sementes/gerar_tecnoshow_2027.py a partir de docs/mapa-2026/lotes.csv.',
           '-- Rascunho para revisão: tudo entra "a confirmar". Rodar depois da migração 002. Idempotente.',
           'begin;', '']
    sql.append('insert into public.categorias (feira_id, nome, icone, cor, ordem, status) values')
    sql.append(',\n'.join(f"  ({FEIRA}, {q(n)}, {q(i)}, {q(c)}, {k}, 'a_confirmar')" for k, (n, i, c) in enumerate(CATEGORIAS)))
    sql.append('on conflict (feira_id, lower(nome)) where excluido_em is null do nothing;\n')

    expositores, vinculos, locais = {}, [], []
    for r in linhas:
        n = r['lote'].strip()
        obs = '; '.join(x for x in [r['observacao'].strip(), f"leitura do mapa 2026: confiança {r['confianca']}"] if x)
        sql.append(f"insert into public.lotes (ed, numero, tipo, rotulo, fileira, status, obs) values "
                   f"('{ED}', {q(n)}, {q(TIPO_LOTE.get(r['tipo'], 'outro'))}, {q(r['ocupantes'])}, {q(r['fileira_aprox'])}, 'a_confirmar', {q(obs)}) "
                   f"on conflict (ed, numero) where excluido_em is null do nothing;")
        if n == '14':   # Bosque: área com várias lanchonetes
            locais += [('Bosque', 'outro', n), ('Área de alimentação do Bosque', 'alimentacao', n)]
            continue
        for nome in [x.strip() for x in r['ocupantes'].split('|') if x.strip()]:
            nome = re.sub(r'\s*\(texto cortado\)', '…', nome)
            tipo = classifica(nome)
            if tipo == 'expositor' and r['tipo'] not in ('expositor', 'expositores', 'imprensa', 'pecuaria', 'pavilhao', 'alimentacao'):
                tipo = 'outro'
            if tipo == 'expositor':
                expositores.setdefault(nome.lower(), nome)
                vinculos.append((nome.lower(), n))
            else:
                locais.append((nome, tipo, n))

    sql.append('')
    for chave, nome in sorted(expositores.items()):
        sql.append(f"insert into public.expositores (feira_id, nome, status) values ({FEIRA}, {q(nome)}, 'a_confirmar') "
                   f"on conflict (feira_id, lower(nome)) where excluido_em is null do nothing;")
    sql.append('')
    # um estande por expositor na edição (lotes juntos por padrão; o expositor pode separar depois)
    for chave in sorted(expositores):
        sql.append(f"insert into public.estandes (ed, expositor_id, status) select '{ED}', x.id, 'a_confirmar' "
                   f"from public.expositores x where x.feira_id = {FEIRA} and lower(x.nome) = {q(chave)} and x.excluido_em is null "
                   f"and not exists (select 1 from public.estandes s where s.ed = '{ED}' and s.expositor_id = x.id and s.excluido_em is null);")
    sql.append('')
    for chave, n in vinculos:
        sql.append(f"insert into public.estande_lotes (estande_id, lote_id) select s.id, l.id from public.estandes s "
                   f"join public.expositores x on x.id = s.expositor_id and lower(x.nome) = {q(chave)} and x.feira_id = {FEIRA} "
                   f"join public.lotes l on l.ed = '{ED}' and l.numero = {q(n)} and l.excluido_em is null "
                   f"where s.ed = '{ED}' and s.excluido_em is null on conflict do nothing;")
    sql.append('')
    for nome, tipo, n in locais + EXTRAS:
        lote = f"(select id from public.lotes where ed = '{ED}' and numero = {q(n)} and excluido_em is null)" if n else 'null'
        sql.append(f"insert into public.locais (ed, nome, tipo, lote_id, status) select '{ED}', {q(nome)}, {q(tipo)}, {lote}, 'a_confirmar' "
                   f"where not exists (select 1 from public.locais where ed = '{ED}' and nome = {q(nome)} and excluido_em is null);")
    sql += ['', 'commit;', '']
    saida = RAIZ / 'supabase/sementes/tecnoshow-comigo-2027.sql'
    saida.write_text('\n'.join(sql), encoding='utf-8')
    print(f'{saida.relative_to(RAIZ)}: {len(linhas)} lotes, {len(expositores)} expositores, '
          f'{len(vinculos)} vínculos estande-lote, {len(locais) + len(EXTRAS)} locais, {len(CATEGORIAS)} categorias')


if __name__ == '__main__':
    main()
