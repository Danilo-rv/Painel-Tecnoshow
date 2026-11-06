-- =====================================================================
-- Migração 011: avaliação final pelo celular (decisão 33a) e limpeza antes do piloto
-- Rode depois da 010. Pode ser rodada de novo sem perder dados.
--
-- Avaliação final: página em formato de conversa, sem menus nem login, aberta pelo link que
--   depois irá por WhatsApp. O visitante usa a credencial do próprio celular; as perguntas já
--   respondidas no perfil vêm do banco. Uma resposta por visitante, no mesmo formato dos tablets
--   (origem "WEB"), para o painel e o relatório lerem sem mudança.
-- Limpeza: o administrador geral vê o que seria apagado e só apaga confirmando o nome da edição.
--   Cadastros, equipe, questionário e auditoria ficam.
-- =====================================================================

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
  if coalesce(r->>'tab', '') !~ '^(T[0-9]{2}|PAINEL|WEB)$' then return false; end if;   -- WEB: avaliação pelo celular
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

create or replace function public.avaliacao_estado(p_token text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante(p_token);
begin
  return jsonb_build_object('ed', v.ed, 'lang', v.lang,
    'perfil', v.perfil - 'culturas',
    'respondeu', exists (select 1 from public.respostas where id = 'web-' || v.id::text));
end $$;

create or replace function public.responder_avaliacao(p_token text, p_resp jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante(p_token); e public.edicoes%rowtype; r jsonb; pf jsonb; v_def jsonb; k text;
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
  return jsonb_build_object('ok', true, 'mun', r->'mun', 'pais', r->'pais');
end $$;

-- ---------- limpeza antes do piloto ----------
create or replace function public.limpar_edicao(p_ed text, p_confirmacao text default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare c jsonb;
begin
  if not public.sou_admin_geral() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  if not exists (select 1 from public.edicoes where slug = p_ed) then raise exception 'edicao_inexistente' using errcode = 'P0001'; end if;
  c := jsonb_build_object(
    'respostas_da_pesquisa', (select count(*) from public.respostas where ed = p_ed),
    'visitantes', (select count(*) from public.visitantes where ed = p_ed),
    'visitas_a_estandes', (select count(*) from public.checkins k join public.visitantes v on v.id = k.visitante where v.ed = p_ed),
    'comentarios', (select count(*) from public.comentarios k join public.visitantes v on v.id = k.visitante where v.ed = p_ed),
    'publicacoes_do_mural', (select count(*) from public.publicacoes where ed = p_ed),
    'presencas', (select count(*) from public.presencas k join public.visitantes v on v.id = k.visitante where v.ed = p_ed),
    'cupons', (select count(*) from public.cupons k join public.trilhas t on t.id = k.trilha_id where t.ed = p_ed),
    'checkins_na_cidade', (select count(*) from public.cidade_checkins k join public.visitantes v on v.id = k.visitante where v.ed = p_ed),
    'ocupacao_hoteleira', (select count(*) from public.ocupacao_hoteis o join public.estabelecimentos e on e.id = o.estab_id where e.ed = p_ed),
    'tablets_habilitados', (select count(*) from public.dispositivos where ed = p_ed));
  if p_confirmacao is null then return jsonb_build_object('previa', true, 'apagaria', c); end if;
  if p_confirmacao <> p_ed then raise exception 'confirmacao_invalida' using errcode = 'P0001'; end if;
  delete from public.respostas where ed = p_ed;
  delete from public.publicacoes where ed = p_ed;
  delete from public.cupons where trilha_id in (select id from public.trilhas where ed = p_ed);
  delete from public.ocupacao_hoteis where estab_id in (select id from public.estabelecimentos where ed = p_ed);
  delete from public.dispositivos where ed = p_ed;
  delete from public.visitantes where ed = p_ed;            -- em cascata: visitas, reações, avaliações, comentários, contatos, presenças, perguntas, cidade
  insert into public.auditoria (quem, tabela, registro, acao, antes) values (auth.uid(), 'edicoes', p_ed, 'limpeza_pre_piloto', c);
  return jsonb_build_object('previa', false, 'apagado', c);
end $$;

revoke all on function public._resposta_valida(jsonb)                 from public, anon, authenticated;
revoke all on function public.avaliacao_estado(text)                  from public, anon, authenticated;
revoke all on function public.responder_avaliacao(text, jsonb)        from public, anon, authenticated;
revoke all on function public.limpar_edicao(text, text)               from public, anon, authenticated;
grant execute on function public.avaliacao_estado(text)               to anon, authenticated;
grant execute on function public.responder_avaliacao(text, jsonb)     to anon, authenticated;
grant execute on function public.limpar_edicao(text, text)            to authenticated;
