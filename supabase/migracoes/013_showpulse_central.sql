-- =====================================================================
-- Migração 013: ShowPulse (telão principal) e central do administrador
-- Rode depois da 012. Pode ser rodada de novo sem perder dados.
--
-- ShowPulse: uma única consulta devolve o que o telão mostra. Só contagens e o lado positivo:
--   reações "curti", "amei" e carinha "bom". Carinha neutra ou ruim nunca vai ao telão (decisão 25).
--   "Acaba de chegar" mostra só o município ou o país do perfil, sem mais nenhum dado da pessoa.
-- Central: situação da preparação da edição, para o administrador ver o que falta.
-- =====================================================================

-- Pulso da feira (0 a 100): fluxo (40%), satisfação (30%) e engajamento (30%)
create or replace function public._pulso(p_ed text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_agora int; v_pico int; v_bom int; v_car int; v_inter int; v_ativos int; f numeric; s numeric; e numeric;
begin
  -- fluxo: pessoas diferentes com visita nos últimos 30 min, contra o maior intervalo de 30 min do dia
  select count(distinct c.visitante) into v_agora from public.checkins c join public.estandes t on t.id = c.estande_id
   where t.ed = p_ed and c.quando > now() - interval '30 minutes';
  select coalesce(max(n), 0) into v_pico from (
    select count(distinct c.visitante) n from public.checkins c join public.estandes t on t.id = c.estande_id
     where t.ed = p_ed and c.quando > date_trunc('day', now())
     group by floor(extract(epoch from c.quando) / 1800)) x;
  f := case when greatest(v_pico, v_agora) = 0 then 0 else least(100, round(100.0 * v_agora / greatest(v_pico, v_agora))) end;
  -- satisfação: % de carinhas "bom" hoje (sem avaliações, fica neutro em 50)
  select count(*) filter (where a.carinha = 'bom'), count(*) into v_bom, v_car
    from public.avaliacoes a join public.visitantes v on v.id = a.visitante
   where v.ed = p_ed and a.quando > date_trunc('day', now());
  s := case when v_car = 0 then 50 else round(100.0 * v_bom / v_car) end;
  -- engajamento: interações por pessoa ativa na última hora (5 ou mais = 100)
  select count(distinct visitante), count(*) into v_ativos, v_inter from (
    select r.visitante from public.reacoes r join public.estandes t on t.id = r.estande_id where t.ed = p_ed and r.quando > now() - interval '1 hour'
    union all select c.visitante from public.checkins c join public.estandes t on t.id = c.estande_id where t.ed = p_ed and c.quando > now() - interval '1 hour'
    union all select p.visitante from public.presencas p join public.agenda g on g.id = p.agenda_id where g.ed = p_ed and p.quando > now() - interval '1 hour') u;
  e := case when v_ativos = 0 then 0 else least(100, round(20.0 * v_inter / v_ativos)) end;
  return jsonb_build_object('valor', round(0.4 * f + 0.3 * s + 0.3 * e), 'fluxo', f, 'satisfacao', s, 'engajamento', e, 'ativos', v_agora);
end $$;

create or replace function public.showpulse(p_ed text, p_desde timestamptz default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_desde timestamptz := greatest(coalesce(p_desde, now() - interval '2 minutes'), now() - interval '10 minutes');
begin
  if not public.sou_equipe() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return jsonb_build_object(
    'agora', now(),
    'pulso', public._pulso(p_ed),
    'totais', jsonb_build_object(
      'visitantes', (select count(*) from public.visitantes where ed = p_ed),
      'hoje', (select count(*) from public.visitantes where ed = p_ed and criado_em > date_trunc('day', now())),
      'interacoes', (select count(*) from public.reacoes r join public.estandes t on t.id = r.estande_id where t.ed = p_ed)
                  + (select count(*) from public.checkins c join public.estandes t on t.id = c.estande_id where t.ed = p_ed)
                  + (select count(*) from public.presencas p join public.agenda g on g.id = p.agenda_id where g.ed = p_ed)),
    -- corrida das cidades: contagem por município ou país
    'cidades', coalesce((select jsonb_agg(jsonb_build_object('mun', mun, 'pais', pais, 'n', n) order by n desc) from (
        select (perfil->>'mun')::int mun, case when perfil->>'mun' is null then perfil->>'pais' end pais, count(*) n
          from public.visitantes where ed = p_ed group by 1, 2 order by 3 desc limit 400) c), '[]'),
    -- "acaba de chegar": só o município ou o país
    'chegadas', coalesce((select jsonb_agg(jsonb_build_object('mun', (perfil->>'mun')::int, 'pais', case when perfil->>'mun' is null then perfil->>'pais' end, 'quando', criado_em) order by criado_em)
        from (select perfil, criado_em from public.visitantes where ed = p_ed and criado_em > v_desde order by criado_em desc limit 30) n), '[]'),
    -- reações positivas recentes, por estande (sobem no mapa)
    'reacoes', coalesce((select jsonb_agg(jsonb_build_object('estande', estande, 'tipo', tipo, 'quando', quando) order by quando) from (
        select r.estande_id estande, r.tipo, r.quando from public.reacoes r join public.estandes t on t.id = r.estande_id
         where t.ed = p_ed and r.quando > v_desde
        union all
        select a.alvo_id, 'bom', a.quando from public.avaliacoes a join public.estandes t on t.id = a.alvo_id
         where a.alvo_tipo = 'estande' and a.carinha = 'bom' and t.ed = p_ed and a.quando > v_desde
        order by 3 desc limit 80) q), '[]'),
    -- estandes com posição no mapa e o calor do dia (reações positivas de hoje)
    'estandes', coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'nome', x.nome, 'pos', public._posicao('estande', t.id),
          'calor', (select count(*) from public.reacoes r where r.estande_id = t.id and r.quando > date_trunc('day', now()))
                 + (select count(*) from public.avaliacoes a where a.alvo_tipo = 'estande' and a.alvo_id = t.id and a.carinha = 'bom' and a.quando > date_trunc('day', now()))))
        from public.estandes t join public.expositores x on x.id = t.expositor_id
       where t.ed = p_ed and t.excluido_em is null and public._posicao('estande', t.id) is not null), '[]'),
    'em_alta', public._em_alta(p_ed),
    -- subindo agora: mais pessoas nos últimos 30 min do que nos 30 anteriores (a partir de 3)
    'subindo', coalesce((select jsonb_agg(jsonb_build_object('nome', nome, 'agora', a, 'antes', b) order by (a - b) desc) from (
        select x.nome, count(distinct c.visitante) filter (where c.quando > now() - interval '30 minutes') a,
               count(distinct c.visitante) filter (where c.quando <= now() - interval '30 minutes') b
          from public.checkins c join public.estandes t on t.id = c.estande_id join public.expositores x on x.id = t.expositor_id
         where t.ed = p_ed and c.quando > now() - interval '60 minutes' group by x.nome
        having count(distinct c.visitante) filter (where c.quando > now() - interval '30 minutes') >= 3
           and count(distinct c.visitante) filter (where c.quando > now() - interval '30 minutes')
             > count(distinct c.visitante) filter (where c.quando <= now() - interval '30 minutes')
         order by 2 desc limit 5) s), '[]'),
    -- produtos mais amados e salvos (a partir de 3)
    'amados', coalesce((select jsonb_agg(jsonb_build_object('produto', produto, 'expositor', expositor, 'n', n) order by n desc) from (
        select produto, expositor, n from (
          select p.nome produto, x.nome expositor,
                 (select count(*) from public.reacoes r where r.produto_id = p.id and r.tipo = 'amei') + (select count(*) from public.salvos s where s.produto_id = p.id) n
            from public.produtos p join public.expositores x on x.id = p.expositor_id
            join public.estandes t on t.expositor_id = x.id and t.ed = p_ed and t.excluido_em is null
           where p.excluido_em is null) a where n >= 3 order by n desc limit 5) b), '[]'),
    'palestras', (public.agora(p_ed))->'agora',
    'planta', (select jsonb_build_object('url', imagem_url, 'largura', largura, 'altura', altura) from public.plantas
                where ed = p_ed and ativa and excluido_em is null order by criado_em desc limit 1),
    'lotes', coalesce((select jsonb_agg(poligono) from public.lotes where ed = p_ed and excluido_em is null and poligono is not null), '[]'));
end $$;

-- ---------- central do administrador: o que falta para a edição ficar pronta ----------
create or replace function public.status_edicao(p_ed text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare e public.edicoes%rowtype;
begin
  if not public.sou_equipe() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  select * into e from public.edicoes where slug = p_ed;
  if not found then return jsonb_build_object('existe', false); end if;
  return jsonb_build_object('existe', true, 'nome', e.nome, 'aberta', e.aberta, 'inicio', e.inicio, 'fim', e.fim,
    'expositores', (select count(*) from public.estandes where ed = p_ed and excluido_em is null),
    'expositores_confirmados', (select count(*) from public.estandes s join public.expositores x on x.id = s.expositor_id where s.ed = p_ed and s.excluido_em is null and x.status = 'confirmado'),
    'estandes_com_conta', (select count(distinct s.id) from public.estandes s join public.expositor_equipe q on q.expositor_id = s.expositor_id where s.ed = p_ed and s.excluido_em is null),
    'lotes', (select count(*) from public.lotes where ed = p_ed and excluido_em is null),
    'lotes_no_mapa', (select count(*) from public.lotes where ed = p_ed and excluido_em is null and poligono is not null),
    'planta', exists (select 1 from public.plantas where ed = p_ed and ativa and excluido_em is null),
    'agenda', (select count(*) from public.agenda where ed = p_ed and excluido_em is null),
    'agenda_com_horario', (select count(*) from public.agenda where ed = p_ed and excluido_em is null and inicio is not null),
    'produtos', (select count(*) from public.produtos p join public.estandes s on s.expositor_id = p.expositor_id where s.ed = p_ed and p.excluido_em is null),
    'trilhas_aprovadas', (select count(*) from public.trilhas where ed = p_ed and status = 'aprovada' and excluido_em is null),
    'trilhas_propostas', (select count(*) from public.trilhas where ed = p_ed and status = 'proposta' and excluido_em is null),
    'parceiros_cidade', (select count(*) from public.estabelecimentos where ed = p_ed and excluido_em is null),
    'questionario_versao', (select coalesce(max(versao), 0) from public.instrumentos where ed = p_ed),
    'equipe', (select count(*) from public.equipe),
    'moderadores', (select count(*) from public.equipe where papel in ('moderador','organizacao','coordenador','admin_geral')),
    'tablets_ativos', (select count(*) from public.dispositivos where ed = p_ed and token_hash is not null and revogado_em is null),
    'chave_unica', e.chave_unica,
    'codigo_saida', e.codigo_saida_hash is not null,
    'respostas', (select count(*) from public.respostas where ed = p_ed),
    'visitantes', (select count(*) from public.visitantes where ed = p_ed),
    'comentarios_pendentes', (select count(*) from public.comentarios c join public.visitantes v on v.id = c.visitante where v.ed = p_ed and c.publico and c.status = 'pendente'),
    'mural_pendente', (select count(*) from public.publicacoes where ed = p_ed and status = 'pendente'),
    'avaliacoes_a_enviar', coalesce((public.resumo_fila_avaliacao(p_ed, 3)->>'pendente')::int, 0));
end $$;

revoke all on function public._pulso(text)                    from public, anon, authenticated;
revoke all on function public.showpulse(text, timestamptz)    from public, anon, authenticated;
revoke all on function public.status_edicao(text)             from public, anon, authenticated;
grant execute on function public.showpulse(text, timestamptz) to authenticated;
grant execute on function public.status_edicao(text)          to authenticated;
