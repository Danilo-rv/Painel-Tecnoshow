-- =====================================================================
-- Migração 009: Passaporte da Cidade e recursos ao vivo
-- Rode depois da 008. Pode ser rodada de novo sem perder dados.
--
-- Passaporte da Cidade (seção 10.3): trilhas com etapas em estabelecimentos parceiros
--   da cidade, e prêmio doado por um parceiro da cidade, que dá baixa no cupom.
-- Perguntas ao vivo nas palestras (seção 18-C): quem está presente pergunta; a equipe
--   media; as perguntas aprovadas ficam visíveis, recebem votos e aparecem no telão.
-- Assuntos em alta: palavras mais frequentes no conteúdo público aprovado (3 horas).
-- Acontecendo agora: palestras agora e a seguir, estandes em alta, assuntos e trilhas.
-- =====================================================================

-- ---------- Passaporte da Cidade ----------
alter table public.trilhas add column if not exists doador_estab uuid references public.estabelecimentos(id) on delete set null;

create or replace function public._etapas_validas(j jsonb)
returns boolean language sql immutable set search_path = '' as $$
  select jsonb_typeof(j) = 'array' and jsonb_array_length(j) between 1 and 10
     and not exists (select 1 from jsonb_array_elements(j) e
                      where jsonb_typeof(e) <> 'object' or (e->>'tipo') is null or (e->>'tipo') not in ('palestra','estande','cidade')
                         or coalesce(e->>'id', '') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                         or (select count(*) from jsonb_object_keys(e)) <> 2)
$$;

create or replace function public._etapa_feita(p_vis uuid, e jsonb)
returns boolean language sql stable security definer set search_path = '' as $$
  select case e->>'tipo'
    when 'palestra' then exists (select 1 from public.presencas where visitante = p_vis and agenda_id = (e->>'id')::uuid)
    when 'estande'  then exists (select 1 from public.checkins where visitante = p_vis and estande_id = (e->>'id')::uuid)
    when 'cidade'   then exists (select 1 from public.cidade_checkins where visitante = p_vis and estab_id = (e->>'id')::uuid)
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
    when 'cidade' then (select jsonb_build_object('nome', c.nome, 'municipio', c.municipio, 'tipo_estab', c.tipo)
                          from public.estabelecimentos c where c.id = (e->>'id')::uuid)
    end
$$;

-- trilhas do visitante (com etapas da cidade e doador da cidade)
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
      'doador', coalesce((select jsonb_build_object('nome', x.nome, 'estande', s.id) from public.estandes s join public.expositores x on x.id = s.expositor_id where s.id = t.doador_estande),
                         (select jsonb_build_object('nome', c.nome, 'estab', c.id) from public.estabelecimentos c where c.id = t.doador_estab)),
      'esgotada', (select count(*) from public.cupons where trilha_id = t.id) >= t.estoque,
      'encerrada', t.prazo is not null and t.prazo <= now(),
      'etapas', (select jsonb_agg(e || coalesce(public._nome_etapa(e), '{}') || jsonb_build_object('feita', public._etapa_feita(v.id, e)) order by n)
                   from jsonb_array_elements(t.etapas) with ordinality as x(e, n)),
      'cupom', (select jsonb_build_object('codigo', c.codigo, 'resgatado', c.resgatado_em is not null) from public.cupons c where c.trilha_id = t.id and c.visitante = v.id));
  end loop;
  return v_out;
end $$;

-- baixa do cupom: estande doador, parceiro da cidade doador ou organização
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
       where s.id = t.doador_estande and ee.user_id = auth.uid())
      or exists (select 1 from public.estab_equipe q where q.estab_id = t.doador_estab and q.user_id = auth.uid())) then
    return jsonb_build_object('ok', false, 'motivo', 'cupom_invalido'); end if;   -- não revela cupons de outros doadores
  if c.resgatado_em is not null then
    return jsonb_build_object('ok', false, 'motivo', 'ja_resgatado', 'resgatado_em', c.resgatado_em, 'premio', t.premio, 'trilha', t.titulo);
  end if;
  update public.cupons set resgatado_em = now(), resgatado_por = auth.uid() where id = c.id;
  return jsonb_build_object('ok', true, 'premio', t.premio, 'trilha', t.titulo);
end $$;

create or replace function public.metricas_trilha(p_trilha uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare t public.trilhas%rowtype; v_comp int;
begin
  select * into t from public.trilhas where id = p_trilha;
  if not found then raise exception 'trilha_invalida' using errcode = 'P0001'; end if;
  if not (public.pode_editar_cadastros() or (t.doador_estande is not null and public._pode_ver_estande(t.doador_estande))
          or (t.doador_estab is not null and public._pode_ver_estab(t.doador_estab))) then
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

create or replace function public.trilhas_do_estab(p_estab uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public._pode_ver_estab(p_estab) then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return coalesce((select jsonb_agg(public.metricas_trilha(t.id) order by t.criado_em) from public.trilhas t
                    where t.doador_estab = p_estab and t.excluido_em is null and t.status <> 'rascunho'), '[]');
end $$;

-- ---------- perguntas ao vivo nas palestras ----------
create table if not exists public.perguntas (
  id         bigint generated always as identity primary key,
  agenda_id  uuid not null references public.agenda(id) on delete cascade,
  visitante  uuid not null references public.visitantes(id) on delete cascade,
  texto      text not null check (char_length(texto) between 3 and 200),
  status     text not null default 'pendente' check (status in ('pendente','exibida','respondida','oculta')),
  quando     timestamptz not null default now(),
  mediado_por uuid
);
create index if not exists perguntas_agenda on public.perguntas (agenda_id, status);
create table if not exists public.pergunta_votos (
  pergunta  bigint not null references public.perguntas(id) on delete cascade,
  visitante uuid not null references public.visitantes(id) on delete cascade,
  primary key (pergunta, visitante)
);
alter table public.perguntas enable row level security;
alter table public.pergunta_votos enable row level security;
revoke all on table public.perguntas from anon, authenticated, public;
revoke all on table public.pergunta_votos from anon, authenticated, public;
drop trigger if exists auditar on public.perguntas;
create trigger auditar after update or delete on public.perguntas for each row execute function public._auditar();

-- lista do visitante: as perguntas aprovadas (com votos) e as próprias ainda na fila
create or replace function public.perguntas_palestra(p_token text, p_agenda uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante(p_token);
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id', q.id, 'texto', q.texto, 'status', q.status, 'minha', q.visitante = v.id,
      'votos', (select count(*) from public.pergunta_votos pv where pv.pergunta = q.id),
      'votei', exists (select 1 from public.pergunta_votos pv where pv.pergunta = q.id and pv.visitante = v.id))
      order by (q.status = 'respondida'), (select count(*) from public.pergunta_votos pv where pv.pergunta = q.id) desc, q.id)
    from public.perguntas q where q.agenda_id = p_agenda and (q.status in ('exibida','respondida') or (q.visitante = v.id and q.status = 'pendente'))), '[]');
end $$;

create or replace function public.perguntar(p_token text, p_agenda uuid, p_texto text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante(p_token); tx text := trim(coalesce(p_texto, ''));
begin
  if v.menor then raise exception 'menor' using errcode = 'P0001'; end if;
  if not exists (select 1 from public.presencas where visitante = v.id and agenda_id = p_agenda) then raise exception 'sem_presenca' using errcode = 'P0001'; end if;
  if char_length(tx) not between 3 and 200 then raise exception 'texto_invalido' using errcode = 'P0001'; end if;
  if (select count(*) from public.perguntas where visitante = v.id and agenda_id = p_agenda) >= 3 then raise exception 'limite' using errcode = 'P0001'; end if;
  insert into public.perguntas (agenda_id, visitante, texto) values (p_agenda, v.id, tx);
  return public.perguntas_palestra(p_token, p_agenda);
end $$;

create or replace function public.votar_pergunta(p_token text, p_pergunta bigint)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante(p_token); q public.perguntas%rowtype;
begin
  select * into q from public.perguntas where id = p_pergunta and status = 'exibida';
  if not found then raise exception 'pergunta_invalida' using errcode = 'P0001'; end if;
  if not exists (select 1 from public.presencas where visitante = v.id and agenda_id = q.agenda_id) then raise exception 'sem_presenca' using errcode = 'P0001'; end if;
  if exists (select 1 from public.pergunta_votos where pergunta = q.id and visitante = v.id) then
    delete from public.pergunta_votos where pergunta = q.id and visitante = v.id;
  else
    insert into public.pergunta_votos (pergunta, visitante) values (q.id, v.id);
  end if;
  return public.perguntas_palestra(p_token, q.agenda_id);
end $$;

-- mediação (equipe): todas as perguntas da palestra, com votos
create or replace function public.perguntas_mediador(p_agenda uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.sou_equipe() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', q.id, 'texto', q.texto, 'status', q.status, 'quando', q.quando,
      'votos', (select count(*) from public.pergunta_votos pv where pv.pergunta = q.id))
      order by (select count(*) from public.pergunta_votos pv where pv.pergunta = q.id) desc, q.id)
    from public.perguntas q where q.agenda_id = p_agenda), '[]');
end $$;

create or replace function public.mediar_pergunta(p_id bigint, p_status text)
returns text language plpgsql volatile security definer set search_path = '' as $$
begin
  if not public.sou_equipe() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  if coalesce(p_status, '') not in ('exibida','respondida','oculta') then raise exception 'decisao_invalida' using errcode = 'P0001'; end if;
  update public.perguntas set status = p_status, mediado_por = auth.uid() where id = p_id;
  if not found then raise exception 'pergunta_invalida' using errcode = 'P0001'; end if;
  return p_status;
end $$;

-- ---------- assuntos em alta ----------
-- Palavras mais frequentes em textos públicos já aprovados (comentários públicos, mural e perguntas
-- exibidas) nas últimas 3 horas. Só palavras citadas por 3 ou mais pessoas diferentes.
create or replace function public._assuntos(p_ed text)
returns jsonb language sql stable security definer set search_path = '' as $$
  with textos as (
    select c.visitante, c.texto from public.comentarios c join public.visitantes v on v.id = c.visitante
     where v.ed = p_ed and c.publico and c.status = 'aprovado' and c.quando > now() - interval '3 hours'
    union all
    select p.visitante, p.texto from public.publicacoes p where p.ed = p_ed and p.status = 'aprovado' and p.texto is not null and p.quando > now() - interval '3 hours'
    union all
    select q.visitante, q.texto from public.perguntas q join public.agenda a on a.id = q.agenda_id
     where a.ed = p_ed and q.status in ('exibida','respondida') and q.quando > now() - interval '3 hours'),
  palavras as (
    select distinct t.visitante, w from textos t, regexp_split_to_table(lower(t.texto), '[^[:alnum:]À-ÿ]+') w
     where char_length(w) >= 4 and w !~ '^[0-9]+$'
       and w not in ('para','como','mais','muito','muita','muitos','muitas','esta','este','isso','essa','esse','aqui','ainda','sobre','pelo','pela',
                     'foram','está','estão','tudo','todo','toda','todos','todas','quem','qual','quais','quando','onde','porque','pois','mesmo','também',
                     'pode','podem','fazer','feira','tecnoshow','obrigado','obrigada','bom','boa','legal','gostei','tem','ter','vai','vou','com','uma',
                     'umas','uns','seu','sua','seus','suas','meu','minha','nosso','nossa','dele','dela','eles','elas','vocês','você','sendo','será',
                     'parece','ótimo','ótima','otimo','otima','achei','acho','gente','coisa','coisas','agora','hoje','aqui','lugar','dia','dias',
                     'excelente','incrível','lindo','linda','show','top','demais','bastante','sempre','nunca','nada','algo','cada','outro','outra',
                     'that','this','with','from','have','muy','pero','todo'))
  select coalesce(jsonb_agg(jsonb_build_object('palavra', w, 'pessoas', n) order by n desc, w), '[]')
    from (select w, count(*) n from palavras group by w having count(*) >= 3 order by 2 desc, 1 limit 10) x
$$;

create or replace function public.mural_telao(p_ed text, p_depois bigint default 0)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.sou_equipe() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return jsonb_build_object(
    'publicacoes', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'texto', p.texto, 'tem_foto', p.foto is not null,
        'alvo_tipo', p.alvo_tipo, 'alvo', public._nome_alvo(p.alvo_tipo, p.alvo_id), 'pos', public._posicao(p.alvo_tipo, p.alvo_id),
        'quando', p.quando) order by p.id)
      from (select * from public.publicacoes where ed = p_ed and status = 'aprovado' and id > coalesce(p_depois, 0) order by id desc limit 60) p), '[]'),
    'em_alta', public._em_alta(p_ed),
    'assuntos', public._assuntos(p_ed),
    'planta', (select jsonb_build_object('url', imagem_url, 'largura', largura, 'altura', altura) from public.plantas
                where ed = p_ed and ativa and excluido_em is null order by criado_em desc limit 1),
    'lotes', coalesce((select jsonb_agg(poligono) from public.lotes where ed = p_ed and excluido_em is null and poligono is not null), '[]'));
end $$;

-- estandes com mais pessoas diferentes nos últimos 30 minutos (só contagens, a partir de 3)
create or replace function public._em_alta(p_ed text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('estande', s.id, 'nome', x.nome, 'n', t.n, 'pos', public._posicao('estande', s.id),
           'lotes', (select jsonb_agg(l.numero order by length(l.numero), l.numero) from public.estande_lotes el join public.lotes l on l.id = el.lote_id where el.estande_id = s.id))
           order by t.n desc), '[]')
    from (select estande_id, count(distinct visitante) n from public.checkins c join public.estandes s2 on s2.id = c.estande_id
           where s2.ed = p_ed and c.quando > now() - interval '30 minutes' group by 1 having count(distinct visitante) >= 3 order by 2 desc limit 5) t
    join public.estandes s on s.id = t.estande_id join public.expositores x on x.id = s.expositor_id
$$;

-- ---------- acontecendo agora (página pública) ----------
create or replace function public.agora(p_ed text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'agora', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'titulo', a.titulo, 'palestrante', a.palestrante, 'inicio', a.inicio, 'fim', a.fim,
               'local', (select nome from public.locais where id = a.local_id)) order by a.inicio)
             from public.agenda a where a.ed = p_ed and a.excluido_em is null and a.inicio <= now() and coalesce(a.fim, a.inicio + interval '1 hour') > now()), '[]'),
    'a_seguir', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'titulo', a.titulo, 'palestrante', a.palestrante, 'inicio', a.inicio,
               'local', (select nome from public.locais where id = a.local_id)) order by a.inicio)
             from (select * from public.agenda where ed = p_ed and excluido_em is null and inicio > now() and inicio <= now() + interval '3 hours' order by inicio limit 8) a), '[]'),
    'em_alta', public._em_alta(p_ed),
    'assuntos', public._assuntos(p_ed),
    'trilhas', coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'titulo', t.titulo, 'premio', t.premio, 'etapas', jsonb_array_length(t.etapas)) order by t.criado_em)
             from public.trilhas t where t.ed = p_ed and t.status = 'aprovada' and t.excluido_em is null and (t.prazo is null or t.prazo > now())), '[]'))
$$;

-- ---------- permissões ----------
revoke all on function public._etapas_validas(jsonb)                   from public, anon, authenticated;
revoke all on function public._etapa_feita(uuid, jsonb)                from public, anon, authenticated;
revoke all on function public._nome_etapa(jsonb)                       from public, anon, authenticated;
revoke all on function public.trilhas_visitante(text)                  from public, anon, authenticated;
revoke all on function public.resgatar_cupom(text)                     from public, anon, authenticated;
revoke all on function public.metricas_trilha(uuid)                    from public, anon, authenticated;
revoke all on function public.trilhas_do_estab(uuid)                   from public, anon, authenticated;
revoke all on function public.perguntas_palestra(text, uuid)           from public, anon, authenticated;
revoke all on function public.perguntar(text, uuid, text)              from public, anon, authenticated;
revoke all on function public.votar_pergunta(text, bigint)             from public, anon, authenticated;
revoke all on function public.perguntas_mediador(uuid)                 from public, anon, authenticated;
revoke all on function public.mediar_pergunta(bigint, text)            from public, anon, authenticated;
revoke all on function public._assuntos(text)                          from public, anon, authenticated;
revoke all on function public._em_alta(text)                           from public, anon, authenticated;
revoke all on function public.mural_telao(text, bigint)                from public, anon, authenticated;
revoke all on function public.agora(text)                              from public, anon, authenticated;
grant execute on function public._etapas_validas(jsonb)                to authenticated;   -- usada pela regra da tabela trilhas
grant execute on function public.trilhas_visitante(text)               to anon, authenticated;
grant execute on function public.resgatar_cupom(text)                  to authenticated;
grant execute on function public.metricas_trilha(uuid)                 to authenticated;
grant execute on function public.trilhas_do_estab(uuid)                to authenticated;
grant execute on function public.perguntas_palestra(text, uuid)        to anon, authenticated;
grant execute on function public.perguntar(text, uuid, text)           to anon, authenticated;
grant execute on function public.votar_pergunta(text, bigint)          to anon, authenticated;
grant execute on function public.perguntas_mediador(uuid)              to authenticated;
grant execute on function public.mediar_pergunta(bigint, text)         to authenticated;
grant execute on function public.mural_telao(text, bigint)             to authenticated;
grant execute on function public.agora(text)                           to anon, authenticated;
