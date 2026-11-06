-- =====================================================================
-- Migração 008: Tecnoshow na Cidade (seção 10 da ideação; decisões 15, 16 e 17)
-- Rode depois da 007. Pode ser rodada de novo sem perder dados.
--
--   * Estabelecimentos parceiros (bares, restaurantes, hotéis, lojas, serviços, turismo)
--     de Rio Verde e das cidades vizinhas, com QR próprio.
--   * O visitante usa o MESMO perfil anônimo da feira: check-in, carinhas e
--     "gostaria de ver este lugar na feira?". No hotel, a pesquisa do hóspede.
--   * Conta do parceiro (convite por link): vê os próprios números. O hotel informa a
--     ocupação diária (sigilosa) e recebe a demanda da cidade, só com 3 ou mais hotéis.
--   * Organização: prospecção de expositores, perfil dos hóspedes, transbordamento regional.
-- =====================================================================

create table if not exists public.estabelecimentos (
  id          uuid primary key default gen_random_uuid(),
  ed          text not null references public.edicoes(slug) on delete cascade,
  nome        text not null check (char_length(nome) between 1 and 120),
  tipo        text not null check (tipo in ('bar','restaurante','hotel','loja','servico','turismo','outro')),
  municipio   int  not null check (municipio between 1000000 and 9999999),
  endereco    text check (char_length(endereco) <= 200),
  quartos     int  check (quartos between 1 and 5000),
  status      text not null default 'a_confirmar' check (status in ('a_confirmar','confirmado')),
  obs         text check (char_length(obs) <= 500),
  excluido_em timestamptz,
  criado_em   timestamptz not null default now()
);
alter table public.estabelecimentos enable row level security;
revoke all on table public.estabelecimentos from anon, authenticated, public;
grant select, insert, update, delete on table public.estabelecimentos to authenticated;
drop policy if exists le on public.estabelecimentos;
drop policy if exists insere on public.estabelecimentos;
drop policy if exists altera on public.estabelecimentos;
drop policy if exists apaga on public.estabelecimentos;
create policy le on public.estabelecimentos for select to authenticated using ((select public.sou_equipe()));
create policy insere on public.estabelecimentos for insert to authenticated with check ((select public.pode_editar_cadastros()));
create policy altera on public.estabelecimentos for update to authenticated using ((select public.pode_editar_cadastros())) with check ((select public.pode_editar_cadastros()));
create policy apaga on public.estabelecimentos for delete to authenticated using ((select public.sou_admin_geral()));
drop trigger if exists auditar on public.estabelecimentos;
create trigger auditar after insert or update or delete on public.estabelecimentos for each row execute function public._auditar();

create table if not exists public.cidade_checkins (
  id        bigint generated always as identity primary key,
  visitante uuid not null references public.visitantes(id) on delete cascade,
  estab_id  uuid not null references public.estabelecimentos(id) on delete cascade,
  quando    timestamptz not null default now()
);
create index if not exists cidade_checkins_estab on public.cidade_checkins (estab_id, quando);
create table if not exists public.cidade_avaliacoes (
  visitante     uuid not null references public.visitantes(id) on delete cascade,
  estab_id      uuid not null references public.estabelecimentos(id) on delete cascade,
  carinha       text check (carinha in ('bom','neutro','ruim')),
  quer_na_feira boolean,
  quando        timestamptz not null default now(),
  primary key (visitante, estab_id)
);
create table if not exists public.hospedagens (
  visitante   uuid not null references public.visitantes(id) on delete cascade,
  estab_id    uuid not null references public.estabelecimentos(id) on delete cascade,
  noites      int  not null check (noites between 1 and 30),
  pessoas     int  not null check (pessoas between 1 and 20),
  diaria      text not null check (diaria in ('d1','d2','d3','d4','d5')),
  antecedencia text not null check (antecedencia in ('a0','a1','a2','a3')),
  motivo      text not null check (motivo in ('feira','negocios','turismo','familia','outro')),
  carinha     text check (carinha in ('bom','neutro','ruim')),
  quando      timestamptz not null default now(),
  primary key (visitante, estab_id)
);
create table if not exists public.ocupacao_hoteis (
  estab_id   uuid not null references public.estabelecimentos(id) on delete cascade,
  dia        date not null,
  quartos    int  not null check (quartos between 1 and 5000),
  ocupados   int  not null check (ocupados >= 0),
  diaria_media numeric(10,2) check (diaria_media between 0 and 100000),
  informado_por uuid,
  informado_em timestamptz not null default now(),
  primary key (estab_id, dia),
  check (ocupados <= quartos)
);
create table if not exists public.estab_equipe (
  user_id   uuid not null references auth.users(id) on delete cascade,
  estab_id  uuid not null references public.estabelecimentos(id) on delete cascade,
  nome      text,
  criado_em timestamptz not null default now(),
  primary key (user_id, estab_id)
);
do $$
declare t text;
begin
  foreach t in array array['cidade_checkins','cidade_avaliacoes','hospedagens','ocupacao_hoteis','estab_equipe'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from anon, authenticated, public', t);
  end loop;
end $$;
drop trigger if exists auditar on public.estab_equipe;
create trigger auditar after insert or update or delete on public.estab_equipe for each row execute function public._auditar();
drop trigger if exists auditar on public.ocupacao_hoteis;
create trigger auditar after insert or update or delete on public.ocupacao_hoteis for each row execute function public._auditar();

-- ---------- convites de parceiro ----------
alter table public.convites drop constraint if exists convites_papel_ok;
alter table public.convites add constraint convites_papel_ok check (papel in ('equipe','moderador','organizacao','coordenador','gestor','atendente','parceiro'));
alter table public.convites add column if not exists estab_id uuid references public.estabelecimentos(id) on delete cascade;

create or replace function public.criar_convite_parceiro(p_estab uuid, p_dias int default 14)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare v_tok text := replace(gen_random_uuid()::text, '-', '');
begin
  if not public.pode_editar_cadastros() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  if not exists (select 1 from public.estabelecimentos where id = p_estab and excluido_em is null) then raise exception 'estab_invalido' using errcode = 'P0001'; end if;
  insert into public.convites (token_hash, criado_por, expira_em, papel, estab_id)
  values (encode(sha256(convert_to(v_tok, 'UTF8')), 'hex'), auth.uid(),
          now() + make_interval(days => least(greatest(coalesce(p_dias, 14), 1), 60)), 'parceiro', p_estab);
  return v_tok;
end $$;

create or replace function public.aceitar_convite(p_token text)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare c public.convites%rowtype; v_nome text;
begin
  if auth.uid() is null then raise exception 'sem_sessao' using errcode = 'P0001'; end if;
  select * into c from public.convites
   where token_hash = encode(sha256(convert_to(coalesce(p_token, ''), 'UTF8')), 'hex')
     and usado_por is null and expira_em > now()
   for update;
  if not found then raise exception 'convite_invalido' using errcode = 'P0001'; end if;
  update public.convites set usado_por = auth.uid(), usado_em = now() where id = c.id;
  select left(raw_user_meta_data->>'nome', 80) into v_nome from auth.users where id = auth.uid();
  if c.estab_id is not null then
    insert into public.estab_equipe (user_id, estab_id, nome) values (auth.uid(), c.estab_id, v_nome) on conflict do nothing;
    return 'parceiro';
  elsif c.expositor_id is not null then
    insert into public.expositor_equipe (user_id, expositor_id, papel, nome)
    values (auth.uid(), c.expositor_id, c.papel, v_nome) on conflict (user_id, expositor_id) do nothing;
    return 'expositor';
  end if;
  insert into public.equipe (user_id, nome, papel) values (auth.uid(), v_nome, c.papel) on conflict (user_id) do nothing;
  return 'equipe';
end $$;

drop function if exists public.listar_convites();
create or replace function public.listar_convites()
returns table (id uuid, criado_em timestamptz, expira_em timestamptz, papel text, expositor text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.pode_editar_cadastros() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return query select c.id, c.criado_em, c.expira_em, c.papel, coalesce(x.nome, e.nome)
    from public.convites c left join public.expositores x on x.id = c.expositor_id left join public.estabelecimentos e on e.id = c.estab_id
    where c.usado_por is null and c.expira_em > now()
      and (public.sou_coordenador() or c.expositor_id is not null or c.estab_id is not null)
    order by c.criado_em desc;
end $$;

create or replace function public.listar_contas_parceiro(p_estab uuid)
returns table (user_id uuid, nome text, email text, criado_em timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.pode_editar_cadastros() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return query select q.user_id, q.nome, u.email::text, q.criado_em from public.estab_equipe q join auth.users u on u.id = q.user_id
   where q.estab_id = p_estab order by q.criado_em;
end $$;
create or replace function public.remover_conta_parceiro(p_user uuid, p_estab uuid)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
begin
  if not public.pode_editar_cadastros() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  delete from public.estab_equipe where user_id = p_user and estab_id = p_estab;
  return found;
end $$;

create or replace function public._pode_ver_estab(p_estab uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.pode_editar_cadastros() or exists (select 1 from public.estab_equipe where estab_id = p_estab and user_id = auth.uid())
$$;
create or replace function public.meus_estabelecimentos()
returns table (estab_id uuid, ed text, nome text, tipo text)
language sql stable security definer set search_path = '' as $$
  select e.id, e.ed, e.nome, e.tipo from public.estab_equipe q join public.estabelecimentos e on e.id = q.estab_id and e.excluido_em is null
   where q.user_id = auth.uid() order by e.nome
$$;

-- ---------- visitante ----------
create or replace function public.estab_publico(p_estab uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', e.id, 'ed', e.ed, 'nome', e.nome, 'tipo', e.tipo, 'municipio', e.municipio, 'endereco', e.endereco)
    from public.estabelecimentos e where e.id = p_estab and e.excluido_em is null
$$;

create or replace function public.estado_cidade(p_token text, p_estab uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante(p_token);
begin
  return jsonb_build_object('menor', v.menor,
    'carinha', (select carinha from public.cidade_avaliacoes where visitante = v.id and estab_id = p_estab),
    'quer_na_feira', (select quer_na_feira from public.cidade_avaliacoes where visitante = v.id and estab_id = p_estab),
    'hospede', exists (select 1 from public.hospedagens where visitante = v.id and estab_id = p_estab));
end $$;

create or replace function public.interagir_cidade(p_token text, p_estab uuid, p_acao text, p_valor text default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante(p_token); e public.estabelecimentos%rowtype;
begin
  select * into e from public.estabelecimentos where id = p_estab and excluido_em is null;
  if not found or e.ed <> v.ed then raise exception 'estab_invalido' using errcode = 'P0001'; end if;
  if (select count(*) from public.cidade_checkins where visitante = v.id and quando > now() - interval '1 hour') >= 60 then
    raise exception 'limite' using errcode = 'P0001'; end if;
  -- avaliar só depois do check-in (seção 10.5)
  if p_acao = 'checkin' or not exists (select 1 from public.cidade_checkins where visitante = v.id and estab_id = p_estab) then
    if not exists (select 1 from public.cidade_checkins where visitante = v.id and estab_id = p_estab and quando > now() - interval '30 minutes') then
      insert into public.cidade_checkins (visitante, estab_id) values (v.id, p_estab);
    end if;
  end if;
  if p_acao = 'carinha' then
    if coalesce(p_valor, '') not in ('bom','neutro','ruim') then raise exception 'valor_invalido' using errcode = 'P0001'; end if;
    insert into public.cidade_avaliacoes (visitante, estab_id, carinha) values (v.id, p_estab, p_valor)
    on conflict (visitante, estab_id) do update set carinha = excluded.carinha, quando = now();
  elsif p_acao = 'quer_na_feira' then
    if coalesce(p_valor, '') not in ('sim','nao') then raise exception 'valor_invalido' using errcode = 'P0001'; end if;
    insert into public.cidade_avaliacoes (visitante, estab_id, quer_na_feira) values (v.id, p_estab, p_valor = 'sim')
    on conflict (visitante, estab_id) do update set quer_na_feira = excluded.quer_na_feira, quando = now();
  elsif p_acao <> 'checkin' then raise exception 'acao_invalida' using errcode = 'P0001';
  end if;
  return public.estado_cidade(p_token, p_estab);
end $$;

create or replace function public.pesquisa_hospede(p_token text, p_estab uuid, p_dados jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante(p_token); e public.estabelecimentos%rowtype;
begin
  select * into e from public.estabelecimentos where id = p_estab and excluido_em is null;
  if not found or e.ed <> v.ed or e.tipo <> 'hotel' then raise exception 'estab_invalido' using errcode = 'P0001'; end if;
  if jsonb_typeof(p_dados) <> 'object' or (select count(*) from jsonb_object_keys(p_dados) k where k not in ('noites','pessoas','diaria','antecedencia','motivo','carinha')) > 0 then
    raise exception 'valor_invalido' using errcode = 'P0001'; end if;
  begin
    insert into public.hospedagens (visitante, estab_id, noites, pessoas, diaria, antecedencia, motivo, carinha)
    values (v.id, p_estab, (p_dados->>'noites')::int, (p_dados->>'pessoas')::int, p_dados->>'diaria', p_dados->>'antecedencia', p_dados->>'motivo', p_dados->>'carinha')
    on conflict (visitante, estab_id) do update set noites = excluded.noites, pessoas = excluded.pessoas, diaria = excluded.diaria,
      antecedencia = excluded.antecedencia, motivo = excluded.motivo, carinha = excluded.carinha, quando = now();
  exception when check_violation or not_null_violation or invalid_text_representation then
    raise exception 'valor_invalido' using errcode = 'P0001';
  end;
  if not exists (select 1 from public.cidade_checkins where visitante = v.id and estab_id = p_estab) then
    insert into public.cidade_checkins (visitante, estab_id) values (v.id, p_estab);
  end if;
  if p_dados->>'carinha' is not null then                -- a satisfação do hóspede entra na avaliação do hotel
    insert into public.cidade_avaliacoes (visitante, estab_id, carinha) values (v.id, p_estab, p_dados->>'carinha')
    on conflict (visitante, estab_id) do update set carinha = excluded.carinha, quando = now();
  end if;
  return public.estado_cidade(p_token, p_estab);
end $$;

-- ---------- parceiro: ocupação e painel ----------
create or replace function public.registrar_ocupacao(p_estab uuid, p_dia date, p_quartos int, p_ocupados int, p_diaria numeric default null)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
begin
  if not public._pode_ver_estab(p_estab) then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  if not exists (select 1 from public.estabelecimentos where id = p_estab and tipo = 'hotel' and excluido_em is null) then raise exception 'estab_invalido' using errcode = 'P0001'; end if;
  if p_dia is null or p_dia > current_date + 1 or p_dia < current_date - 400 then raise exception 'data_invalida' using errcode = 'P0001'; end if;
  begin
    insert into public.ocupacao_hoteis (estab_id, dia, quartos, ocupados, diaria_media, informado_por)
    values (p_estab, p_dia, p_quartos, p_ocupados, p_diaria, auth.uid())
    on conflict (estab_id, dia) do update set quartos = excluded.quartos, ocupados = excluded.ocupados, diaria_media = excluded.diaria_media,
      informado_por = excluded.informado_por, informado_em = now();
  exception when check_violation or not_null_violation then raise exception 'valor_invalido' using errcode = 'P0001';
  end;
  return true;
end $$;

-- demanda da cidade: só dias com 3 ou mais hotéis informantes (decisão 16)
create or replace function public._demanda_hoteis(p_ed text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('dia', dia, 'hoteis', n, 'ocupacao', taxa, 'diaria_media', dm) order by dia), '[]')
    from (select o.dia, count(*) n, round(100.0 * sum(o.ocupados) / sum(o.quartos), 1) taxa,
                 case when count(o.diaria_media) >= 3 then round(avg(o.diaria_media), 0) end dm
            from public.ocupacao_hoteis o join public.estabelecimentos e on e.id = o.estab_id
           where e.ed = p_ed and e.excluido_em is null group by o.dia having count(*) >= 3) d
$$;

create or replace function public.painel_parceiro(p_estab uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare e public.estabelecimentos%rowtype; v_vis int; v_hosp int;
begin
  if not public._pode_ver_estab(p_estab) then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  select * into e from public.estabelecimentos where id = p_estab and excluido_em is null;
  if not found then raise exception 'estab_invalido' using errcode = 'P0001'; end if;
  select count(distinct visitante) into v_vis from public.cidade_checkins where estab_id = p_estab;
  select count(*) into v_hosp from public.hospedagens where estab_id = p_estab;
  return jsonb_build_object(
    'estab', jsonb_build_object('id', e.id, 'ed', e.ed, 'nome', e.nome, 'tipo', e.tipo, 'municipio', e.municipio, 'quartos', e.quartos),
    'visitantes', v_vis,
    'checkins', (select count(*) from public.cidade_checkins where estab_id = p_estab),
    'satisfacao', (select jsonb_build_object('bom', count(*) filter (where carinha='bom'), 'neutro', count(*) filter (where carinha='neutro'),
                     'ruim', count(*) filter (where carinha='ruim'), 'total', count(carinha)) from public.cidade_avaliacoes where estab_id = p_estab),
    'quer_na_feira', (select count(*) filter (where quer_na_feira) from public.cidade_avaliacoes where estab_id = p_estab),
    'por_dia', coalesce((select jsonb_agg(jsonb_build_object('dia', d, 'n', n) order by d) from (
                 select (quando at time zone 'America/Sao_Paulo')::date d, count(distinct visitante) n from public.cidade_checkins where estab_id = p_estab group by 1) x), '[]'),
    -- perfil e hospedagem do próprio estabelecimento só com 5 ou mais pessoas
    'perfil', case when v_vis >= 5 then (select jsonb_object_agg(k, n) from (select v.perfil->>'perfil' k, count(*) n from public.visitantes v
                 where v.id in (select visitante from public.cidade_checkins where estab_id = p_estab) group by 1) a) end,
    'origem', case when v_vis >= 5 then (select jsonb_agg(jsonb_build_object('mun', mun, 'pais', pais, 'n', n) order by n desc) from (
                 select (v.perfil->>'mun')::int mun, v.perfil->>'pais' pais, count(*) n from public.visitantes v
                  where v.id in (select visitante from public.cidade_checkins where estab_id = p_estab) group by 1, 2
                 having count(*) >= 3 order by 3 desc limit 8) o) end,   -- só grupos de 3 ou mais pessoas
    'hospedes', case when v_hosp >= 5 then (select jsonb_build_object('respostas', count(*), 'noites_media', round(avg(noites), 1), 'pessoas_media', round(avg(pessoas), 1),
                 'diaria', (select jsonb_object_agg(diaria, n) from (select diaria, count(*) n from public.hospedagens where estab_id = p_estab group by 1) a),
                 'antecedencia', (select jsonb_object_agg(antecedencia, n) from (select antecedencia, count(*) n from public.hospedagens where estab_id = p_estab group by 1) a),
                 'motivo', (select jsonb_object_agg(motivo, n) from (select motivo, count(*) n from public.hospedagens where estab_id = p_estab group by 1) a))
               from public.hospedagens where estab_id = p_estab) end,
    'hospedes_n', v_hosp,
    'ocupacao', case when e.tipo = 'hotel' then coalesce((select jsonb_agg(jsonb_build_object('dia', dia, 'quartos', quartos, 'ocupados', ocupados, 'diaria_media', diaria_media) order by dia desc)
                 from (select * from public.ocupacao_hoteis where estab_id = p_estab order by dia desc limit 30) o), '[]') end,
    'demanda_cidade', case when e.tipo = 'hotel' then public._demanda_hoteis(e.ed) end);
end $$;

-- ---------- organização ----------
create or replace function public.resumo_cidade(p_ed text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_hosp int;
begin
  if not public.sou_equipe() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  select count(*) into v_hosp from public.hospedagens h join public.estabelecimentos e on e.id = h.estab_id where e.ed = p_ed;
  return jsonb_build_object(
    'estabelecimentos', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'nome', e.nome, 'tipo', e.tipo, 'municipio', e.municipio,
          'visitantes', (select count(distinct visitante) from public.cidade_checkins c where c.estab_id = e.id),
          'bom', (select count(*) from public.cidade_avaliacoes a where a.estab_id = e.id and a.carinha = 'bom'),
          'ruim', (select count(*) from public.cidade_avaliacoes a where a.estab_id = e.id and a.carinha = 'ruim'),
          'avaliacoes', (select count(carinha) from public.cidade_avaliacoes a where a.estab_id = e.id),
          'quer_na_feira', (select count(*) from public.cidade_avaliacoes a where a.estab_id = e.id and a.quer_na_feira),
          'contas', (select count(*) from public.estab_equipe q where q.estab_id = e.id)) order by e.nome)
        from public.estabelecimentos e where e.ed = p_ed and e.excluido_em is null), '[]'),
    'visitantes_cidade', (select count(distinct c.visitante) from public.cidade_checkins c join public.estabelecimentos e on e.id = c.estab_id where e.ed = p_ed),
    'visitantes_feira_e_cidade', (select count(distinct c.visitante) from public.cidade_checkins c join public.estabelecimentos e on e.id = c.estab_id
                                  where e.ed = p_ed and exists (select 1 from public.checkins k where k.visitante = c.visitante)),
    -- hóspedes: agregados de todos os hotéis, a partir de 5 respostas
    'hospedes', case when v_hosp >= 5 then (select jsonb_build_object('respostas', count(*), 'noites_media', round(avg(h.noites), 1), 'pessoas_media', round(avg(h.pessoas), 1),
          'diaria', (select jsonb_object_agg(diaria, n) from (select h2.diaria, count(*) n from public.hospedagens h2 join public.estabelecimentos e2 on e2.id = h2.estab_id where e2.ed = p_ed group by 1) a),
          'antecedencia', (select jsonb_object_agg(antecedencia, n) from (select h2.antecedencia, count(*) n from public.hospedagens h2 join public.estabelecimentos e2 on e2.id = h2.estab_id where e2.ed = p_ed group by 1) a),
          'motivo', (select jsonb_object_agg(motivo, n) from (select h2.motivo, count(*) n from public.hospedagens h2 join public.estabelecimentos e2 on e2.id = h2.estab_id where e2.ed = p_ed group by 1) a))
        from public.hospedagens h join public.estabelecimentos e on e.id = h.estab_id where e.ed = p_ed) end,
    'hospedes_n', v_hosp,
    -- transbordamento: hóspedes por município do hotel, só municípios com 3 ou mais hotéis; o resto vai para "outras cidades"
    'transbordamento', (select coalesce(jsonb_agg(jsonb_build_object('municipio', mun, 'hospedes', n) order by n desc), '[]') from (
        select case when (select count(*) from public.estabelecimentos e3 where e3.ed = p_ed and e3.tipo = 'hotel' and e3.excluido_em is null and e3.municipio = e.municipio) >= 3
                    then e.municipio end mun, count(*) n
          from public.hospedagens h join public.estabelecimentos e on e.id = h.estab_id where e.ed = p_ed group by 1) t),
    'demanda', public._demanda_hoteis(p_ed));
end $$;

-- ---------- permissões ----------
revoke all on function public.criar_convite_parceiro(uuid, int)                          from public, anon, authenticated;
revoke all on function public.aceitar_convite(text)                                     from public, anon, authenticated;
revoke all on function public.listar_convites()                                         from public, anon, authenticated;
revoke all on function public.listar_contas_parceiro(uuid)                              from public, anon, authenticated;
revoke all on function public.remover_conta_parceiro(uuid, uuid)                        from public, anon, authenticated;
revoke all on function public._pode_ver_estab(uuid)                                     from public, anon, authenticated;
revoke all on function public.meus_estabelecimentos()                                   from public, anon, authenticated;
revoke all on function public.estab_publico(uuid)                                       from public, anon, authenticated;
revoke all on function public.estado_cidade(text, uuid)                                 from public, anon, authenticated;
revoke all on function public.interagir_cidade(text, uuid, text, text)                  from public, anon, authenticated;
revoke all on function public.pesquisa_hospede(text, uuid, jsonb)                       from public, anon, authenticated;
revoke all on function public.registrar_ocupacao(uuid, date, int, int, numeric)         from public, anon, authenticated;
revoke all on function public._demanda_hoteis(text)                                     from public, anon, authenticated;
revoke all on function public.painel_parceiro(uuid)                                     from public, anon, authenticated;
revoke all on function public.resumo_cidade(text)                                       from public, anon, authenticated;
grant execute on function public.criar_convite_parceiro(uuid, int)                      to authenticated;
grant execute on function public.aceitar_convite(text)                                  to authenticated;
grant execute on function public.listar_convites()                                      to authenticated;
grant execute on function public.listar_contas_parceiro(uuid)                           to authenticated;
grant execute on function public.remover_conta_parceiro(uuid, uuid)                     to authenticated;
grant execute on function public.meus_estabelecimentos()                                to authenticated;
grant execute on function public.estab_publico(uuid)                                    to anon, authenticated;
grant execute on function public.estado_cidade(text, uuid)                              to anon, authenticated;
grant execute on function public.interagir_cidade(text, uuid, text, text)               to anon, authenticated;
grant execute on function public.pesquisa_hospede(text, uuid, jsonb)                    to anon, authenticated;
grant execute on function public.registrar_ocupacao(uuid, date, int, int, numeric)      to authenticated;
grant execute on function public.painel_parceiro(uuid)                                  to authenticated;
grant execute on function public.resumo_cidade(text)                                    to authenticated;
