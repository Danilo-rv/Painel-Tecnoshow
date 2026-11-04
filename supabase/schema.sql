-- =====================================================================
-- Tecnoshow Avalia: banco de respostas no Supabase
-- Rode este arquivo inteiro no SQL Editor do projeto (uma vez; pode rodar de novo sem perder dados).
--
-- Modelo de segurança
--   * Os tablets usam a chave pública "anon". Ela só consegue chamar a função enviar_respostas,
--     que exige a chave da coleta da edição, valida cada resposta e só INSERE (não lê, não altera, não apaga).
--   * Painel e relatório exigem login (Supabase Auth) de uma conta cadastrada na tabela equipe.
--     Pessoas entram na equipe por link de convite (uso único, com validade) gerado pelo coordenador.
--     Uma conta criada sem convite não acessa nada.
--   * Só o coordenador publica versões do questionário, gera convites e remove pessoas.
--   * Nenhuma tabela é acessível diretamente pela chave anon (RLS ligado e permissões revogadas).
-- =====================================================================

-- ---------- tabelas ----------
create table if not exists public.edicoes (
  slug        text primary key check (slug ~ '^[a-z0-9-]{1,60}$'),
  nome        text not null,
  chave_hash  text not null check (chave_hash ~ '^[0-9a-f]{64}$'),   -- sha256 da chave da coleta, nunca a chave em si
  aberta      boolean not null default true,                         -- false encerra a coleta da edição
  criada_em   timestamptz not null default now()
);

create table if not exists public.equipe (
  user_id   uuid primary key references auth.users(id) on delete cascade,
  nome      text,
  criado_em timestamptz not null default now()
);
alter table public.equipe add column if not exists papel text not null default 'equipe';
alter table public.equipe drop constraint if exists equipe_papel_ok;
alter table public.equipe add constraint equipe_papel_ok check (papel in ('coordenador','equipe'));

-- questionário publicado, uma linha por versão (def = JSON do instrumento)
create table if not exists public.instrumentos (
  ed             text not null references public.edicoes(slug) on delete cascade,
  versao         int  not null check (versao > 0),
  def            jsonb not null check (octet_length(def::text) < 300000),
  publicado_em   timestamptz not null default now(),
  publicado_por  uuid references auth.users(id) on delete set null,
  primary key (ed, versao)
);

-- convites para a equipe: guardamos só o hash do link
create table if not exists public.convites (
  id          uuid primary key default gen_random_uuid(),
  token_hash  text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  criado_por  uuid references auth.users(id) on delete cascade,
  criado_em   timestamptz not null default now(),
  expira_em   timestamptz not null,
  usado_por   uuid references auth.users(id) on delete set null,
  usado_em    timestamptz
);

-- ---------- validação de uma resposta (mesmos valores do questionário) ----------
create or replace function public._opcao(r jsonb, campo text, opcoes text[])
returns boolean language sql immutable set search_path = '' as $$
  select coalesce(jsonb_typeof(r->campo), 'null') = 'null'
      or (jsonb_typeof(r->campo) = 'string' and (r->>campo) = any(opcoes))
$$;

create or replace function public._resposta_valida(r jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare k text; v jsonb;
begin
  if coalesce(jsonb_typeof(r), '') <> 'object' or octet_length(r::text) > 12000 then return false; end if;
  for k in select jsonb_object_keys(r) loop
    if k <> all (array['id','t','tab','ed','lang','br','mun','pais','perfil','idade','gen','prim','dias','pern',
                       'obj','av','tecn','neg','gasto','nps','com','dur','v','x']) then return false; end if;
  end loop;
  if coalesce(r->>'id', '') !~ '^[A-Za-z0-9-]{8,80}$' then return false; end if;
  if coalesce(jsonb_typeof(r->'t'), '') <> 'number' then return false; end if;
  if coalesce(r->>'tab', '') !~ '^(T[0-9]{2}|PAINEL)$' then return false; end if;
  if coalesce(r->>'ed', '') !~ '^[a-z0-9-]{1,60}$' then return false; end if;
  if coalesce(r->>'lang', '') not in ('pt','en','es') then return false; end if;
  if coalesce(r->>'br', '') not in ('0','1') then return false; end if;
  if coalesce(jsonb_typeof(r->'mun'), 'null') not in ('null','number') then return false; end if;
  if jsonb_typeof(r->'mun') = 'number' and (r->>'mun') !~ '^[0-9]{7}$' then return false; end if;
  if coalesce(jsonb_typeof(r->'pais'), 'null') <> 'null' and coalesce(r->>'pais', '') !~ '^[A-Z]{2}$' then return false; end if;
  if not (public._opcao(r,'perfil', array['pp','pm','pg','tec','exp','est','inv','vis'])
      and public._opcao(r,'idade',  array['a1','a2','a3','a4','a5','a6'])
      and public._opcao(r,'gen',    array['f','m','o','n'])
      and public._opcao(r,'prim',   array['s','nn'])
      and public._opcao(r,'dias',   array['d1','d2','d3','d4','d5'])
      and public._opcao(r,'pern',   array['pnao','prv','pout'])
      and public._opcao(r,'tecn',   array['ts','tav','tn'])
      and public._opcao(r,'neg',    array['n0','n1','n2','n3','n4'])
      and public._opcao(r,'gasto',  array['g0','g1','g2','g3','g4','g5','g6'])) then return false; end if;
  -- objetivos: lista de até 6 opções conhecidas
  if coalesce(jsonb_typeof(r->'obj'), 'null') not in ('null','array') then return false; end if;
  if jsonb_typeof(r->'obj') = 'array' then
    if jsonb_array_length(r->'obj') > 6 then return false; end if;
    for v in select jsonb_array_elements(r->'obj') loop
      if jsonb_typeof(v) <> 'string' or (v #>> '{}') not in ('otec','ocomp','oneg','opal','onet','olaz') then return false; end if;
    end loop;
  end if;
  -- avaliação: itens conhecidos, notas inteiras de 1 a 5
  if coalesce(jsonb_typeof(r->'av'), 'null') not in ('null','object') then return false; end if;
  if jsonb_typeof(r->'av') = 'object' then
    for k, v in select * from jsonb_each(r->'av') loop
      if k !~ '^[a-z][a-z0-9_]{0,23}$' or jsonb_typeof(v) <> 'number' or (v #>> '{}') !~ '^[1-5]$' then return false; end if;
    end loop;
  end if;
  if coalesce(jsonb_typeof(r->'nps'), 'null') <> 'null' and coalesce(r->>'nps', '') !~ '^([0-9]|10)$' then return false; end if;
  if coalesce(jsonb_typeof(r->'com'), 'null') not in ('null','string') or char_length(coalesce(r->>'com', '')) > 400 then return false; end if;
  if coalesce(jsonb_typeof(r->'dur'), 'null') not in ('null','number') then return false; end if;
  if coalesce(jsonb_typeof(r->'v'), 'null') <> 'null' and coalesce(r->>'v', '') !~ '^[0-9]{1,6}$' then return false; end if;
  if coalesce(jsonb_typeof(r->'x'), 'null') not in ('null','object') then return false; end if;
  if jsonb_typeof(r->'x') = 'object' then
    if (select count(*) from jsonb_object_keys(r->'x')) > 40 then return false; end if;
    for k in select jsonb_object_keys(r->'x') loop
      if k !~ '^[a-z][a-z0-9_]{0,23}$' then return false; end if;
    end loop;
  end if;
  return true;
end $$;

-- confere a resposta contra a versão do questionário em que foi dada
create or replace function public._conforme_instrumento(p_def jsonb, r jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare k text; v jsonb; p jsonb; ids text[]; a text; n jsonb;
begin
  -- itens de satisfação (pergunta av): na versão padrão, só os 6 originais
  if jsonb_typeof(r->'av') = 'object' then
    if p_def is null then
      ids := array['est','prog','aten','seg','sin','cont'];
    else
      select coalesce(array_agg(i->>'id'), '{}') into ids
        from jsonb_array_elements(p_def->'perguntas') q, jsonb_array_elements(coalesce(q->'items','[]')) i
       where q->>'id' = 'av';
    end if;
    for k in select jsonb_object_keys(r->'av') loop
      if not (k = any(ids)) then return false; end if;
    end loop;
  end if;
  if jsonb_typeof(r->'x') <> 'object' then return true; end if;
  if p_def is null then return (select count(*) from jsonb_object_keys(r->'x')) = 0; end if;
  for k, v in select * from jsonb_each(r->'x') loop
    p := null;
    select q into p from jsonb_array_elements(p_def->'perguntas') q
     where q->>'id' = k and coalesce((q->>'nucleo')::boolean, false) = false limit 1;
    if p is null then return false; end if;
    select coalesce(array_agg(o->>'id'), '{}') into ids from jsonb_array_elements(coalesce(p->'opts', p->'items', '[]')) o;
    case p->>'type'
      when 'single' then
        if jsonb_typeof(v) <> 'string' or not ((v #>> '{}') = any(ids)) then return false; end if;
      when 'multi' then
        if jsonb_typeof(v) <> 'array' or jsonb_array_length(v) > 30 then return false; end if;
        for a in select jsonb_array_elements_text(v) loop
          if not (a = any(ids)) then return false; end if;
        end loop;
      when 'rating' then
        if jsonb_typeof(v) <> 'object' then return false; end if;
        for a, n in select * from jsonb_each(v) loop
          if not (a = any(ids)) or jsonb_typeof(n) <> 'number' or (n #>> '{}') !~ '^[1-5]$' then return false; end if;
        end loop;
      when 'nps' then
        if jsonb_typeof(v) <> 'number' or (v #>> '{}') !~ '^([0-9]|10)$' then return false; end if;
      when 'text' then
        if jsonb_typeof(v) <> 'string' or char_length(v #>> '{}') > 400 then return false; end if;
      else return false;
    end case;
  end loop;
  return true;
end $$;

-- formato mínimo de um questionário publicado
create or replace function public._instrumento_valido(d jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare q jsonb; o jsonb; ids text[] := '{}';
begin
  if coalesce(jsonb_typeof(d), '') <> 'object' or coalesce(jsonb_typeof(d->'perguntas'), '') <> 'array' then return false; end if;
  if jsonb_array_length(d->'perguntas') not between 5 and 60 then return false; end if;
  for q in select jsonb_array_elements(d->'perguntas') loop
    if coalesce(q->>'id', '') !~ '^[a-z][a-z0-9_]{0,23}$' or (q->>'id') = any(ids) then return false; end if;
    ids := ids || (q->>'id');
    if coalesce(q->>'type', '') not in ('origem','single','multi','rating','nps','text') then return false; end if;
    if coalesce(jsonb_typeof(q->'opts'), 'null') not in ('null','array') or coalesce(jsonb_typeof(q->'items'), 'null') not in ('null','array') then return false; end if;
    for o in select jsonb_array_elements(coalesce(q->'opts','[]') || coalesce(q->'items','[]')) loop
      if coalesce(o->>'id', '') !~ '^[a-z][a-z0-9_]{0,23}$' then return false; end if;
    end loop;
  end loop;
  -- as perguntas do núcleo usadas pelo mapa, indicadores e impacto precisam existir
  if not (array['origem','perfil','av','gasto','nps'] <@ ids) then return false; end if;
  return true;
end $$;

create table if not exists public.respostas (
  seq          bigint generated always as identity primary key,   -- ordem de chegada (leitura incremental do painel)
  id           text not null unique,                              -- gerado no tablet: reenviar a mesma resposta não duplica
  ed           text not null references public.edicoes(slug) on delete cascade,
  tab          text not null,
  t            timestamptz not null,                               -- hora da resposta no tablet
  recebido_em  timestamptz not null default now(),
  dados        jsonb not null check (public._resposta_valida(dados))
);
create index if not exists respostas_ed_seq on public.respostas (ed, seq);

-- ---------- RLS e permissões ----------
alter table public.edicoes   enable row level security;
alter table public.equipe    enable row level security;
alter table public.respostas enable row level security;
revoke all on table public.edicoes, public.equipe, public.respostas from anon, authenticated, public;

alter table public.instrumentos enable row level security;
alter table public.convites     enable row level security;
revoke all on table public.instrumentos, public.convites from anon, authenticated, public;

create or replace function public.sou_equipe()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.equipe where user_id = auth.uid())
$$;
create or replace function public.sou_coordenador()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.equipe where user_id = auth.uid() and papel = 'coordenador')
$$;

grant select on table public.instrumentos to authenticated;
drop policy if exists equipe_le_instrumentos on public.instrumentos;
create policy equipe_le_instrumentos on public.instrumentos for select to authenticated
  using ((select public.sou_equipe()));

grant select on table public.respostas to authenticated;
drop policy if exists equipe_le_respostas on public.respostas;
create policy equipe_le_respostas on public.respostas for select to authenticated
  using ((select public.sou_equipe()));

-- ---------- envio dos tablets ----------
create or replace function public.enviar_respostas(p_ed text, p_chave text, p_itens jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_ed  public.edicoes%rowtype;
  v     jsonb;
  v_t   timestamptz;
  v_def jsonb;
  n_ok  int := 0; n_dup int := 0; n_inv int := 0;
begin
  select * into v_ed from public.edicoes where slug = p_ed;
  if not found or not v_ed.aberta then
    raise exception 'edicao_fechada' using errcode = 'P0001';
  end if;
  if p_chave is null or char_length(p_chave) > 200
     or encode(sha256(convert_to(p_chave, 'UTF8')), 'hex') <> v_ed.chave_hash then
    raise exception 'chave_invalida' using errcode = 'P0001';
  end if;
  if coalesce(jsonb_typeof(p_itens), '') <> 'array' or jsonb_array_length(p_itens) > 100 then
    raise exception 'lote_invalido' using errcode = 'P0001';
  end if;
  for v in select jsonb_array_elements(p_itens) loop
    if not public._resposta_valida(v) or (v->>'ed') is distinct from p_ed then
      n_inv := n_inv + 1; continue;
    end if;
    -- confere contra a versão do questionário (0 = padrão, sem perguntas novas)
    if coalesce((v->>'v')::int, 0) > 0 then
      select i.def into v_def from public.instrumentos i where i.ed = p_ed and i.versao = (v->>'v')::int;
      if not found then n_inv := n_inv + 1; continue; end if;
    else
      v_def := null;
    end if;
    if not public._conforme_instrumento(v_def, v) then
      n_inv := n_inv + 1; continue;
    end if;
    v_t := to_timestamp((v->>'t')::double precision / 1000);
    if v_t < now() - interval '90 days' or v_t > now() + interval '1 day' then
      n_inv := n_inv + 1; continue;
    end if;
    insert into public.respostas (id, ed, tab, t, dados)
    values (v->>'id', p_ed, v->>'tab', v_t, v)
    on conflict (id) do nothing;
    if found then n_ok := n_ok + 1; else n_dup := n_dup + 1; end if;
  end loop;
  return jsonb_build_object('gravadas', n_ok, 'repetidas', n_dup, 'invalidas', n_inv);
end $$;

-- ---------- questionário ----------
-- Os tablets (anon) leem a versão em uso: é o texto público do questionário, sem dados pessoais.
create or replace function public.instrumento_atual(p_ed text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select def || jsonb_build_object('versao', versao, 'publicado_em', publicado_em)
    from public.instrumentos where ed = p_ed order by versao desc limit 1
$$;

create or replace function public.publicar_instrumento(p_ed text, p_def jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_versao int; v_em timestamptz := now();
begin
  if not public.sou_coordenador() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  if not exists (select 1 from public.edicoes where slug = p_ed) then raise exception 'edicao_inexistente' using errcode = 'P0001'; end if;
  if not public._instrumento_valido(p_def) or octet_length(p_def::text) >= 300000 then raise exception 'instrumento_invalido' using errcode = 'P0001'; end if;
  perform pg_advisory_xact_lock(hashtext('instrumento:' || p_ed));
  select coalesce(max(versao), 0) + 1 into v_versao from public.instrumentos where ed = p_ed;
  insert into public.instrumentos (ed, versao, def, publicado_em, publicado_por)
  values (p_ed, v_versao, (p_def - 'versao' - 'publicado_em'), v_em, auth.uid());
  return jsonb_build_object('versao', v_versao, 'publicado_em', v_em);
end $$;

-- ---------- equipe e convites ----------
create or replace function public.criar_convite(p_dias int default 7)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare v_tok text := replace(gen_random_uuid()::text, '-', '');
begin
  if not public.sou_coordenador() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  insert into public.convites (token_hash, criado_por, expira_em)
  values (encode(sha256(convert_to(v_tok, 'UTF8')), 'hex'), auth.uid(), now() + make_interval(days => least(greatest(coalesce(p_dias, 7), 1), 30)));
  return v_tok;
end $$;

create or replace function public.aceitar_convite(p_token text)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
declare v_id uuid; v_nome text;
begin
  if auth.uid() is null then raise exception 'sem_sessao' using errcode = 'P0001'; end if;
  if exists (select 1 from public.equipe where user_id = auth.uid()) then return true; end if;
  update public.convites set usado_por = auth.uid(), usado_em = now()
   where token_hash = encode(sha256(convert_to(coalesce(p_token, ''), 'UTF8')), 'hex')
     and usado_por is null and expira_em > now()
  returning id into v_id;
  if v_id is null then raise exception 'convite_invalido' using errcode = 'P0001'; end if;
  select left(raw_user_meta_data->>'nome', 80) into v_nome from auth.users where id = auth.uid();
  insert into public.equipe (user_id, nome, papel) values (auth.uid(), v_nome, 'equipe') on conflict (user_id) do nothing;
  return true;
end $$;

create or replace function public.listar_equipe()
returns table (user_id uuid, email text, nome text, papel text, criado_em timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.sou_coordenador() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return query select e.user_id, u.email::text, e.nome, e.papel, e.criado_em
    from public.equipe e join auth.users u on u.id = e.user_id order by e.papel, e.criado_em;
end $$;

create or replace function public.listar_convites()
returns table (id uuid, criado_em timestamptz, expira_em timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.sou_coordenador() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return query select c.id, c.criado_em, c.expira_em from public.convites c
    where c.usado_por is null and c.expira_em > now() order by c.criado_em desc;
end $$;

create or replace function public.revogar_convite(p_id uuid)
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  if not public.sou_coordenador() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  delete from public.convites where id = p_id and usado_por is null;
end $$;

create or replace function public.remover_membro(p_user uuid)
returns void language plpgsql volatile security definer set search_path = '' as $$
begin
  if not public.sou_coordenador() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  if p_user = auth.uid() then raise exception 'nao_pode_remover_a_si' using errcode = 'P0001'; end if;
  delete from public.equipe where user_id = p_user and papel <> 'coordenador';
end $$;

-- Funções: por padrão o Postgres libera EXECUTE para todos; aqui só o necessário.
revoke all on function public._opcao(jsonb, text, text[])            from public, anon, authenticated;
revoke all on function public._resposta_valida(jsonb)                from public, anon, authenticated;
revoke all on function public.sou_equipe()                           from public, anon, authenticated;
revoke all on function public.enviar_respostas(text, text, jsonb)    from public, anon, authenticated;
revoke all on function public._conforme_instrumento(jsonb, jsonb)   from public, anon, authenticated;
revoke all on function public._instrumento_valido(jsonb)             from public, anon, authenticated;
revoke all on function public.sou_coordenador()                      from public, anon, authenticated;
revoke all on function public.instrumento_atual(text)                from public, anon, authenticated;
revoke all on function public.publicar_instrumento(text, jsonb)      from public, anon, authenticated;
revoke all on function public.criar_convite(int)                     from public, anon, authenticated;
revoke all on function public.aceitar_convite(text)                  from public, anon, authenticated;
revoke all on function public.listar_equipe()                        from public, anon, authenticated;
revoke all on function public.listar_convites()                      from public, anon, authenticated;
revoke all on function public.revogar_convite(uuid)                  from public, anon, authenticated;
revoke all on function public.remover_membro(uuid)                   from public, anon, authenticated;
grant execute on function public.sou_equipe()                        to authenticated;
grant execute on function public.sou_coordenador()                   to authenticated;
grant execute on function public.enviar_respostas(text, text, jsonb) to anon, authenticated;
grant execute on function public.instrumento_atual(text)             to anon, authenticated;
grant execute on function public.publicar_instrumento(text, jsonb)   to authenticated;
grant execute on function public.criar_convite(int)                  to authenticated;
grant execute on function public.aceitar_convite(text)               to authenticated;
grant execute on function public.listar_equipe()                     to authenticated;
grant execute on function public.listar_convites()                   to authenticated;
grant execute on function public.revogar_convite(uuid)               to authenticated;
grant execute on function public.remover_membro(uuid)                to authenticated;

-- =====================================================================
-- DEPOIS DE RODAR O ARQUIVO, cadastre a edição e a equipe (troque os valores):
--
-- 1) Gere uma chave da coleta e anote o resultado (ela vai nos tablets):
--      select replace(gen_random_uuid()::text, '-', '') as chave_da_coleta;
--
-- 2) Cadastre a edição. O slug é o nome da edição em minúsculas, sem acentos, com hífens
--    ("Tecnoshow Comigo 2027" vira "tecnoshow-comigo-2027"), igual ao campo Edição do app:
--      insert into public.edicoes (slug, nome, chave_hash) values
--        ('tecnoshow-comigo-2027', 'Tecnoshow Comigo 2027',
--         encode(sha256(convert_to('COLE_AQUI_A_CHAVE_DA_COLETA', 'UTF8')), 'hex'));
--
-- 3) Crie a SUA conta de coordenador em Authentication > Users > Add user (marque "Auto Confirm User")
--    e dê a ela o papel de coordenador:
--      insert into public.equipe (user_id, nome, papel)
--        select id, 'Seu nome', 'coordenador' from auth.users where email = 'seu.email@ifgoiano.edu.br'
--      on conflict (user_id) do update set papel = 'coordenador';
--
-- 4) O restante da equipe entra pelos links de convite gerados no app (Administração > Equipe).
--    Para isso, deixe ligado "Allow new users to sign up" em Authentication > Sign In / Providers:
--    uma conta criada sem convite não acessa nada.
--
-- 5) Ao fim da coleta:  update public.edicoes set aberta = false where slug = 'tecnoshow-comigo-2027';
-- =====================================================================
