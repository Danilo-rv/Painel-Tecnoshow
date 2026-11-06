-- =====================================================================
-- Migração 002: base multifeira com cadastros editáveis
-- Rode DEPOIS de supabase/schema.sql. Pode ser rodada de novo sem perder dados.
--
-- O que muda
--   * Feiras: uma linha por feira licenciada; cada edição pertence a uma feira.
--   * Papéis: administrador geral, coordenação, organização e equipe.
--   * Cadastros editáveis por edição: planta, lotes, locais, categorias, expositores,
--     estandes e agenda. Tudo se liga por identificador (uuid), nunca por nome:
--     renomear ou mover algo atualiza todas as telas que o usam.
--   * Lixeira (excluido_em), status "a confirmar", auditoria de toda alteração
--     e a visão "pendencias", que se recalcula sozinha a cada consulta.
--   * Função para clonar uma edição (a 2028 nasce da 2027, por exemplo).
-- =====================================================================

-- ---------- feiras e edições ----------
create table if not exists public.feiras (
  id            uuid primary key default gen_random_uuid(),
  slug          text not null unique check (slug ~ '^[a-z0-9-]{1,60}$'),
  nome          text not null check (char_length(nome) between 1 and 120),
  cidade        text check (char_length(cidade) <= 120),
  organizadora  text check (char_length(organizadora) <= 120),
  criado_em     timestamptz not null default now()
);

alter table public.edicoes add column if not exists feira_id uuid references public.feiras(id);
alter table public.edicoes add column if not exists ano      int  check (ano between 2000 and 2100);
alter table public.edicoes add column if not exists inicio   date;
alter table public.edicoes add column if not exists fim      date;
alter table public.edicoes add column if not exists dias     int  check (dias between 1 and 30);
alter table public.edicoes add column if not exists status   text not null default 'rascunho';
alter table public.edicoes drop constraint if exists edicoes_status_ok;
alter table public.edicoes add constraint edicoes_status_ok check (status in ('rascunho','aberta','encerrada'));

insert into public.feiras (slug, nome, cidade, organizadora)
values ('tecnoshow-comigo', 'Tecnoshow Comigo', 'Rio Verde (GO)', 'Comigo')
on conflict (slug) do nothing;

update public.edicoes e
   set feira_id = f.id,
       ano = coalesce(e.ano, nullif(substring(e.slug from '([0-9]{4})$'), '')::int)
  from public.feiras f
 where f.slug = 'tecnoshow-comigo' and e.feira_id is null and e.slug like 'tecnoshow-comigo%';

-- ---------- papéis ----------
alter table public.equipe drop constraint if exists equipe_papel_ok;
alter table public.equipe add constraint equipe_papel_ok
  check (papel in ('admin_geral','coordenador','organizacao','equipe'));

create or replace function public.meu_papel()
returns text language sql stable security definer set search_path = '' as $$
  select papel from public.equipe where user_id = auth.uid()
$$;
create or replace function public.sou_coordenador()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.equipe where user_id = auth.uid() and papel in ('admin_geral','coordenador'))
$$;
create or replace function public.pode_editar_cadastros()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.equipe where user_id = auth.uid() and papel in ('admin_geral','coordenador','organizacao'))
$$;
create or replace function public.sou_admin_geral()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.equipe where user_id = auth.uid() and papel = 'admin_geral')
$$;

-- remover membro: administradores e coordenadores não podem ser removidos por esta função
create or replace function public.remover_membro(p_user uuid)
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  if not public.sou_coordenador() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  if p_user = auth.uid() then raise exception 'nao_pode_remover_a_si' using errcode = 'P0001'; end if;
  delete from public.equipe where user_id = p_user and papel not in ('coordenador','admin_geral');
end $$;

-- ---------- validação de geometria (coordenadas relativas à planta, de 0 a 1) ----------
create or replace function public._ponto_valido(p jsonb)
returns boolean language sql immutable set search_path = '' as $$
  select p is null or (
    jsonb_typeof(p) = 'object'
    and jsonb_typeof(p->'x') = 'number' and jsonb_typeof(p->'y') = 'number'
    and (p->>'x')::numeric between 0 and 1 and (p->>'y')::numeric between 0 and 1)
$$;
create or replace function public._poligono_valido(p jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare v jsonb;
begin
  if p is null then return true; end if;
  if jsonb_typeof(p) <> 'array' or jsonb_array_length(p) not between 3 and 64 then return false; end if;
  for v in select jsonb_array_elements(p) loop
    if jsonb_typeof(v) <> 'array' or jsonb_array_length(v) <> 2
       or jsonb_typeof(v->0) <> 'number' or jsonb_typeof(v->1) <> 'number'
       or (v->>0)::numeric not between 0 and 1 or (v->>1)::numeric not between 0 and 1 then return false; end if;
  end loop;
  return true;
end $$;
create or replace function public._georef_valida(p jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare v jsonb;
begin
  if p is null then return true; end if;
  if jsonb_typeof(p) <> 'array' or jsonb_array_length(p) not between 3 and 8 then return false; end if;
  for v in select jsonb_array_elements(p) loop
    if jsonb_typeof(v) <> 'object' or not (v ? 'x') or not public._ponto_valido(v - 'lat' - 'lon')
       or jsonb_typeof(v->'lat') <> 'number' or jsonb_typeof(v->'lon') <> 'number'
       or (v->>'lat')::numeric not between -90 and 90 or (v->>'lon')::numeric not between -180 and 180 then return false; end if;
  end loop;
  return true;
end $$;

-- ---------- cadastros ----------
create table if not exists public.categorias (
  id          uuid primary key default gen_random_uuid(),
  feira_id    uuid not null references public.feiras(id) on delete cascade,
  nome        text not null check (char_length(nome) between 1 and 80),
  icone       text check (char_length(icone) <= 40),
  cor         text check (cor ~ '^#[0-9a-fA-F]{6}$'),
  ordem       int not null default 0,
  status      text not null default 'a_confirmar' check (status in ('a_confirmar','confirmado')),
  excluido_em timestamptz,
  criado_em   timestamptz not null default now()
);
create unique index if not exists categorias_nome_un on public.categorias (feira_id, lower(nome)) where excluido_em is null;

create table if not exists public.expositores (
  id           uuid primary key default gen_random_uuid(),
  feira_id     uuid not null references public.feiras(id) on delete cascade,
  nome         text not null check (char_length(nome) between 1 and 120),
  categoria_id uuid references public.categorias(id) on delete set null,
  cnpj         text check (cnpj ~ '^[0-9]{14}$'),
  site         text check (char_length(site) <= 200),
  status       text not null default 'a_confirmar' check (status in ('a_confirmar','confirmado')),
  obs          text check (char_length(obs) <= 500),
  excluido_em  timestamptz,
  criado_em    timestamptz not null default now()
);
create unique index if not exists expositores_nome_un on public.expositores (feira_id, lower(nome)) where excluido_em is null;

create table if not exists public.plantas (
  id          uuid primary key default gen_random_uuid(),
  ed          text not null references public.edicoes(slug) on delete cascade,
  imagem_url  text not null check (imagem_url ~ '^https://'),
  largura     int check (largura > 0),
  altura      int check (altura > 0),
  georef      jsonb check (public._georef_valida(georef)),
  ativa       boolean not null default true,
  excluido_em timestamptz,
  criado_em   timestamptz not null default now()
);

create table if not exists public.lotes (
  id          uuid primary key default gen_random_uuid(),
  ed          text not null references public.edicoes(slug) on delete cascade,
  numero      text not null check (numero ~ '^[0-9A-Za-z-]{1,10}$'),
  tipo        text not null default 'expositores' check (tipo in ('expositores','auditorio','pavilhao','pecuaria','alimentacao','praca','descanso','bosque','administracao','imprensa','servico','outro')),
  rotulo      text check (char_length(rotulo) <= 400),
  fileira     text check (char_length(fileira) <= 40),
  poligono    jsonb check (public._poligono_valido(poligono)),
  status      text not null default 'a_confirmar' check (status in ('a_confirmar','confirmado')),
  obs         text check (char_length(obs) <= 500),
  excluido_em timestamptz,
  criado_em   timestamptz not null default now()
);
create unique index if not exists lotes_numero_un on public.lotes (ed, numero) where excluido_em is null;

create table if not exists public.locais (
  id          uuid primary key default gen_random_uuid(),
  ed          text not null references public.edicoes(slug) on delete cascade,
  nome        text not null check (char_length(nome) between 1 and 120),
  tipo        text not null check (tipo in ('palco','banheiro','portaria','ambulatorio','estacionamento','alimentacao','test_drive','heliponto','acessibilidade','servico','outro')),
  lote_id     uuid references public.lotes(id) on delete set null,
  ponto       jsonb check (public._ponto_valido(ponto)),
  horarios    text check (char_length(horarios) <= 200),
  status      text not null default 'a_confirmar' check (status in ('a_confirmar','confirmado')),
  obs         text check (char_length(obs) <= 500),
  excluido_em timestamptz,
  criado_em   timestamptz not null default now()
);

create table if not exists public.estandes (
  id           uuid primary key default gen_random_uuid(),
  ed           text not null references public.edicoes(slug) on delete cascade,
  expositor_id uuid not null references public.expositores(id) on delete cascade,
  juntar_lotes boolean not null default true,      -- decisão 32-3: o expositor escolhe juntar ou separar
  status       text not null default 'a_confirmar' check (status in ('a_confirmar','confirmado')),
  excluido_em  timestamptz,
  criado_em    timestamptz not null default now()
);
create table if not exists public.estande_lotes (
  estande_id uuid not null references public.estandes(id) on delete cascade,
  lote_id    uuid not null references public.lotes(id) on delete cascade,
  primary key (estande_id, lote_id)
);

create table if not exists public.agenda (
  id          uuid primary key default gen_random_uuid(),
  ed          text not null references public.edicoes(slug) on delete cascade,
  titulo      text not null check (char_length(titulo) between 1 and 200),
  tipo        text not null default 'palestra' check (tipo in ('palestra','demonstracao','lancamento','dinamica','test_drive','cerimonia','outro')),
  local_id    uuid references public.locais(id) on delete set null,
  inicio      timestamptz,
  fim         timestamptz,
  palestrante text check (char_length(palestrante) <= 200),
  descricao   text check (char_length(descricao) <= 2000),
  status      text not null default 'a_confirmar' check (status in ('a_confirmar','confirmado')),
  excluido_em timestamptz,
  criado_em   timestamptz not null default now(),
  check (fim is null or inicio is null or fim > inicio)
);

-- ---------- auditoria ----------
create table if not exists public.auditoria (
  id       bigint generated always as identity primary key,
  quando   timestamptz not null default now(),
  quem     uuid,
  tabela   text not null,
  registro text,
  acao     text not null,
  antes    jsonb,
  depois   jsonb
);
create or replace function public._auditar()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.auditoria (quem, tabela, registro, acao, antes, depois)
  values (auth.uid(), tg_table_name,
          coalesce((case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end)->>'id',
                   (case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end)->>'estande_id'),
          lower(tg_op),
          case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,
          case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end);
  return coalesce(new, old);
end $$;

do $$
declare t text;
begin
  foreach t in array array['feiras','categorias','expositores','plantas','lotes','locais','estandes','estande_lotes','agenda'] loop
    execute format('drop trigger if exists auditar on public.%I', t);
    execute format('create trigger auditar after insert or update or delete on public.%I for each row execute function public._auditar()', t);
  end loop;
end $$;

-- ---------- RLS e permissões ----------
do $$
declare t text;
begin
  foreach t in array array['feiras','categorias','expositores','plantas','lotes','locais','estandes','estande_lotes','agenda','auditoria'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from anon, authenticated, public', t);
  end loop;
  -- cadastros: equipe lê; quem pode editar insere e altera; só o administrador geral apaga de vez
  foreach t in array array['feiras','categorias','expositores','plantas','lotes','locais','estandes','estande_lotes','agenda'] loop
    execute format('grant select, insert, update, delete on table public.%I to authenticated', t);
    execute format('drop policy if exists le on public.%I', t);
    execute format('drop policy if exists insere on public.%I', t);
    execute format('drop policy if exists altera on public.%I', t);
    execute format('drop policy if exists apaga on public.%I', t);
    execute format('create policy le on public.%I for select to authenticated using ((select public.sou_equipe()))', t);
    execute format('create policy insere on public.%I for insert to authenticated with check ((select public.pode_editar_cadastros()))', t);
    execute format('create policy altera on public.%I for update to authenticated using ((select public.pode_editar_cadastros())) with check ((select public.pode_editar_cadastros()))', t);
    execute format('create policy apaga on public.%I for delete to authenticated using ((select public.sou_admin_geral()))', t);
  end loop;
end $$;
-- feiras: só o administrador geral cria ou altera
drop policy if exists insere on public.feiras;
drop policy if exists altera on public.feiras;
create policy insere on public.feiras for insert to authenticated with check ((select public.sou_admin_geral()));
create policy altera on public.feiras for update to authenticated using ((select public.sou_admin_geral())) with check ((select public.sou_admin_geral()));
-- estande_lotes não tem "excluido_em": desvincular é apagar, permitido a quem edita
drop policy if exists apaga on public.estande_lotes;
create policy apaga on public.estande_lotes for delete to authenticated using ((select public.pode_editar_cadastros()));

-- auditoria: só leitura, para administrador geral e coordenação
grant select on table public.auditoria to authenticated;
drop policy if exists le on public.auditoria;
create policy le on public.auditoria for select to authenticated using ((select public.sou_coordenador()));

-- edições: a equipe lê os dados públicos da edição (nunca o hash da chave da coleta)
grant select (slug, nome, aberta, criada_em, feira_id, ano, inicio, fim, dias, status) on table public.edicoes to authenticated;
drop policy if exists equipe_le_edicoes on public.edicoes;
create policy equipe_le_edicoes on public.edicoes for select to authenticated using ((select public.sou_equipe()));

-- ---------- pendências de dados (recalculada a cada consulta) ----------
create or replace view public.pendencias with (security_invoker = true) as
  select 'lote'::text as tipo, l.id as ref, l.ed, 'Lote ' || l.numero as item, 'dados a confirmar'::text as motivo
    from public.lotes l where l.excluido_em is null and l.status = 'a_confirmar'
  union all
  select 'lote', l.id, l.ed, 'Lote ' || l.numero, 'sem posição no mapa'
    from public.lotes l where l.excluido_em is null and l.poligono is null
  union all
  select 'local', o.id, o.ed, o.nome, 'sem posição no mapa'
    from public.locais o where o.excluido_em is null and o.ponto is null and o.lote_id is null
  union all
  select 'local', o.id, o.ed, o.nome, 'dados a confirmar'
    from public.locais o where o.excluido_em is null and o.status = 'a_confirmar'
  union all
  select 'estande', s.id, s.ed, x.nome, 'sem lote'
    from public.estandes s join public.expositores x on x.id = s.expositor_id
   where s.excluido_em is null and not exists (select 1 from public.estande_lotes el where el.estande_id = s.id)
  union all
  select 'expositor', x.id, s.ed, x.nome, 'sem categoria'
    from public.expositores x join public.estandes s on s.expositor_id = x.id and s.excluido_em is null
   where x.excluido_em is null and x.categoria_id is null
  union all
  select 'expositor', x.id, s.ed, x.nome, 'dados a confirmar'
    from public.expositores x join public.estandes s on s.expositor_id = x.id and s.excluido_em is null
   where x.excluido_em is null and x.status = 'a_confirmar'
  union all
  select 'agenda', a.id, a.ed, a.titulo, 'sem palco ou local'
    from public.agenda a where a.excluido_em is null and a.local_id is null
  union all
  select 'agenda', a.id, a.ed, a.titulo, 'sem horário'
    from public.agenda a where a.excluido_em is null and (a.inicio is null or a.fim is null)
  union all
  select 'planta', null::uuid, e.slug, e.nome, 'sem planta'
    from public.edicoes e where not exists (select 1 from public.plantas p where p.ed = e.slug and p.ativa and p.excluido_em is null)
  union all
  select 'planta', p.id, p.ed, 'Planta ativa', 'sem georreferência'
    from public.plantas p where p.ativa and p.excluido_em is null and p.georef is null;
revoke all on public.pendencias from anon, public;
grant select on public.pendencias to authenticated;

-- ---------- clonar edição ----------
-- Copia planta, lotes, locais, estandes e vínculos para uma nova edição (agenda não, porque as datas mudam).
-- Devolve a chave da coleta da nova edição, mostrada uma única vez.
create or replace function public.clonar_edicao(p_origem text, p_slug text, p_nome text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_or public.edicoes%rowtype; v_chave text := replace(gen_random_uuid()::text, '-', '');
begin
  if not public.sou_coordenador() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  select * into v_or from public.edicoes where slug = p_origem;
  if not found then raise exception 'edicao_inexistente' using errcode = 'P0001'; end if;
  if p_slug !~ '^[a-z0-9-]{1,60}$' or exists (select 1 from public.edicoes where slug = p_slug) then
    raise exception 'slug_invalido' using errcode = 'P0001'; end if;
  insert into public.edicoes (slug, nome, chave_hash, aberta, feira_id, ano, status)
  values (p_slug, left(p_nome, 120), encode(sha256(convert_to(v_chave, 'UTF8')), 'hex'), true, v_or.feira_id,
          nullif(substring(p_slug from '([0-9]{4})$'), '')::int, 'rascunho');
  insert into public.plantas (ed, imagem_url, largura, altura, georef, ativa)
    select p_slug, imagem_url, largura, altura, georef, ativa from public.plantas where ed = p_origem and excluido_em is null;
  create temporary table _map_lote on commit drop as
    select l.id as velho, gen_random_uuid() as novo from public.lotes l where l.ed = p_origem and l.excluido_em is null;
  insert into public.lotes (id, ed, numero, tipo, rotulo, fileira, poligono, status, obs)
    select m.novo, p_slug, l.numero, l.tipo, l.rotulo, l.fileira, l.poligono, 'a_confirmar', l.obs
      from public.lotes l join _map_lote m on m.velho = l.id;
  insert into public.locais (ed, nome, tipo, lote_id, ponto, horarios, status, obs)
    select p_slug, o.nome, o.tipo, m.novo, o.ponto, o.horarios, 'a_confirmar', o.obs
      from public.locais o left join _map_lote m on m.velho = o.lote_id
     where o.ed = p_origem and o.excluido_em is null;
  create temporary table _map_est on commit drop as
    select s.id as velho, gen_random_uuid() as novo from public.estandes s where s.ed = p_origem and s.excluido_em is null;
  insert into public.estandes (id, ed, expositor_id, juntar_lotes, status)
    select me.novo, p_slug, s.expositor_id, s.juntar_lotes, 'a_confirmar'
      from public.estandes s join _map_est me on me.velho = s.id;
  insert into public.estande_lotes (estande_id, lote_id)
    select me.novo, ml.novo from public.estande_lotes el
      join _map_est me on me.velho = el.estande_id join _map_lote ml on ml.velho = el.lote_id;
  return jsonb_build_object('edicao', p_slug, 'chave_da_coleta', v_chave);
end $$;

-- ---------- funções: permissões ----------
revoke all on function public.meu_papel()                       from public, anon, authenticated;
revoke all on function public.pode_editar_cadastros()           from public, anon, authenticated;
revoke all on function public.sou_admin_geral()                 from public, anon, authenticated;
revoke all on function public._ponto_valido(jsonb)              from public, anon, authenticated;
revoke all on function public._poligono_valido(jsonb)           from public, anon, authenticated;
revoke all on function public._georef_valida(jsonb)             from public, anon, authenticated;
revoke all on function public._auditar()                        from public, anon, authenticated;
revoke all on function public.clonar_edicao(text, text, text)   from public, anon, authenticated;
revoke all on function public.remover_membro(uuid)              from public, anon, authenticated;
grant execute on function public.meu_papel()                     to authenticated;
grant execute on function public.pode_editar_cadastros()         to authenticated;
grant execute on function public.sou_admin_geral()               to authenticated;
grant execute on function public.clonar_edicao(text, text, text) to authenticated;
grant execute on function public.remover_membro(uuid)            to authenticated;
-- as funções de validação são usadas pelas restrições das tabelas, que rodam com o papel de quem grava:
-- só conferem números, então podem ser usadas por quem tem login
grant execute on function public._ponto_valido(jsonb)    to authenticated;
grant execute on function public._poligono_valido(jsonb) to authenticated;
grant execute on function public._georef_valida(jsonb)   to authenticated;

-- ---------- armazenamento das plantas (só no Supabase) ----------
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values ('plantas', 'plantas', true, 20971520, array['image/png','image/jpeg','image/webp','image/svg+xml'])
    on conflict (id) do nothing;
    execute 'drop policy if exists plantas_insere on storage.objects';
    execute 'drop policy if exists plantas_altera on storage.objects';
    execute 'drop policy if exists plantas_apaga on storage.objects';
    execute $p$create policy plantas_insere on storage.objects for insert to authenticated
             with check (bucket_id = 'plantas' and (select public.pode_editar_cadastros()))$p$;
    execute $p$create policy plantas_altera on storage.objects for update to authenticated
             using (bucket_id = 'plantas' and (select public.pode_editar_cadastros()))$p$;
    execute $p$create policy plantas_apaga on storage.objects for delete to authenticated
             using (bucket_id = 'plantas' and (select public.pode_editar_cadastros()))$p$;
  end if;
end $$;
