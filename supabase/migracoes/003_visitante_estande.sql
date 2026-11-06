-- =====================================================================
-- Migração 003: visitante (porta de entrada) e página do estande
-- Rode depois da 002. Pode ser rodada de novo sem perder dados.
--
-- Modelo de segurança do visitante
--   * O visitante não tem login. Ao completar o perfil, recebe uma credencial
--     aleatória guardada no próprio celular; o banco guarda só o hash dela.
--   * Toda ação do visitante passa por funções (RPC) que conferem essa credencial.
--     A chave pública (anon) não lê nem grava nenhuma tabela diretamente.
--   * O WhatsApp é guardado de duas formas: um HMAC (para achar o mesmo número
--     sem guardá-lo em claro) e uma cópia cifrada, que só é usada quando o
--     visitante pede contato a um estande. A equipe nunca lê essas colunas.
--   * A confirmação do número por código depende de um provedor da API do
--     WhatsApp Business; até lá, whatsapp_confirmado fica false.
-- =====================================================================

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- ---------- segredos do servidor (nunca expostos pela API) ----------
create table if not exists public._segredos (
  nome  text primary key,
  valor text not null
);
alter table public._segredos enable row level security;
revoke all on table public._segredos from anon, authenticated, public;
insert into public._segredos (nome, valor) values
  ('pimenta_whatsapp', encode(extensions.gen_random_bytes(32), 'hex')),
  ('chave_whatsapp',   encode(extensions.gen_random_bytes(32), 'hex'))
on conflict (nome) do nothing;

create or replace function public._segredo(p_nome text)
returns text language sql stable security definer set search_path = '' as $$
  select valor from public._segredos where nome = p_nome
$$;
revoke all on function public._segredo(text) from public, anon, authenticated;

-- ---------- produtos (vitrine do expositor) ----------
create table if not exists public.produtos (
  id           uuid primary key default gen_random_uuid(),
  expositor_id uuid not null references public.expositores(id) on delete cascade,
  nome         text not null check (char_length(nome) between 1 and 120),
  descricao    text check (char_length(descricao) <= 1000),
  foto_url     text check (foto_url ~ '^https://'),
  preco_texto  text check (char_length(preco_texto) <= 120),
  condicoes    text check (char_length(condicoes) <= 1000),
  validade     date,
  ordem        int not null default 0,
  status       text not null default 'a_confirmar' check (status in ('a_confirmar','confirmado')),
  excluido_em  timestamptz,
  criado_em    timestamptz not null default now()
);

-- ---------- visitante e interações ----------
create table if not exists public.visitantes (
  id                  uuid primary key default gen_random_uuid(),
  ed                  text not null references public.edicoes(slug) on delete cascade,
  token_hash          text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  whatsapp_hash       text not null check (whatsapp_hash ~ '^[0-9a-f]{64}$'),
  whatsapp_cifrado    bytea not null,
  whatsapp_confirmado boolean not null default false,
  perfil              jsonb not null,
  lang                text not null default 'pt' check (lang in ('pt','en','es')),
  canal               text not null default 'celular' check (canal in ('celular','tablet','conversa')),
  menor               boolean not null default false,
  criado_em           timestamptz not null default now()
);
create index if not exists visitantes_whatsapp on public.visitantes (whatsapp_hash);

create table if not exists public.checkins (
  id          bigint generated always as identity primary key,
  visitante   uuid not null references public.visitantes(id) on delete cascade,
  estande_id  uuid references public.estandes(id) on delete cascade,
  local_id    uuid references public.locais(id) on delete cascade,
  quando      timestamptz not null default now()
);
create index if not exists checkins_estande on public.checkins (estande_id, quando);

create table if not exists public.reacoes (
  id          bigint generated always as identity primary key,
  visitante   uuid not null references public.visitantes(id) on delete cascade,
  estande_id  uuid not null references public.estandes(id) on delete cascade,
  produto_id  uuid references public.produtos(id) on delete cascade,
  tipo        text not null check (tipo in ('curti','amei')),
  quando      timestamptz not null default now()
);
create unique index if not exists reacoes_un on public.reacoes
  (visitante, estande_id, coalesce(produto_id, '00000000-0000-0000-0000-000000000000'::uuid), tipo);

create table if not exists public.salvos (
  visitante  uuid not null references public.visitantes(id) on delete cascade,
  produto_id uuid not null references public.produtos(id) on delete cascade,
  quando     timestamptz not null default now(),
  primary key (visitante, produto_id)
);
create table if not exists public.seguidores (
  visitante  uuid not null references public.visitantes(id) on delete cascade,
  estande_id uuid not null references public.estandes(id) on delete cascade,
  desde      timestamptz not null default now(),
  primary key (visitante, estande_id)
);
create table if not exists public.avaliacoes (
  id         bigint generated always as identity primary key,
  visitante  uuid not null references public.visitantes(id) on delete cascade,
  alvo_tipo  text not null check (alvo_tipo in ('estande','palestra','local')),
  alvo_id    uuid not null,
  carinha    text not null check (carinha in ('bom','neutro','ruim')),
  motivo     text check (motivo in ('fila','demora','preco','falta_produto','atendimento','outro')),
  quando     timestamptz not null default now(),
  unique (visitante, alvo_tipo, alvo_id)
);
create table if not exists public.comentarios (
  id         bigint generated always as identity primary key,
  visitante  uuid not null references public.visitantes(id) on delete cascade,
  alvo_tipo  text not null check (alvo_tipo in ('estande','produto','palestra','local')),
  alvo_id    uuid not null,
  texto      text not null check (char_length(texto) between 1 and 400),
  publico    boolean not null default false,
  status     text not null default 'privado' check (status in ('privado','pendente','aprovado','recusado')),
  quando     timestamptz not null default now()
);
create table if not exists public.contatos (
  visitante  uuid not null references public.visitantes(id) on delete cascade,
  estande_id uuid not null references public.estandes(id) on delete cascade,
  quando     timestamptz not null default now(),
  primary key (visitante, estande_id)
);

-- ---------- RLS e permissões ----------
do $$
declare t text;
begin
  foreach t in array array['produtos','visitantes','checkins','reacoes','salvos','seguidores','avaliacoes','comentarios','contatos'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from anon, authenticated, public', t);
    execute format('drop policy if exists le on public.%I', t);
    execute format('create policy le on public.%I for select to authenticated using ((select public.sou_equipe()))', t);
  end loop;
  foreach t in array array['checkins','reacoes','salvos','seguidores','avaliacoes','comentarios','contatos'] loop
    execute format('grant select on table public.%I to authenticated', t);
  end loop;
end $$;
-- visitantes: a equipe lê o perfil, nunca a credencial nem o WhatsApp
grant select (id, ed, whatsapp_confirmado, perfil, lang, canal, menor, criado_em) on table public.visitantes to authenticated;
-- produtos: cadastro editável como os demais
grant select, insert, update, delete on table public.produtos to authenticated;
drop policy if exists insere on public.produtos;
drop policy if exists altera on public.produtos;
drop policy if exists apaga on public.produtos;
create policy insere on public.produtos for insert to authenticated with check ((select public.pode_editar_cadastros()));
create policy altera on public.produtos for update to authenticated using ((select public.pode_editar_cadastros())) with check ((select public.pode_editar_cadastros()));
create policy apaga on public.produtos for delete to authenticated using ((select public.sou_admin_geral()));
drop trigger if exists auditar on public.produtos;
create trigger auditar after insert or update or delete on public.produtos for each row execute function public._auditar();

-- ---------- validação do perfil curto ----------
create or replace function public._perfil_valido(p jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare k text; v jsonb;
begin
  if coalesce(jsonb_typeof(p), '') <> 'object' or octet_length(p::text) > 2000 then return false; end if;
  for k in select jsonb_object_keys(p) loop
    if k <> all (array['br','mun','pais','perfil','idade','culturas','prim','dias','pern']) then return false; end if;
  end loop;
  if coalesce(p->>'br', '') not in ('0','1') then return false; end if;
  if (p->>'br') = '1' and coalesce(p->>'mun', '') !~ '^[0-9]{7}$' then return false; end if;
  if (p->>'br') = '0' and coalesce(p->>'pais', '') !~ '^[A-Z]{2}$' then return false; end if;
  if coalesce(p->>'perfil', '') not in ('pp','pm','pg','tec','exp','est','inv','vis') then return false; end if;
  if coalesce(p->>'idade', '') not in ('a1','a2','a3','a4','a5','a6') then return false; end if;
  if coalesce(p->>'prim', 's') not in ('s','nn') then return false; end if;
  if coalesce(p->>'dias', 'd1') not in ('d1','d2','d3','d4','d5') then return false; end if;
  if coalesce(p->>'pern', 'pnao') not in ('pnao','prv','pout') then return false; end if;
  if coalesce(jsonb_typeof(p->'culturas'), 'array') <> 'array' or jsonb_array_length(coalesce(p->'culturas', '[]')) > 12 then return false; end if;
  for v in select jsonb_array_elements(coalesce(p->'culturas', '[]')) loop
    if coalesce(v #>> '{}', '') !~ '^[a-z_]{2,24}$' then return false; end if;
  end loop;
  return true;
end $$;

create or replace function public._visitante(p_token text)
returns public.visitantes language plpgsql stable security definer set search_path = '' as $$
declare v public.visitantes%rowtype;
begin
  select * into v from public.visitantes
   where token_hash = encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex');
  if not found then raise exception 'visitante_invalido' using errcode = 'P0001'; end if;
  return v;
end $$;

-- ---------- porta de entrada ----------
create or replace function public.criar_visitante(p_ed text, p_perfil jsonb, p_whatsapp text, p_lang text default 'pt')
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_num text := regexp_replace(coalesce(p_whatsapp, ''), '[^0-9]', '', 'g');
        v_hash text; v_tok text := encode(extensions.gen_random_bytes(24), 'hex'); v_id uuid; v_menor boolean;
begin
  if not exists (select 1 from public.edicoes where slug = p_ed and aberta) then
    raise exception 'edicao_fechada' using errcode = 'P0001'; end if;
  if not public._perfil_valido(p_perfil) then raise exception 'perfil_invalido' using errcode = 'P0001'; end if;
  if v_num !~ '^[0-9]{10,15}$' then raise exception 'whatsapp_invalido' using errcode = 'P0001'; end if;
  v_hash := encode(extensions.hmac(v_num, public._segredo('pimenta_whatsapp'), 'sha256'), 'hex');
  -- limite contra abuso: no máximo 5 perfis por número por hora
  if (select count(*) from public.visitantes where whatsapp_hash = v_hash and criado_em > now() - interval '1 hour') >= 5 then
    raise exception 'muitas_tentativas' using errcode = 'P0001'; end if;
  v_menor := (p_perfil->>'idade') = 'a1';
  insert into public.visitantes (ed, token_hash, whatsapp_hash, whatsapp_cifrado, perfil, lang, menor)
  values (p_ed, encode(extensions.digest(v_tok, 'sha256'), 'hex'), v_hash,
          extensions.pgp_sym_encrypt(v_num, public._segredo('chave_whatsapp')),
          p_perfil, case when p_lang in ('pt','en','es') then p_lang else 'pt' end, v_menor)
  returning id into v_id;
  return jsonb_build_object('token', v_tok, 'menor', v_menor);
end $$;

-- ---------- página pública do estande ----------
create or replace function public.estande_publico(p_estande uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', s.id, 'ed', s.ed, 'expositor', x.nome, 'site', x.site,
    'categoria', c.nome, 'cor', c.cor,
    'lotes', coalesce((select jsonb_agg(l.numero order by length(l.numero), l.numero) from public.estande_lotes el
                        join public.lotes l on l.id = el.lote_id and l.excluido_em is null where el.estande_id = s.id), '[]'),
    'produtos', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'nome', p.nome, 'descricao', p.descricao,
                            'foto_url', p.foto_url, 'preco_texto', p.preco_texto, 'condicoes', p.condicoes, 'validade', p.validade)
                            order by p.ordem, p.nome)
                          from public.produtos p where p.expositor_id = x.id and p.excluido_em is null), '[]'))
  from public.estandes s join public.expositores x on x.id = s.expositor_id and x.excluido_em is null
  left join public.categorias c on c.id = x.categoria_id and c.excluido_em is null
  where s.id = p_estande and s.excluido_em is null
$$;

create or replace function public.estado_visitante(p_token text, p_estande uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante(p_token);
begin
  return jsonb_build_object(
    'menor', v.menor,
    'curti', exists (select 1 from public.reacoes where visitante = v.id and estande_id = p_estande and produto_id is null and tipo = 'curti'),
    'amei',  exists (select 1 from public.reacoes where visitante = v.id and estande_id = p_estande and produto_id is null and tipo = 'amei'),
    'seguindo', exists (select 1 from public.seguidores where visitante = v.id and estande_id = p_estande),
    'contato',  exists (select 1 from public.contatos where visitante = v.id and estande_id = p_estande),
    'carinha', (select jsonb_build_object('carinha', carinha, 'motivo', motivo) from public.avaliacoes
                 where visitante = v.id and alvo_tipo = 'estande' and alvo_id = p_estande),
    'produtos', coalesce((select jsonb_object_agg(p.id, jsonb_build_object(
                    'curti', exists (select 1 from public.reacoes r where r.visitante = v.id and r.produto_id = p.id and r.tipo = 'curti'),
                    'amei',  exists (select 1 from public.reacoes r where r.visitante = v.id and r.produto_id = p.id and r.tipo = 'amei'),
                    'salvo', exists (select 1 from public.salvos sv where sv.visitante = v.id and sv.produto_id = p.id)))
                  from public.produtos p join public.estandes s on s.expositor_id = p.expositor_id
                 where s.id = p_estande and p.excluido_em is null), '{}'::jsonb));
end $$;

-- ---------- interações do visitante ----------
create or replace function public.interagir(p_token text, p_estande uuid, p_acao text, p_produto uuid default null,
                                            p_valor text default null, p_texto text default null, p_publico boolean default false)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante(p_token); s public.estandes%rowtype;
begin
  select * into s from public.estandes where id = p_estande and excluido_em is null;
  if not found or s.ed <> v.ed then raise exception 'estande_invalido' using errcode = 'P0001'; end if;
  if p_produto is not null and not exists (select 1 from public.produtos p where p.id = p_produto
          and p.expositor_id = s.expositor_id and p.excluido_em is null) then
    raise exception 'produto_invalido' using errcode = 'P0001'; end if;
  -- limite contra abuso: 300 ações por visitante por hora
  if (select count(*) from public.checkins where visitante = v.id and quando > now() - interval '1 hour') > 300 then
    raise exception 'muitas_tentativas' using errcode = 'P0001'; end if;
  -- check-in: um por estande a cada 30 minutos (é ele que libera as demais ações)
  if not exists (select 1 from public.checkins where visitante = v.id and estande_id = p_estande and quando > now() - interval '30 minutes') then
    insert into public.checkins (visitante, estande_id) values (v.id, p_estande);
  end if;
  case p_acao
    when 'checkin' then null;
    when 'curti', 'amei' then
      if exists (select 1 from public.reacoes where visitante = v.id and estande_id = p_estande
                  and produto_id is not distinct from p_produto and tipo = p_acao) then
        delete from public.reacoes where visitante = v.id and estande_id = p_estande and produto_id is not distinct from p_produto and tipo = p_acao;
      else
        insert into public.reacoes (visitante, estande_id, produto_id, tipo) values (v.id, p_estande, p_produto, p_acao);
      end if;
    when 'salvar' then
      if p_produto is null then raise exception 'produto_invalido' using errcode = 'P0001'; end if;
      if exists (select 1 from public.salvos where visitante = v.id and produto_id = p_produto) then
        delete from public.salvos where visitante = v.id and produto_id = p_produto;
      else insert into public.salvos (visitante, produto_id) values (v.id, p_produto); end if;
    when 'seguir' then
      if exists (select 1 from public.seguidores where visitante = v.id and estande_id = p_estande) then
        delete from public.seguidores where visitante = v.id and estande_id = p_estande;
      else insert into public.seguidores (visitante, estande_id) values (v.id, p_estande); end if;
    when 'carinha' then
      if coalesce(p_valor, '') not in ('bom','neutro','ruim') then raise exception 'valor_invalido' using errcode = 'P0001'; end if;
      insert into public.avaliacoes (visitante, alvo_tipo, alvo_id, carinha, motivo)
      values (v.id, 'estande', p_estande, p_valor, case when p_valor = 'ruim' then nullif(p_texto, '') end)
      on conflict (visitante, alvo_tipo, alvo_id) do update
        set carinha = excluded.carinha, motivo = excluded.motivo, quando = now();
    when 'comentario' then
      if char_length(coalesce(trim(p_texto), '')) not between 1 and 400 then raise exception 'texto_invalido' using errcode = 'P0001'; end if;
      if (select count(*) from public.comentarios where visitante = v.id and quando > now() - interval '1 hour') >= 20 then
        raise exception 'muitas_tentativas' using errcode = 'P0001'; end if;
      insert into public.comentarios (visitante, alvo_tipo, alvo_id, texto, publico, status)
      values (v.id, case when p_produto is null then 'estande' else 'produto' end, coalesce(p_produto, p_estande),
              trim(p_texto), coalesce(p_publico, false) and not v.menor,
              case when coalesce(p_publico, false) and not v.menor then 'pendente' else 'privado' end);
    when 'contato' then
      if v.menor then raise exception 'menor' using errcode = 'P0001'; end if;
      insert into public.contatos (visitante, estande_id) values (v.id, p_estande) on conflict do nothing;
    else raise exception 'acao_invalida' using errcode = 'P0001';
  end case;
  return public.estado_visitante(p_token, p_estande);
end $$;

-- ---------- permissões das funções ----------
revoke all on function public._perfil_valido(jsonb)                                   from public, anon, authenticated;
revoke all on function public._visitante(text)                                         from public, anon, authenticated;
revoke all on function public.criar_visitante(text, jsonb, text, text)                from public, anon, authenticated;
revoke all on function public.estande_publico(uuid)                                    from public, anon, authenticated;
revoke all on function public.estado_visitante(text, uuid)                             from public, anon, authenticated;
revoke all on function public.interagir(text, uuid, text, uuid, text, text, boolean)   from public, anon, authenticated;
grant execute on function public.criar_visitante(text, jsonb, text, text)              to anon, authenticated;
grant execute on function public.estande_publico(uuid)                                  to anon, authenticated;
grant execute on function public.estado_visitante(text, uuid)                           to anon, authenticated;
grant execute on function public.interagir(text, uuid, text, uuid, text, text, boolean) to anon, authenticated;
