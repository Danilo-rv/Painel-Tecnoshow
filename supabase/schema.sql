-- =====================================================================
-- Tecnoshow Avalia: banco de respostas no Supabase
-- Rode este arquivo inteiro no SQL Editor do projeto (uma vez; pode rodar de novo sem perder dados).
--
-- Modelo de segurança
--   * Os tablets usam a chave pública "anon". Ela só consegue chamar a função enviar_respostas,
--     que exige a chave da coleta da edição, valida cada resposta e só INSERE (não lê, não altera, não apaga).
--   * Painel e relatório exigem login (Supabase Auth) de uma conta cadastrada na tabela equipe.
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
  if coalesce(jsonb_typeof(r), '') <> 'object' or octet_length(r::text) > 4000 then return false; end if;
  for k in select jsonb_object_keys(r) loop
    if k <> all (array['id','t','tab','ed','lang','br','mun','pais','perfil','idade','gen','prim','dias','pern',
                       'obj','av','tecn','neg','gasto','nps','com','dur']) then return false; end if;
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
      if k not in ('est','prog','aten','seg','sin','cont') or jsonb_typeof(v) <> 'number' or (v #>> '{}') !~ '^[1-5]$' then return false; end if;
    end loop;
  end if;
  if coalesce(jsonb_typeof(r->'nps'), 'null') <> 'null' and coalesce(r->>'nps', '') !~ '^([0-9]|10)$' then return false; end if;
  if coalesce(jsonb_typeof(r->'com'), 'null') not in ('null','string') or char_length(coalesce(r->>'com', '')) > 400 then return false; end if;
  if coalesce(jsonb_typeof(r->'dur'), 'null') not in ('null','number') then return false; end if;
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

create or replace function public.sou_equipe()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.equipe where user_id = auth.uid())
$$;

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

-- Funções: por padrão o Postgres libera EXECUTE para todos; aqui só o necessário.
revoke all on function public._opcao(jsonb, text, text[])            from public, anon, authenticated;
revoke all on function public._resposta_valida(jsonb)                from public, anon, authenticated;
revoke all on function public.sou_equipe()                           from public, anon, authenticated;
revoke all on function public.enviar_respostas(text, text, jsonb)    from public, anon, authenticated;
grant execute on function public.sou_equipe()                        to authenticated;
grant execute on function public.enviar_respostas(text, text, jsonb) to anon, authenticated;

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
-- 3) Crie as contas da equipe em Authentication > Users > Add user e inclua cada uma:
--      insert into public.equipe (user_id, nome)
--        select id, 'Nome da pessoa' from auth.users where email = 'pessoa@ifgoiano.edu.br';
--
-- 4) Ao fim da coleta:  update public.edicoes set aberta = false where slug = 'tecnoshow-comigo-2027';
-- =====================================================================
