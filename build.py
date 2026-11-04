#!/usr/bin/env python3
"""Gera as versões publicáveis do Tecnoshow Avalia a partir de src/template.html.

    python3 build.py            -> dist/  (site próprio com Supabase: index.html, sw.js, vendor/)
    python3 build.py --artifact -> dist/tecnoshow_avalia_claude.html (versão para o claude.ai, sem Supabase)

A configuração do Supabase vem, nesta ordem, das variáveis de ambiente SUPABASE_URL e
SUPABASE_ANON_KEY ou do arquivo config.json ({"supabaseUrl": "...", "supabaseAnonKey": "..."}).
A chave "anon" é pública por definição (vai para o navegador); a proteção dos dados está nas
regras do banco (supabase/schema.sql). Nunca coloque aqui a chave "service_role".
"""
import base64, hashlib, json, os, re, shutil, sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
SRC, DIST = RAIZ / 'src', RAIZ / 'dist'


def config():
    url, chave = os.environ.get('SUPABASE_URL', '').strip(), os.environ.get('SUPABASE_ANON_KEY', '').strip()
    arq = RAIZ / 'config.json'
    if (not url or not chave) and arq.exists():
        c = json.loads(arq.read_text(encoding='utf-8'))
        url, chave = url or c.get('supabaseUrl', ''), chave or c.get('supabaseAnonKey', '')
    if not url or not chave:
        sys.exit('Faltam SUPABASE_URL e SUPABASE_ANON_KEY (variáveis de ambiente ou config.json).')
    if not re.fullmatch(r'https://[a-z0-9-]+\.supabase\.co', url.rstrip('/')):
        sys.exit('SUPABASE_URL deve ter a forma https://<projeto>.supabase.co')
    partes = chave.split('.')
    if len(partes) == 3:  # chave JWT antiga: confere que não é a service_role
        try:
            corpo = json.loads(base64.urlsafe_b64decode(partes[1] + '=' * (-len(partes[1]) % 4)))
            if corpo.get('role') != 'anon':
                sys.exit('A chave informada não é a "anon". Nunca publique a chave service_role.')
        except ValueError:
            pass
    elif chave.startswith('sb_secret_'):
        sys.exit('Esta é uma chave secreta. Use a chave publicável (sb_publishable_...) ou a "anon".')
    return {'supabaseUrl': url.rstrip('/'), 'supabaseAnonKey': chave}


def sri(dados: bytes) -> str:
    return 'sha384-' + base64.b64encode(hashlib.sha384(dados).digest()).decode()


def main():
    artifact = '--artifact' in sys.argv
    tpl = (SRC / 'template.html').read_text(encoding='utf-8')
    geo = (RAIZ / 'data' / 'geo.json').read_text(encoding='utf-8').strip()
    DIST.mkdir(exist_ok=True)

    if artifact:
        libs = '<script src="https://cdnjs.cloudflare.com/ajax/libs/d3/7.8.5/d3.min.js"></script>'
        html = tpl.replace('__LIBS__', libs).replace('__CONFIG__', 'null').replace('__GEO__', geo)
        saida = DIST / 'tecnoshow_avalia_claude.html'
        saida.write_text(html, encoding='utf-8')
        print('gerado', saida.relative_to(RAIZ), f'{len(html)/1e6:.2f} MB')
        return

    cfg = config()
    (DIST / 'vendor').mkdir(exist_ok=True)
    libs = []
    for nome in ('d3.min.js', 'supabase.js'):
        b = (RAIZ / 'vendor' / nome).read_bytes()
        shutil.copyfile(RAIZ / 'vendor' / nome, DIST / 'vendor' / nome)
        libs.append(f'<script src="vendor/{nome}" integrity="{sri(b)}"></script>')
    corpo = (tpl.replace('__LIBS__', '\n'.join(libs))
                .replace('__CONFIG__', json.dumps(cfg))
                .replace('__GEO__', geo))
    # CSP: só scripts deste site e os blocos embutidos exatos (pelo hash); conexões só com o projeto Supabase
    hashes = ' '.join("'sha256-" + base64.b64encode(hashlib.sha256(m.encode()).digest()).decode() + "'"
                      for m in re.findall(r'<script>(.*?)</script>', corpo, flags=re.S))
    csp = ("default-src 'self'; "
           f"script-src 'self' {hashes}; "
           "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
           "font-src https://fonts.gstatic.com; img-src 'self' data: blob:; "
           f"connect-src 'self' {cfg['supabaseUrl']} https://fonts.googleapis.com https://fonts.gstatic.com; "
           "worker-src 'self'; object-src 'none'; base-uri 'none'; form-action 'none'")
    html = ('<!doctype html>\n<html lang="pt-BR">\n<head>\n<meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n'
            f'<meta http-equiv="Content-Security-Policy" content="{csp}">\n'
            '<meta name="referrer" content="no-referrer">\n</head>\n<body>\n' + corpo + '</body>\n</html>\n')
    (DIST / 'index.html').write_text(html, encoding='utf-8')
    versao = hashlib.sha256(html.encode()).hexdigest()[:12]
    sw = (SRC / 'sw.js').read_text(encoding='utf-8').replace('__VERSAO__', versao)
    (DIST / 'sw.js').write_text(sw, encoding='utf-8')
    (DIST / '.nojekyll').write_text('')
    print('gerado dist/index.html', f'{len(html)/1e6:.2f} MB', 'versão', versao)


if __name__ == '__main__':
    main()
