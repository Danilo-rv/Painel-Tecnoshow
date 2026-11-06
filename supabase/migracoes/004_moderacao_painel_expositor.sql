-- =====================================================================
-- Migração 004: moderação de comentários e painel do expositor
-- Rode depois da 003. Pode ser rodada de novo sem perder dados.
--
--   * Papel "moderador" na equipe da organização.
--   * Equipe do estande (gestor e atendente): contas convidadas por link para UM expositor.
--     Elas NÃO entram na tabela equipe, portanto não leem dados de outros estandes.
--   * Painel do expositor: só por função, com números agregados, avaliações do próprio estande
--     (inclusive as negativas, decisão 25) e os contatos que os visitantes pediram.
--   * Moderação: comentários públicos ficam pendentes até aprovação.
-- =====================================================================

-- ---------- papéis ----------
alter table public.equipe drop constraint if exists equipe_papel_ok;
alter table public.equipe add constraint equipe_papel_ok
  check (papel in ('admin_geral','coordenador','organizacao','moderador','equipe'));

create or replace function public.pode_moderar()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.equipe where user_id = auth.uid() and papel in ('admin_geral','coordenador','organizacao','moderador'))
$$;

-- ---------- equipe do estande ----------
create table if not exists public.expositor_equipe (
  user_id      uuid not null references auth.users(id) on delete cascade,
  expositor_id uuid not null references public.expositores(id) on delete cascade,
  papel        text not null default 'gestor' check (papel in ('gestor','atendente')),
  nome         text,
  criado_em    timestamptz not null default now(),
  primary key (user_id, expositor_id)
);
alter table public.expositor_equipe enable row level security;
revoke all on table public.expositor_equipe from anon, authenticated, public;
grant select on table public.expositor_equipe to authenticated;
drop policy if exists le on public.expositor_equipe;
create policy le on public.expositor_equipe for select to authenticated
  using (user_id = (select auth.uid()) or (select public.pode_editar_cadastros()));
drop trigger if exists auditar on public.expositor_equipe;
create trigger auditar after insert or update or delete on public.expositor_equipe for each row execute function public._auditar();

-- auditoria: registros sem coluna id (como expositor_equipe) passam a guardar o expositor
create or replace function public._auditar()
returns trigger language plpgsql security definer set search_path = '' as $$
declare j jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
begin
  insert into public.auditoria (quem, tabela, registro, acao, antes, depois)
  values (auth.uid(), tg_table_name, coalesce(j->>'id', j->>'estande_id', j->>'expositor_id'), lower(tg_op),
          case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,
          case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end);
  return coalesce(new, old);
end $$;

create or replace function public._pode_ver_estande(p_estande uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.pode_editar_cadastros() or exists (
    select 1 from public.estandes s join public.expositor_equipe ee on ee.expositor_id = s.expositor_id
     where s.id = p_estande and ee.user_id = auth.uid())
$$;

-- lojas da conta logada (para o login da área do expositor)
create or replace function public.minhas_lojas()
returns table (estande_id uuid, ed text, edicao text, expositor text, papel text)
language sql stable security definer set search_path = '' as $$
  select s.id, s.ed, e.nome, x.nome, ee.papel
    from public.expositor_equipe ee
    join public.expositores x on x.id = ee.expositor_id and x.excluido_em is null
    join public.estandes s on s.expositor_id = x.id and s.excluido_em is null
    join public.edicoes e on e.slug = s.ed
   where ee.user_id = auth.uid()
   order by e.ano desc nulls last, x.nome
$$;

-- ---------- convites: papel da equipe e convites de estande ----------
alter table public.convites add column if not exists papel text not null default 'equipe';
alter table public.convites drop constraint if exists convites_papel_ok;
alter table public.convites add constraint convites_papel_ok check (papel in ('equipe','moderador','organizacao','coordenador','gestor','atendente'));
alter table public.convites add column if not exists expositor_id uuid references public.expositores(id) on delete cascade;

drop function if exists public.criar_convite(int);
create or replace function public.criar_convite(p_dias int default 7, p_papel text default 'equipe')
returns text language plpgsql volatile security definer set search_path = '' as $$
declare v_tok text := replace(gen_random_uuid()::text, '-', '');
begin
  if not public.sou_coordenador() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  if coalesce(p_papel, '') not in ('equipe','moderador','organizacao','coordenador') then raise exception 'papel_invalido' using errcode = 'P0001'; end if;
  if p_papel = 'coordenador' and not public.sou_admin_geral() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  insert into public.convites (token_hash, criado_por, expira_em, papel)
  values (encode(sha256(convert_to(v_tok, 'UTF8')), 'hex'), auth.uid(),
          now() + make_interval(days => least(greatest(coalesce(p_dias, 7), 1), 30)), p_papel);
  return v_tok;
end $$;

create or replace function public.criar_convite_expositor(p_expositor uuid, p_papel text default 'gestor', p_dias int default 14)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare v_tok text := replace(gen_random_uuid()::text, '-', '');
begin
  if not public.pode_editar_cadastros() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  if coalesce(p_papel, '') not in ('gestor','atendente') then raise exception 'papel_invalido' using errcode = 'P0001'; end if;
  if not exists (select 1 from public.expositores where id = p_expositor and excluido_em is null) then
    raise exception 'expositor_invalido' using errcode = 'P0001'; end if;
  insert into public.convites (token_hash, criado_por, expira_em, papel, expositor_id)
  values (encode(sha256(convert_to(v_tok, 'UTF8')), 'hex'), auth.uid(),
          now() + make_interval(days => least(greatest(coalesce(p_dias, 14), 1), 60)), p_papel, p_expositor);
  return v_tok;
end $$;

-- devolve 'expositor' ou 'equipe', para o app saber para onde levar a pessoa
drop function if exists public.aceitar_convite(text);
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
  if c.expositor_id is not null then
    insert into public.expositor_equipe (user_id, expositor_id, papel, nome)
    values (auth.uid(), c.expositor_id, c.papel, v_nome) on conflict (user_id, expositor_id) do nothing;
  else
    insert into public.equipe (user_id, nome, papel) values (auth.uid(), v_nome, c.papel)
    on conflict (user_id) do nothing;
  end if;
  return case when c.expositor_id is not null then 'expositor' else 'equipe' end;
end $$;

-- contas com acesso ao painel de um expositor (para a organização revogar quando a pessoa sai da empresa)
create or replace function public.listar_contas_expositor(p_expositor uuid)
returns table (user_id uuid, nome text, email text, papel text, criado_em timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.pode_editar_cadastros() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return query select ee.user_id, ee.nome, u.email::text, ee.papel, ee.criado_em
    from public.expositor_equipe ee join auth.users u on u.id = ee.user_id
   where ee.expositor_id = p_expositor order by ee.criado_em;
end $$;

create or replace function public.remover_conta_expositor(p_user uuid, p_expositor uuid)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
begin
  if not public.pode_editar_cadastros() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  delete from public.expositor_equipe where user_id = p_user and expositor_id = p_expositor;
  return found;
end $$;

drop function if exists public.listar_convites();
create or replace function public.listar_convites()
returns table (id uuid, criado_em timestamptz, expira_em timestamptz, papel text, expositor text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.pode_editar_cadastros() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return query select c.id, c.criado_em, c.expira_em, c.papel, x.nome
    from public.convites c left join public.expositores x on x.id = c.expositor_id
    where c.usado_por is null and c.expira_em > now()
      and (public.sou_coordenador() or c.expositor_id is not null)
    order by c.criado_em desc;
end $$;

-- ---------- moderação ----------
drop trigger if exists auditar on public.comentarios;
create trigger auditar after update or delete on public.comentarios for each row execute function public._auditar();

create or replace function public.listar_moderacao(p_ed text, p_status text default 'pendente')
returns table (id bigint, texto text, alvo_tipo text, alvo text, quando timestamptz, status text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.pode_moderar() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return query
    select c.id, c.texto, c.alvo_tipo,
           coalesce(x.nome, xp.nome || ' · ' || p.nome, l.nome, a.titulo, '–'), c.quando, c.status
      from public.comentarios c
      join public.visitantes v on v.id = c.visitante and v.ed = p_ed
      left join public.estandes s on c.alvo_tipo = 'estande' and s.id = c.alvo_id
      left join public.expositores x on x.id = s.expositor_id
      left join public.produtos p on c.alvo_tipo = 'produto' and p.id = c.alvo_id
      left join public.expositores xp on xp.id = p.expositor_id
      left join public.locais l on c.alvo_tipo = 'local' and l.id = c.alvo_id
      left join public.agenda a on c.alvo_tipo = 'palestra' and a.id = c.alvo_id
     where c.publico and c.status = coalesce(p_status, 'pendente')
     order by c.quando
     limit 500;
end $$;

create or replace function public.moderar_comentario(p_id bigint, p_decisao text)
returns text language plpgsql volatile security definer set search_path = '' as $$
begin
  if not public.pode_moderar() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  if coalesce(p_decisao, '') not in ('aprovado','recusado') then raise exception 'decisao_invalida' using errcode = 'P0001'; end if;
  update public.comentarios set status = p_decisao where id = p_id and publico;
  if not found then raise exception 'comentario_invalido' using errcode = 'P0001'; end if;
  return p_decisao;
end $$;

-- ---------- painel do expositor ----------
-- Agregados do próprio estande. Perfil dos visitantes só aparece com 5 ou mais pessoas;
-- o benchmark do segmento só com 5 ou mais estandes da mesma categoria.
create or replace function public.painel_expositor(p_estande uuid)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare s public.estandes%rowtype; x public.expositores%rowtype; v_vis int; r jsonb; v_cont jsonb;
begin
  if not public._pode_ver_estande(p_estande) then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  select * into s from public.estandes where id = p_estande and excluido_em is null;
  if not found then raise exception 'estande_invalido' using errcode = 'P0001'; end if;
  select * into x from public.expositores where id = s.expositor_id;
  select count(distinct visitante) into v_vis from public.checkins where estande_id = p_estande;

  -- contatos pedidos pelos visitantes (WhatsApp decifrado só aqui, e a leitura fica na auditoria)
  select coalesce(jsonb_agg(jsonb_build_object(
           'quando', ct.quando,
           'whatsapp', extensions.pgp_sym_decrypt(v.whatsapp_cifrado, public._segredo('chave_whatsapp')),
           'perfil', v.perfil->>'perfil', 'culturas', v.perfil->'culturas',
           'mun', (v.perfil->>'mun')::int, 'pais', v.perfil->>'pais', 'lang', v.lang) order by ct.quando desc), '[]')
    into v_cont
    from public.contatos ct join public.visitantes v on v.id = ct.visitante
   where ct.estande_id = p_estande;
  if jsonb_array_length(v_cont) > 0 then
    insert into public.auditoria (quem, tabela, registro, acao)
    values (auth.uid(), 'contatos', p_estande::text, 'leitura');
  end if;

  r := jsonb_build_object(
    'estande', jsonb_build_object('id', s.id, 'ed', s.ed, 'expositor', x.nome,
       'lotes', coalesce((select jsonb_agg(l.numero order by length(l.numero), l.numero) from public.estande_lotes el
                           join public.lotes l on l.id = el.lote_id where el.estande_id = s.id), '[]')),
    'totais', jsonb_build_object(
       'visitantes', v_vis,
       'checkins', (select count(*) from public.checkins where estande_id = p_estande),
       'curti', (select count(*) from public.reacoes where estande_id = p_estande and produto_id is null and tipo = 'curti'),
       'amei', (select count(*) from public.reacoes where estande_id = p_estande and produto_id is null and tipo = 'amei'),
       'seguidores', (select count(*) from public.seguidores where estande_id = p_estande),
       'salvos', (select count(*) from public.salvos sv join public.produtos p on p.id = sv.produto_id where p.expositor_id = x.id),
       'contatos', jsonb_array_length(v_cont)),
    'satisfacao', (select jsonb_build_object(
         'bom', count(*) filter (where carinha = 'bom'), 'neutro', count(*) filter (where carinha = 'neutro'),
         'ruim', count(*) filter (where carinha = 'ruim'), 'total', count(*),
         'motivos', coalesce((select jsonb_object_agg(motivo, n) from (select motivo, count(*) n from public.avaliacoes
                     where alvo_tipo = 'estande' and alvo_id = p_estande and carinha = 'ruim' and motivo is not null group by motivo) m), '{}'))
       from public.avaliacoes where alvo_tipo = 'estande' and alvo_id = p_estande),
    'por_hora', coalesce((select jsonb_agg(jsonb_build_object('hora', h, 'n', n) order by h) from (
         select date_trunc('hour', quando) h, count(distinct visitante) n from public.checkins
          where estande_id = p_estande group by 1 order by 1 desc limit 48) t), '[]'),
    'produtos', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'nome', p.nome,
         'curti', (select count(*) from public.reacoes rr where rr.produto_id = p.id and rr.tipo = 'curti'),
         'amei', (select count(*) from public.reacoes rr where rr.produto_id = p.id and rr.tipo = 'amei'),
         'salvos', (select count(*) from public.salvos sv where sv.produto_id = p.id)) order by p.ordem, p.nome)
       from public.produtos p where p.expositor_id = x.id and p.excluido_em is null), '[]'),
    'perfil', case when v_vis >= 5 then (
       select jsonb_build_object(
         'perfil', (select jsonb_object_agg(k, n) from (select v.perfil->>'perfil' k, count(*) n from public.visitantes v
                     where v.id in (select visitante from public.checkins where estande_id = p_estande) group by 1) a),
         'culturas', (select jsonb_object_agg(k, n) from (select c k, count(*) n from public.visitantes v,
                     jsonb_array_elements_text(coalesce(v.perfil->'culturas', '[]')) c
                     where v.id in (select visitante from public.checkins where estande_id = p_estande) group by 1) b),
         'origem', (select jsonb_agg(jsonb_build_object('mun', mun, 'pais', pais, 'n', n) order by n desc) from (
                     select (v.perfil->>'mun')::int mun, v.perfil->>'pais' pais, count(*) n from public.visitantes v
                      where v.id in (select visitante from public.checkins where estande_id = p_estande)
                      group by 1, 2 having count(*) >= 1 order by 3 desc limit 10) c))) end,
    'comentarios', coalesce((select jsonb_agg(jsonb_build_object('texto', c.texto, 'publico', c.publico, 'status', c.status, 'quando', c.quando,
         'produto', p.nome) order by c.quando desc)
       from (select * from public.comentarios where (alvo_tipo = 'estande' and alvo_id = p_estande)
               or (alvo_tipo = 'produto' and alvo_id in (select id from public.produtos where expositor_id = x.id))
             order by quando desc limit 200) c
       left join public.produtos p on c.alvo_tipo = 'produto' and p.id = c.alvo_id), '[]'),
    'contatos', v_cont,
    'benchmark', (select case when count(*) >= 5 then jsonb_build_object('estandes', count(*), 'media_visitantes', round(avg(nv), 1)) end
       from (select s2.id, (select count(distinct visitante) from public.checkins where estande_id = s2.id) nv
               from public.estandes s2 join public.expositores x2 on x2.id = s2.expositor_id
              where s2.ed = s.ed and s2.excluido_em is null and x.categoria_id is not null and x2.categoria_id = x.categoria_id) seg));
  return r;
end $$;

-- ---------- permissões ----------
revoke all on function public.pode_moderar()                               from public, anon, authenticated;
revoke all on function public._pode_ver_estande(uuid)                      from public, anon, authenticated;
revoke all on function public.minhas_lojas()                               from public, anon, authenticated;
revoke all on function public.criar_convite(int, text)                     from public, anon, authenticated;
revoke all on function public.criar_convite_expositor(uuid, text, int)     from public, anon, authenticated;
revoke all on function public.aceitar_convite(text)                        from public, anon, authenticated;
revoke all on function public.listar_convites()                            from public, anon, authenticated;
revoke all on function public.listar_contas_expositor(uuid)               from public, anon, authenticated;
revoke all on function public.remover_conta_expositor(uuid, uuid)          from public, anon, authenticated;
revoke all on function public.listar_moderacao(text, text)                 from public, anon, authenticated;
revoke all on function public.moderar_comentario(bigint, text)             from public, anon, authenticated;
revoke all on function public.painel_expositor(uuid)                       from public, anon, authenticated;
grant execute on function public.pode_moderar()                            to authenticated;
grant execute on function public.minhas_lojas()                            to authenticated;
grant execute on function public.criar_convite(int, text)                  to authenticated;
grant execute on function public.criar_convite_expositor(uuid, text, int)  to authenticated;
grant execute on function public.aceitar_convite(text)                     to authenticated;
grant execute on function public.listar_convites()                         to authenticated;
grant execute on function public.listar_contas_expositor(uuid)            to authenticated;
grant execute on function public.remover_conta_expositor(uuid, uuid)       to authenticated;
grant execute on function public.listar_moderacao(text, text)              to authenticated;
grant execute on function public.moderar_comentario(bigint, text)          to authenticated;
grant execute on function public.painel_expositor(uuid)                    to authenticated;
