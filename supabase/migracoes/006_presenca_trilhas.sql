-- =====================================================================
-- Migração 006: presença em palestras (QR que muda a cada minuto) e trilhas com cupom
-- Rode depois da 005. Pode ser rodada de novo sem perder dados.
--
-- Presença: o telão do auditório mostra um QR com um código que muda a cada minuto.
--   O código vale no minuto atual e no anterior, e só durante a sessão (de 15 min antes
--   do início até 15 min depois do fim). Uma foto do QR enviada por WhatsApp expira logo.
-- Trilhas: etapas (palestras e estandes), prêmio, estoque e prazo. Quem completa recebe
--   um cupom de uso único; o estande doador dá baixa. Prêmio por ordem de chegada, sem sorteio.
-- =====================================================================

-- ---------- presença em palestras ----------
create table if not exists public._agenda_segredos (
  agenda_id uuid primary key references public.agenda(id) on delete cascade,
  segredo   text not null
);
alter table public._agenda_segredos enable row level security;
revoke all on table public._agenda_segredos from anon, authenticated, public;

create table if not exists public.presencas (
  id         bigint generated always as identity primary key,
  visitante  uuid not null references public.visitantes(id) on delete cascade,
  agenda_id  uuid not null references public.agenda(id) on delete cascade,
  quando     timestamptz not null default now(),
  unique (visitante, agenda_id)
);
create index if not exists presencas_agenda on public.presencas (agenda_id);
alter table public.presencas enable row level security;
revoke all on table public.presencas from anon, authenticated, public;

create or replace function public._palestra_aberta(a public.agenda)
returns boolean language sql stable set search_path = '' as $$
  select a.inicio is not null and a.excluido_em is null
     and now() between a.inicio - interval '15 minutes' and coalesce(a.fim, a.inicio + interval '2 hours') + interval '15 minutes'
$$;

create or replace function public._codigo_palestra(p_agenda uuid, p_janela bigint)
returns text language sql stable security definer set search_path = '' as $$
  select left(encode(extensions.digest(s.segredo || ':' || p_janela::text, 'sha256'), 'hex'), 10)
    from public._agenda_segredos s where s.agenda_id = p_agenda
$$;

-- telão do auditório (equipe logada): código do minuto, situação e contagem
create or replace function public.codigo_palestra(p_agenda uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare a public.agenda%rowtype; v_j bigint := floor(extract(epoch from now()) / 60);
begin
  if not public.sou_equipe() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  select * into a from public.agenda where id = p_agenda and excluido_em is null;
  if not found then raise exception 'agenda_invalida' using errcode = 'P0001'; end if;
  insert into public._agenda_segredos (agenda_id, segredo) values (p_agenda, encode(extensions.gen_random_bytes(16), 'hex'))
  on conflict (agenda_id) do nothing;
  return jsonb_build_object('codigo', public._codigo_palestra(p_agenda, v_j), 'valido_ate', to_timestamp((v_j + 1) * 60),
    'titulo', a.titulo, 'palestrante', a.palestrante, 'inicio', a.inicio, 'fim', a.fim, 'ed', a.ed,
    'local', (select nome from public.locais where id = a.local_id), 'aberta', public._palestra_aberta(a),
    'presentes', (select count(*) from public.presencas where agenda_id = p_agenda));
end $$;

-- página pública da palestra (sem dados de visitantes)
create or replace function public.palestra_publica(p_agenda uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', a.id, 'ed', a.ed, 'titulo', a.titulo, 'tipo', a.tipo, 'palestrante', a.palestrante,
           'descricao', a.descricao, 'inicio', a.inicio, 'fim', a.fim, 'aberta', public._palestra_aberta(a),
           'local', (select nome from public.locais where id = a.local_id))
    from public.agenda a where a.id = p_agenda and a.excluido_em is null
$$;

create or replace function public.estado_palestra(p_token text, p_agenda uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante(p_token);
begin
  return jsonb_build_object('menor', v.menor,
    'presente', exists (select 1 from public.presencas where visitante = v.id and agenda_id = p_agenda),
    'carinha', (select carinha from public.avaliacoes where visitante = v.id and alvo_tipo = 'palestra' and alvo_id = p_agenda));
end $$;

create or replace function public.presenca_palestra(p_token text, p_agenda uuid, p_codigo text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante(p_token); a public.agenda%rowtype;
        v_j bigint := floor(extract(epoch from now()) / 60);
begin
  select * into a from public.agenda where id = p_agenda and excluido_em is null;
  if not found or a.ed <> v.ed then raise exception 'agenda_invalida' using errcode = 'P0001'; end if;
  if (select count(*) from public.presencas where visitante = v.id and quando > now() - interval '1 hour') >= 20 then
    raise exception 'limite' using errcode = 'P0001'; end if;
  if not public._palestra_aberta(a) then raise exception 'fora_do_horario' using errcode = 'P0001'; end if;
  if coalesce(p_codigo, '') not in (coalesce(public._codigo_palestra(p_agenda, v_j), '-'), coalesce(public._codigo_palestra(p_agenda, v_j - 1), '-')) then
    raise exception 'codigo_expirado' using errcode = 'P0001'; end if;
  insert into public.presencas (visitante, agenda_id) values (v.id, p_agenda) on conflict do nothing;
  return public.estado_palestra(p_token, p_agenda);
end $$;

-- avaliação da palestra: só quem esteve presente; comentário vai só para a organização
create or replace function public.avaliar_palestra(p_token text, p_agenda uuid, p_carinha text, p_texto text default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante(p_token);
begin
  if not exists (select 1 from public.presencas where visitante = v.id and agenda_id = p_agenda) then
    raise exception 'sem_presenca' using errcode = 'P0001'; end if;
  if p_carinha is not null then
    if p_carinha not in ('bom','neutro','ruim') then raise exception 'valor_invalido' using errcode = 'P0001'; end if;
    insert into public.avaliacoes (visitante, alvo_tipo, alvo_id, carinha) values (v.id, 'palestra', p_agenda, p_carinha)
    on conflict (visitante, alvo_tipo, alvo_id) do update set carinha = excluded.carinha, quando = now();
  end if;
  if nullif(trim(coalesce(p_texto, '')), '') is not null then
    if (select count(*) from public.comentarios where visitante = v.id and quando > now() - interval '1 hour') >= 20 then
      raise exception 'limite' using errcode = 'P0001'; end if;
    insert into public.comentarios (visitante, alvo_tipo, alvo_id, texto, publico, status)
    values (v.id, 'palestra', p_agenda, left(trim(p_texto), 400), false, 'privado');
  end if;
  return public.estado_palestra(p_token, p_agenda);
end $$;

-- organização: público e avaliação por palestra
create or replace function public.presencas_edicao(p_ed text)
returns table (agenda_id uuid, presentes bigint, bom bigint, neutro bigint, ruim bigint, comentarios bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.sou_equipe() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return query select a.id,
    (select count(*) from public.presencas p where p.agenda_id = a.id),
    (select count(*) from public.avaliacoes v where v.alvo_tipo = 'palestra' and v.alvo_id = a.id and v.carinha = 'bom'),
    (select count(*) from public.avaliacoes v where v.alvo_tipo = 'palestra' and v.alvo_id = a.id and v.carinha = 'neutro'),
    (select count(*) from public.avaliacoes v where v.alvo_tipo = 'palestra' and v.alvo_id = a.id and v.carinha = 'ruim'),
    (select count(*) from public.comentarios c where c.alvo_tipo = 'palestra' and c.alvo_id = a.id)
  from public.agenda a where a.ed = p_ed and a.excluido_em is null;
end $$;

create or replace function public.comentarios_palestra(p_agenda uuid)
returns table (texto text, quando timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.pode_editar_cadastros() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return query select c.texto, c.quando from public.comentarios c
   where c.alvo_tipo = 'palestra' and c.alvo_id = p_agenda order by c.quando desc limit 300;
end $$;

-- ---------- trilhas ----------
create or replace function public._etapas_validas(j jsonb)
returns boolean language sql immutable set search_path = '' as $$
  select jsonb_typeof(j) = 'array' and jsonb_array_length(j) between 1 and 10
     and not exists (select 1 from jsonb_array_elements(j) e
                      where jsonb_typeof(e) <> 'object' or (e->>'tipo') is null or (e->>'tipo') not in ('palestra','estande')
                         or coalesce(e->>'id', '') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                         or (select count(*) from jsonb_object_keys(e)) <> 2)
$$;

create table if not exists public.trilhas (
  id             uuid primary key default gen_random_uuid(),
  ed             text not null references public.edicoes(slug) on delete cascade,
  titulo         text not null check (char_length(titulo) between 1 and 120),
  descricao      text check (char_length(descricao) <= 1000),
  premio         text not null check (char_length(premio) between 1 and 200),
  doador_estande uuid references public.estandes(id) on delete set null,
  estoque        int not null default 0 check (estoque between 0 and 100000),
  prazo          timestamptz,
  regulamento    text check (char_length(regulamento) <= 3000),
  etapas         jsonb not null check (public._etapas_validas(etapas)),
  status         text not null default 'rascunho' check (status in ('rascunho','aprovada','encerrada')),
  excluido_em    timestamptz,
  criado_em      timestamptz not null default now()
);
alter table public.trilhas enable row level security;
revoke all on table public.trilhas from anon, authenticated, public;
grant select, insert, update, delete on table public.trilhas to authenticated;
drop policy if exists le on public.trilhas;
drop policy if exists insere on public.trilhas;
drop policy if exists altera on public.trilhas;
drop policy if exists apaga on public.trilhas;
create policy le on public.trilhas for select to authenticated using ((select public.sou_equipe()));
create policy insere on public.trilhas for insert to authenticated with check ((select public.pode_editar_cadastros()));
create policy altera on public.trilhas for update to authenticated using ((select public.pode_editar_cadastros())) with check ((select public.pode_editar_cadastros()));
create policy apaga on public.trilhas for delete to authenticated using ((select public.sou_admin_geral()));
drop trigger if exists auditar on public.trilhas;
create trigger auditar after insert or update or delete on public.trilhas for each row execute function public._auditar();

create table if not exists public.cupons (
  id            bigint generated always as identity primary key,
  trilha_id     uuid not null references public.trilhas(id) on delete cascade,
  visitante     uuid not null references public.visitantes(id) on delete cascade,
  codigo        text not null unique,
  criado_em     timestamptz not null default now(),
  resgatado_em  timestamptz,
  resgatado_por uuid,
  unique (trilha_id, visitante)
);
alter table public.cupons enable row level security;
revoke all on table public.cupons from anon, authenticated, public;
drop trigger if exists auditar on public.cupons;
create trigger auditar after update or delete on public.cupons for each row execute function public._auditar();

create or replace function public._etapa_feita(p_vis uuid, e jsonb)
returns boolean language sql stable security definer set search_path = '' as $$
  select case e->>'tipo'
    when 'palestra' then exists (select 1 from public.presencas where visitante = p_vis and agenda_id = (e->>'id')::uuid)
    when 'estande'  then exists (select 1 from public.checkins where visitante = p_vis and estande_id = (e->>'id')::uuid)
    else false end
$$;

create or replace function public._nome_etapa(e jsonb)
returns jsonb language sql stable security definer set search_path = '' as $$
  select case e->>'tipo'
    when 'palestra' then (select jsonb_build_object('nome', a.titulo, 'inicio', a.inicio, 'local', (select nome from public.locais where id = a.local_id))
                            from public.agenda a where a.id = (e->>'id')::uuid)
    when 'estande' then (select jsonb_build_object('nome', x.nome, 'lotes', (select jsonb_agg(l.numero order by length(l.numero), l.numero)
                            from public.estande_lotes el join public.lotes l on l.id = el.lote_id where el.estande_id = s.id))
                            from public.estandes s join public.expositores x on x.id = s.expositor_id where s.id = (e->>'id')::uuid)
    end
$$;

-- trilhas da edição do visitante, com progresso; emite o cupom de quem completou (ordem de chegada, até o estoque)
create or replace function public.trilhas_visitante(p_token text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante(p_token); t public.trilhas%rowtype; v_cod text; v_out jsonb := '[]';
        v_feitas int; v_total int; v_emitidos int;
begin
  for t in select * from public.trilhas where ed = v.ed and status = 'aprovada' and excluido_em is null order by criado_em loop
    select count(*) filter (where public._etapa_feita(v.id, e)), count(*) into v_feitas, v_total from jsonb_array_elements(t.etapas) e;
    if v_feitas = v_total and (t.prazo is null or t.prazo > now())
       and not exists (select 1 from public.cupons where trilha_id = t.id and visitante = v.id) then
      perform 1 from public.trilhas where id = t.id for update;              -- fila única por trilha: o estoque não estoura
      select count(*) into v_emitidos from public.cupons where trilha_id = t.id;
      if v_emitidos < t.estoque then
        loop
          v_cod := upper(encode(extensions.gen_random_bytes(4), 'hex'));
          begin
            insert into public.cupons (trilha_id, visitante, codigo) values (t.id, v.id, v_cod);
            exit;
          exception when unique_violation then
            if exists (select 1 from public.cupons where trilha_id = t.id and visitante = v.id) then exit; end if;
          end;
        end loop;
      end if;
    end if;
    v_out := v_out || jsonb_build_object('id', t.id, 'titulo', t.titulo, 'descricao', t.descricao, 'premio', t.premio,
      'regulamento', t.regulamento, 'prazo', t.prazo, 'feitas', v_feitas, 'total', v_total,
      'doador', (select jsonb_build_object('nome', x.nome, 'estande', s.id) from public.estandes s join public.expositores x on x.id = s.expositor_id where s.id = t.doador_estande),
      'esgotada', (select count(*) from public.cupons where trilha_id = t.id) >= t.estoque,
      'encerrada', t.prazo is not null and t.prazo <= now(),
      'etapas', (select jsonb_agg(e || coalesce(public._nome_etapa(e), '{}') || jsonb_build_object('feita', public._etapa_feita(v.id, e)) order by n)
                   from jsonb_array_elements(t.etapas) with ordinality as x(e, n)),
      'cupom', (select jsonb_build_object('codigo', c.codigo, 'resgatado', c.resgatado_em is not null) from public.cupons c where c.trilha_id = t.id and c.visitante = v.id));
  end loop;
  return v_out;
end $$;

-- baixa do cupom: o estande doador (conta do estande) ou a organização
create or replace function public.resgatar_cupom(p_codigo text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare c public.cupons%rowtype; t public.trilhas%rowtype;
begin
  if auth.uid() is null then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  if (select count(*) from public.auditoria where quem = auth.uid() and tabela = 'cupom_tentativa' and quando > now() - interval '10 minutes') >= 30 then
    raise exception 'limite' using errcode = 'P0001'; end if;
  insert into public.auditoria (quem, tabela, acao) values (auth.uid(), 'cupom_tentativa', 'tentativa');
  select * into c from public.cupons where codigo = upper(regexp_replace(coalesce(p_codigo, ''), '[^0-9A-Za-z]', '', 'g')) for update;
  -- código inválido devolve resposta (não erro), para a tentativa continuar registrada e contar no limite
  if not found then return jsonb_build_object('ok', false, 'motivo', 'cupom_invalido'); end if;
  select * into t from public.trilhas where id = c.trilha_id;
  if not (public.pode_editar_cadastros() or exists (
      select 1 from public.estandes s join public.expositor_equipe ee on ee.expositor_id = s.expositor_id
       where s.id = t.doador_estande and ee.user_id = auth.uid())) then
    return jsonb_build_object('ok', false, 'motivo', 'cupom_invalido'); end if;   -- não revela cupons de outros doadores
  if c.resgatado_em is not null then
    return jsonb_build_object('ok', false, 'motivo', 'ja_resgatado', 'resgatado_em', c.resgatado_em, 'premio', t.premio, 'trilha', t.titulo);
  end if;
  update public.cupons set resgatado_em = now(), resgatado_por = auth.uid() where id = c.id;
  return jsonb_build_object('ok', true, 'premio', t.premio, 'trilha', t.titulo);
end $$;

-- números da trilha: organização ou estande doador. Perfil de quem completou só com 5 ou mais.
create or replace function public.metricas_trilha(p_trilha uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare t public.trilhas%rowtype; v_comp int;
begin
  select * into t from public.trilhas where id = p_trilha;
  if not found then raise exception 'trilha_invalida' using errcode = 'P0001'; end if;
  if not (public.pode_editar_cadastros() or (t.doador_estande is not null and public._pode_ver_estande(t.doador_estande))) then
    raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  select count(*) into v_comp from public.cupons where trilha_id = t.id;
  return jsonb_build_object('id', t.id, 'titulo', t.titulo, 'premio', t.premio, 'estoque', t.estoque, 'status', t.status,
    'cupons', v_comp, 'resgatados', (select count(*) from public.cupons where trilha_id = t.id and resgatado_em is not null),
    'comecaram', (select count(*) from public.visitantes v where v.ed = t.ed
                   and exists (select 1 from jsonb_array_elements(t.etapas) e where public._etapa_feita(v.id, e))),
    'etapas', (select jsonb_agg(public._nome_etapa(e) || jsonb_build_object('tipo', e->>'tipo',
                 'n', (select count(*) from public.visitantes v where v.ed = t.ed and public._etapa_feita(v.id, e))) order by n)
               from jsonb_array_elements(t.etapas) with ordinality as x(e, n)),
    'perfil', case when v_comp >= 5 then (select jsonb_object_agg(k, q) from (select v.perfil->>'perfil' k, count(*) q
                 from public.cupons c join public.visitantes v on v.id = c.visitante where c.trilha_id = t.id group by 1) p) end);
end $$;

create or replace function public.trilhas_do_estande(p_estande uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public._pode_ver_estande(p_estande) then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return coalesce((select jsonb_agg(public.metricas_trilha(t.id) order by t.criado_em) from public.trilhas t
                    where t.doador_estande = p_estande and t.excluido_em is null and t.status <> 'rascunho'), '[]');
end $$;

-- ---------- permissões ----------
revoke all on function public._palestra_aberta(public.agenda)            from public, anon, authenticated;
revoke all on function public._codigo_palestra(uuid, bigint)             from public, anon, authenticated;
revoke all on function public._etapa_feita(uuid, jsonb)                  from public, anon, authenticated;
revoke all on function public._nome_etapa(jsonb)                         from public, anon, authenticated;
revoke all on function public._etapas_validas(jsonb)                     from public, anon, authenticated;
revoke all on function public.codigo_palestra(uuid)                      from public, anon, authenticated;
revoke all on function public.palestra_publica(uuid)                     from public, anon, authenticated;
revoke all on function public.estado_palestra(text, uuid)                from public, anon, authenticated;
revoke all on function public.presenca_palestra(text, uuid, text)        from public, anon, authenticated;
revoke all on function public.avaliar_palestra(text, uuid, text, text)   from public, anon, authenticated;
revoke all on function public.presencas_edicao(text)                     from public, anon, authenticated;
revoke all on function public.comentarios_palestra(uuid)                 from public, anon, authenticated;
revoke all on function public.trilhas_visitante(text)                    from public, anon, authenticated;
revoke all on function public.resgatar_cupom(text)                       from public, anon, authenticated;
revoke all on function public.metricas_trilha(uuid)                      from public, anon, authenticated;
revoke all on function public.trilhas_do_estande(uuid)                   from public, anon, authenticated;
grant execute on function public._etapas_validas(jsonb)                  to authenticated;   -- usada pela regra da tabela
grant execute on function public.codigo_palestra(uuid)                   to authenticated;
grant execute on function public.palestra_publica(uuid)                  to anon, authenticated;
grant execute on function public.estado_palestra(text, uuid)             to anon, authenticated;
grant execute on function public.presenca_palestra(text, uuid, text)     to anon, authenticated;
grant execute on function public.avaliar_palestra(text, uuid, text, text) to anon, authenticated;
grant execute on function public.presencas_edicao(text)                  to authenticated;
grant execute on function public.comentarios_palestra(uuid)              to authenticated;
grant execute on function public.trilhas_visitante(text)                 to anon, authenticated;
grant execute on function public.resgatar_cupom(text)                    to authenticated;
grant execute on function public.metricas_trilha(uuid)                   to authenticated;
grant execute on function public.trilhas_do_estande(uuid)                to authenticated;
