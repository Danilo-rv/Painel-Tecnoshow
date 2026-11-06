-- =====================================================================
-- Migração 012: envio assistido da avaliação pelo WhatsApp, com link pessoal
-- Rode depois da 011. Pode ser rodada de novo sem perder dados.
--
-- Sem a plataforma paga do WhatsApp: a equipe envia pelo próprio WhatsApp, e o app prepara tudo.
--   * Fila: visitantes cadastrados há 3 horas ou mais (configurável), adultos, que ainda não avaliaram,
--     não disseram que responderam no tablet e ainda não receberam o link. Um por número de WhatsApp.
--   * Ao preparar o envio, o banco gera um código pessoal (vale 7 dias; guarda só o hash) e decifra
--     o WhatsApp daquela pessoa; a consulta fica na auditoria. A lista em si não mostra números.
--   * O link #avaliar-<código> funciona em qualquer navegador (não depende do cadastro no aparelho).
--   * O bot começa perguntando se a pessoa já respondeu no tablet; quem disser sim sai da fila.
-- =====================================================================

create table if not exists public.avaliacao_convites (
  visitante   uuid primary key references public.visitantes(id) on delete cascade,
  codigo_hash text unique check (codigo_hash ~ '^[0-9a-f]{64}$'),
  expira_em   timestamptz,
  enviado_em  timestamptz,
  enviado_por uuid,
  usado_em    timestamptz,
  respondeu_tablet_em timestamptz
);
alter table public.avaliacao_convites enable row level security;
revoke all on table public.avaliacao_convites from anon, authenticated, public;

create or replace function public._registrar_avaliacao(v public.visitantes, p_resp jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare e public.edicoes%rowtype; r jsonb; pf jsonb; v_def jsonb; k text;
begin
  select * into e from public.edicoes where slug = v.ed;
  if not found or not e.aberta then raise exception 'edicao_fechada' using errcode = 'P0001'; end if;
  if exists (select 1 from public.respostas where id = 'web-' || v.id::text) then raise exception 'ja_respondeu' using errcode = 'P0001'; end if;
  if coalesce(jsonb_typeof(p_resp), '') <> 'object' then raise exception 'resposta_invalida' using errcode = 'P0001'; end if;
  -- o que vem do perfil prevalece sobre o que o celular mandou
  pf := v.perfil;
  r := p_resp - array['id','t','tab','ed','br','mun','pais','perfil','idade'];
  for k in select unnest(array['prim','dias','pern']) loop
    if pf ? k then r := r - k; end if;
  end loop;
  r := r || jsonb_strip_nulls(jsonb_build_object(
         'id', 'web-' || v.id::text, 't', floor(extract(epoch from now()) * 1000)::bigint, 'tab', 'WEB', 'ed', v.ed,
         'br', coalesce((pf->>'br')::int, 1), 'mun', (pf->>'mun')::int, 'pais', case when coalesce((pf->>'br')::int, 1) = 1 then 'BR' else pf->>'pais' end,
         'perfil', pf->>'perfil', 'idade', pf->>'idade', 'prim', pf->>'prim', 'dias', pf->>'dias', 'pern', pf->>'pern'));
  if not public._resposta_valida(r) then raise exception 'resposta_invalida' using errcode = 'P0001'; end if;
  if coalesce((r->>'v')::int, 0) > 0 then
    select i.def into v_def from public.instrumentos i where i.ed = v.ed and i.versao = (r->>'v')::int;
    if not found then raise exception 'resposta_invalida' using errcode = 'P0001'; end if;
  end if;
  if not public._conforme_instrumento(v_def, r) then raise exception 'resposta_invalida' using errcode = 'P0001'; end if;
  insert into public.respostas (id, ed, tab, t, dados) values (r->>'id', v.ed, 'WEB', now(), r);
  update public.avaliacao_convites set usado_em = now() where visitante = v.id;
  return jsonb_build_object('ok', true, 'mun', r->'mun', 'pais', r->'pais');
end $$;

create or replace function public.responder_avaliacao(p_token text, p_resp jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
begin
  return public._registrar_avaliacao(public._visitante(p_token), p_resp);
end $$;

-- visitante pelo código do link
create or replace function public._visitante_por_codigo(p_codigo text)
returns public.visitantes language plpgsql stable security definer set search_path = '' as $$
declare v public.visitantes%rowtype;
begin
  select x.* into v from public.avaliacao_convites c join public.visitantes x on x.id = c.visitante
   where c.codigo_hash = encode(sha256(convert_to(coalesce(p_codigo, ''), 'UTF8')), 'hex') and c.expira_em > now();
  if not found then raise exception 'link_invalido' using errcode = 'P0001'; end if;
  return v;
end $$;

create or replace function public.avaliacao_estado_codigo(p_codigo text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante_por_codigo(p_codigo);
begin
  return jsonb_build_object('ed', v.ed, 'lang', v.lang, 'perfil', v.perfil - 'culturas',
    'respondeu', exists (select 1 from public.respostas where id = 'web-' || v.id::text),
    'tablet', (select respondeu_tablet_em is not null from public.avaliacao_convites where visitante = v.id));
end $$;

create or replace function public.responder_avaliacao_codigo(p_codigo text, p_resp jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
begin
  return public._registrar_avaliacao(public._visitante_por_codigo(p_codigo), p_resp);
end $$;

-- "já respondi no tablet": sai da fila e não conta em dobro
create or replace function public.respondi_no_tablet(p_token text default null, p_codigo text default null)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
declare v public.visitantes%rowtype;
begin
  if p_codigo is not null then v := public._visitante_por_codigo(p_codigo); else v := public._visitante(p_token); end if;
  insert into public.avaliacao_convites (visitante, respondeu_tablet_em) values (v.id, now())
  on conflict (visitante) do update set respondeu_tablet_em = coalesce(public.avaliacao_convites.respondeu_tablet_em, now());
  return true;
end $$;

-- ---------- equipe: fila e preparo do envio ----------
create or replace function public.fila_avaliacao(p_ed text, p_horas int default 3, p_situacao text default 'pendente')
returns table (visitante uuid, cadastro timestamptz, lang text, perfil text, mun int, pais text, enviado_em timestamptz, situacao text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.sou_equipe() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return query
  with ult as (   -- um por número de WhatsApp: o cadastro mais recente
    select distinct on (v.whatsapp_hash) v.* from public.visitantes v where v.ed = p_ed and not v.menor order by v.whatsapp_hash, v.criado_em desc),
  st as (
    select u.id, u.criado_em, u.lang, u.perfil, c.enviado_em,
           case when exists (select 1 from public.respostas r where r.id = 'web-' || u.id::text) then 'respondida'
                when c.respondeu_tablet_em is not null then 'tablet'
                when c.enviado_em is not null then 'enviada'
                when u.criado_em <= now() - make_interval(hours => least(greatest(coalesce(p_horas, 3), 0), 72)) then 'pendente'
                else 'aguardando' end s
      from ult u left join public.avaliacao_convites c on c.visitante = u.id)
  select st.id, st.criado_em, st.lang, st.perfil->>'perfil', (st.perfil->>'mun')::int, st.perfil->>'pais', st.enviado_em, st.s
    from st where st.s = coalesce(p_situacao, 'pendente') order by st.criado_em limit 300;
end $$;

create or replace function public.resumo_fila_avaliacao(p_ed text, p_horas int default 3)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.sou_equipe() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return (select coalesce(jsonb_object_agg(situacao, n), '{}') from (
    select f.situacao, count(*) n from public.fila_avaliacao(p_ed, p_horas, 'pendente') f group by 1
    union all select f.situacao, count(*) from public.fila_avaliacao(p_ed, p_horas, 'aguardando') f group by 1
    union all select f.situacao, count(*) from public.fila_avaliacao(p_ed, p_horas, 'enviada') f group by 1
    union all select f.situacao, count(*) from public.fila_avaliacao(p_ed, p_horas, 'respondida') f group by 1
    union all select f.situacao, count(*) from public.fila_avaliacao(p_ed, p_horas, 'tablet') f group by 1) x);
end $$;

-- gera o link pessoal e devolve o WhatsApp daquela pessoa (fica na auditoria)
create or replace function public.preparar_envio_avaliacao(p_visitante uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v public.visitantes%rowtype; v_cod text := encode(extensions.gen_random_bytes(16), 'hex');
begin
  if not public.sou_equipe() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  select * into v from public.visitantes where id = p_visitante;
  if not found or v.menor then raise exception 'visitante_invalido' using errcode = 'P0001'; end if;
  if exists (select 1 from public.respostas where id = 'web-' || v.id::text) then raise exception 'ja_respondeu' using errcode = 'P0001'; end if;
  insert into public.avaliacao_convites (visitante, codigo_hash, expira_em, enviado_em, enviado_por)
  values (v.id, encode(sha256(convert_to(v_cod, 'UTF8')), 'hex'), now() + interval '7 days', now(), auth.uid())
  on conflict (visitante) do update set codigo_hash = excluded.codigo_hash, expira_em = excluded.expira_em,
    enviado_em = excluded.enviado_em, enviado_por = excluded.enviado_por;
  insert into public.auditoria (quem, tabela, registro, acao) values (auth.uid(), 'avaliacao_convites', v.id::text, 'envio_whatsapp');
  return jsonb_build_object('codigo', v_cod, 'lang', v.lang,
    'whatsapp', extensions.pgp_sym_decrypt(v.whatsapp_cifrado, public._segredo('chave_whatsapp')));
end $$;

revoke all on function public._registrar_avaliacao(public.visitantes, jsonb)   from public, anon, authenticated;
revoke all on function public.responder_avaliacao(text, jsonb)                  from public, anon, authenticated;
revoke all on function public._visitante_por_codigo(text)                       from public, anon, authenticated;
revoke all on function public.avaliacao_estado_codigo(text)                     from public, anon, authenticated;
revoke all on function public.responder_avaliacao_codigo(text, jsonb)           from public, anon, authenticated;
revoke all on function public.respondi_no_tablet(text, text)                    from public, anon, authenticated;
revoke all on function public.fila_avaliacao(text, int, text)                   from public, anon, authenticated;
revoke all on function public.resumo_fila_avaliacao(text, int)                  from public, anon, authenticated;
revoke all on function public.preparar_envio_avaliacao(uuid)                    from public, anon, authenticated;
grant execute on function public.responder_avaliacao(text, jsonb)               to anon, authenticated;
grant execute on function public.avaliacao_estado_codigo(text)                  to anon, authenticated;
grant execute on function public.responder_avaliacao_codigo(text, jsonb)        to anon, authenticated;
grant execute on function public.respondi_no_tablet(text, text)                 to anon, authenticated;
grant execute on function public.fila_avaliacao(text, int, text)                to authenticated;
grant execute on function public.resumo_fila_avaliacao(text, int)               to authenticated;
grant execute on function public.preparar_envio_avaliacao(uuid)                 to authenticated;
