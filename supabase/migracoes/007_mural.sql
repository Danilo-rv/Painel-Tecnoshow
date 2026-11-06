-- =====================================================================
-- Migração 007: telão social (mural de fotos e mensagens sobre o mapa da feira)
-- Rode depois da 006. Pode ser rodada de novo sem perder dados.
--
-- O visitante publica uma mensagem curta (até 140 caracteres) e, se quiser, uma foto,
-- a partir da página de um estande ou de uma palestra. Tudo passa por moderação
-- (decisão 4) antes de aparecer no telão. Menores de 18 anos não publicam.
-- A foto chega já reduzida pelo celular (sem os dados EXIF, inclusive o GPS) e fica no banco,
-- sem endereço público: só a moderação e o telão (contas da equipe) a leem.
-- =====================================================================

create table if not exists public.publicacoes (
  id           bigint generated always as identity primary key,
  ed           text not null references public.edicoes(slug) on delete cascade,
  visitante    uuid not null references public.visitantes(id) on delete cascade,
  alvo_tipo    text not null check (alvo_tipo in ('estande','palestra')),
  alvo_id      uuid not null,
  texto        text check (char_length(texto) <= 140),
  foto         bytea check (octet_length(foto) <= 350000),
  foto_tipo    text check (foto_tipo in ('image/jpeg','image/webp')),
  status       text not null default 'pendente' check (status in ('pendente','aprovado','recusado')),
  quando       timestamptz not null default now(),
  moderado_por uuid,
  moderado_em  timestamptz,
  check (texto is not null or foto is not null),
  check ((foto is null) = (foto_tipo is null))
);
create index if not exists publicacoes_ed on public.publicacoes (ed, status, id);
alter table public.publicacoes enable row level security;
revoke all on table public.publicacoes from anon, authenticated, public;
drop trigger if exists auditar on public.publicacoes;
-- a auditoria guarda a decisão, não a foto
create or replace function public._auditar_publicacao()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.auditoria (quem, tabela, registro, acao, antes, depois)
  values (auth.uid(), 'publicacoes', coalesce(new.id, old.id)::text, lower(tg_op),
          case when tg_op <> 'INSERT' then jsonb_build_object('status', old.status) end,
          case when tg_op <> 'DELETE' then jsonb_build_object('status', new.status) end);
  return coalesce(new, old);
end $$;
create trigger auditar after update or delete on public.publicacoes for each row execute function public._auditar_publicacao();

-- posição no mapa (0..1): centro do primeiro lote do estande, ou ponto/lote do local da palestra
create or replace function public._centro(p jsonb)
returns jsonb language sql immutable set search_path = '' as $$
  select case when p is null then null else jsonb_build_object(
    'x', round((select avg((e->>0)::numeric) from jsonb_array_elements(p) e), 4),
    'y', round((select avg((e->>1)::numeric) from jsonb_array_elements(p) e), 4)) end
$$;
create or replace function public._posicao(p_tipo text, p_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select case p_tipo
    when 'estande' then (select public._centro(l.poligono) from public.estande_lotes el join public.lotes l on l.id = el.lote_id
                          where el.estande_id = p_id and l.poligono is not null order by length(l.numero), l.numero limit 1)
    when 'palestra' then (select coalesce(o.ponto, (select public._centro(l.poligono) from public.lotes l where l.id = o.lote_id))
                           from public.agenda a join public.locais o on o.id = a.local_id where a.id = p_id)
  end
$$;
create or replace function public._nome_alvo(p_tipo text, p_id uuid)
returns text language sql stable security definer set search_path = '' as $$
  select case p_tipo
    when 'estande' then (select x.nome from public.estandes s join public.expositores x on x.id = s.expositor_id where s.id = p_id)
    when 'palestra' then (select a.titulo from public.agenda a where a.id = p_id) end
$$;

-- ---------- visitante publica ----------
create or replace function public.publicar_mural(p_token text, p_alvo_tipo text, p_alvo_id uuid, p_texto text, p_foto text default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante(p_token); b bytea; t text; tx text := nullif(trim(coalesce(p_texto, '')), '');
begin
  if v.menor then raise exception 'menor' using errcode = 'P0001'; end if;
  if p_alvo_tipo = 'estande' then
    if not exists (select 1 from public.estandes where id = p_alvo_id and ed = v.ed and excluido_em is null) then raise exception 'alvo_invalido' using errcode = 'P0001'; end if;
  elsif p_alvo_tipo = 'palestra' then
    if not exists (select 1 from public.agenda where id = p_alvo_id and ed = v.ed and excluido_em is null) then raise exception 'alvo_invalido' using errcode = 'P0001'; end if;
  else raise exception 'alvo_invalido' using errcode = 'P0001'; end if;
  if char_length(tx) > 140 then raise exception 'texto_longo' using errcode = 'P0001'; end if;
  if (select count(*) from public.publicacoes where visitante = v.id and quando > now() - interval '1 hour') >= 5 then
    raise exception 'limite' using errcode = 'P0001'; end if;
  if p_foto is not null then
    begin b := decode(p_foto, 'base64'); exception when others then raise exception 'foto_invalida' using errcode = 'P0001'; end;
    if octet_length(b) > 350000 then raise exception 'foto_grande' using errcode = 'P0001'; end if;
    if substring(b from 1 for 3) = '\xffd8ff'::bytea then t := 'image/jpeg';
    elsif substring(b from 1 for 4) = '\x52494646'::bytea and substring(b from 9 for 4) = '\x57454250'::bytea then t := 'image/webp';
    else raise exception 'foto_invalida' using errcode = 'P0001'; end if;
  end if;
  if tx is null and b is null then raise exception 'vazio' using errcode = 'P0001'; end if;
  insert into public.publicacoes (ed, visitante, alvo_tipo, alvo_id, texto, foto, foto_tipo) values (v.ed, v.id, p_alvo_tipo, p_alvo_id, tx, b, t);
  return jsonb_build_object('ok', true, 'status', 'pendente');
end $$;

-- ---------- moderação ----------
create or replace function public.listar_mural(p_ed text, p_status text default 'pendente')
returns table (id bigint, texto text, tem_foto boolean, alvo_tipo text, alvo text, quando timestamptz, status text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.pode_moderar() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return query select p.id, p.texto, p.foto is not null, p.alvo_tipo, public._nome_alvo(p.alvo_tipo, p.alvo_id), p.quando, p.status
    from public.publicacoes p where p.ed = p_ed and p.status = coalesce(p_status, 'pendente') order by p.id limit 300;
end $$;

create or replace function public.moderar_mural(p_id bigint, p_decisao text)
returns text language plpgsql volatile security definer set search_path = '' as $$
begin
  if not public.pode_moderar() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  if coalesce(p_decisao, '') not in ('aprovado','recusado') then raise exception 'decisao_invalida' using errcode = 'P0001'; end if;
  update public.publicacoes set status = p_decisao, moderado_por = auth.uid(), moderado_em = now() where id = p_id;
  if not found then raise exception 'publicacao_invalida' using errcode = 'P0001'; end if;
  return p_decisao;
end $$;

-- foto: moderação vê todas; o restante da equipe (telão) só as aprovadas
create or replace function public.foto_mural(p_id bigint)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p public.publicacoes%rowtype;
begin
  select * into p from public.publicacoes where id = p_id;
  if not found or p.foto is null then return null; end if;
  if not (public.pode_moderar() or (public.sou_equipe() and p.status = 'aprovado')) then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return jsonb_build_object('tipo', p.foto_tipo, 'dados', encode(p.foto, 'base64'));
end $$;

-- ---------- telão ----------
create or replace function public.mural_telao(p_ed text, p_depois bigint default 0)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.sou_equipe() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return jsonb_build_object(
    'publicacoes', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'texto', p.texto, 'tem_foto', p.foto is not null,
        'alvo_tipo', p.alvo_tipo, 'alvo', public._nome_alvo(p.alvo_tipo, p.alvo_id), 'pos', public._posicao(p.alvo_tipo, p.alvo_id),
        'quando', p.quando) order by p.id)
      from (select * from public.publicacoes where ed = p_ed and status = 'aprovado' and id > coalesce(p_depois, 0) order by id desc limit 60) p), '[]'),
    -- "em alta agora": estandes com mais pessoas diferentes nos últimos 30 minutos (só contagens)
    'em_alta', coalesce((select jsonb_agg(jsonb_build_object('estande', s.id, 'nome', x.nome, 'n', t.n, 'pos', public._posicao('estande', s.id)) order by t.n desc)
      from (select estande_id, count(distinct visitante) n from public.checkins c join public.estandes s2 on s2.id = c.estande_id
             where s2.ed = p_ed and c.quando > now() - interval '30 minutes' group by 1 having count(distinct visitante) >= 3 order by 2 desc limit 5) t
      join public.estandes s on s.id = t.estande_id join public.expositores x on x.id = s.expositor_id), '[]'),
    'planta', (select jsonb_build_object('url', imagem_url, 'largura', largura, 'altura', altura) from public.plantas
                where ed = p_ed and ativa and excluido_em is null order by criado_em desc limit 1),
    'lotes', coalesce((select jsonb_agg(poligono) from public.lotes where ed = p_ed and excluido_em is null and poligono is not null), '[]'));
end $$;

-- ---------- permissões ----------
revoke all on function public._auditar_publicacao()                                  from public, anon, authenticated;
revoke all on function public._centro(jsonb)                                         from public, anon, authenticated;
revoke all on function public._posicao(text, uuid)                                   from public, anon, authenticated;
revoke all on function public._nome_alvo(text, uuid)                                 from public, anon, authenticated;
revoke all on function public.publicar_mural(text, text, uuid, text, text)           from public, anon, authenticated;
revoke all on function public.listar_mural(text, text)                               from public, anon, authenticated;
revoke all on function public.moderar_mural(bigint, text)                            from public, anon, authenticated;
revoke all on function public.foto_mural(bigint)                                     from public, anon, authenticated;
revoke all on function public.mural_telao(text, bigint)                              from public, anon, authenticated;
grant execute on function public.publicar_mural(text, text, uuid, text, text)        to anon, authenticated;
grant execute on function public.listar_mural(text, text)                            to authenticated;
grant execute on function public.moderar_mural(bigint, text)                         to authenticated;
grant execute on function public.foto_mural(bigint)                                  to authenticated;
grant execute on function public.mural_telao(text, bigint)                           to authenticated;
