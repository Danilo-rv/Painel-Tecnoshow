-- =====================================================================
-- Migração 010: credencial própria por tablet, trilha proposta pelo estande e dados abertos
-- Rode depois da 009. Pode ser rodada de novo sem perder dados.
--
-- Tablets (seção 18.4): a equipe gera um código de habilitação de 6 dígitos (vale 15 min,
--   uma vez); o tablet troca o código por uma credencial própria, que pode ser desligada
--   sozinha. A chave única da edição continua aceita até a coordenação desligá-la.
-- Trilha proposta: o estande propõe; a organização aprova em Cadastros › Trilhas.
-- Dados abertos (decisão 9): agregados públicos, só grupos com 5 ou mais pessoas.
-- =====================================================================

-- ---------- aparelhos ----------
create table if not exists public.dispositivos (
  id          uuid primary key default gen_random_uuid(),
  ed          text not null references public.edicoes(slug) on delete cascade,
  nome        text not null check (char_length(nome) between 1 and 60),
  token_hash  text unique check (token_hash ~ '^[0-9a-f]{64}$'),
  codigo_hash text check (codigo_hash ~ '^[0-9a-f]{64}$'),
  codigo_expira timestamptz,
  criado_por  uuid,
  criado_em   timestamptz not null default now(),
  habilitado_em timestamptz,
  ultimo_uso  timestamptz,
  revogado_em timestamptz
);
alter table public.dispositivos enable row level security;
revoke all on table public.dispositivos from anon, authenticated, public;
drop trigger if exists auditar on public.dispositivos;
create trigger auditar after insert or update or delete on public.dispositivos for each row execute function public._auditar();
alter table public.edicoes add column if not exists chave_unica boolean not null default true;

create or replace function public._chave_ok(p_ed text, p_chave text)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
declare h text; e public.edicoes%rowtype;
begin
  if p_chave is null or char_length(p_chave) > 200 then return false; end if;
  h := encode(sha256(convert_to(p_chave, 'UTF8')), 'hex');
  select * into e from public.edicoes where slug = p_ed;
  if not found then return false; end if;
  if e.chave_unica and h = e.chave_hash then return true; end if;
  update public.dispositivos set ultimo_uso = now()
   where ed = p_ed and token_hash = h and revogado_em is null and (ultimo_uso is null or ultimo_uso < now() - interval '5 minutes');
  return exists (select 1 from public.dispositivos where ed = p_ed and token_hash = h and revogado_em is null);
end $$;

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
  if not public._chave_ok(p_ed, p_chave) then
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

create or replace function public.codigo_saida(p_ed text, p_chave text)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare e public.edicoes%rowtype;
begin
  select * into e from public.edicoes where slug = p_ed;
  if not found or not public._chave_ok(p_ed, p_chave) then
    raise exception 'chave_invalida' using errcode = 'P0001'; end if;
  return e.codigo_saida_hash;
end $$;

create or replace function public.registrar_saida(p_ed text, p_chave text, p_tablet text)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
declare e public.edicoes%rowtype;
begin
  select * into e from public.edicoes where slug = p_ed;
  if not found or not public._chave_ok(p_ed, p_chave) then
    raise exception 'chave_invalida' using errcode = 'P0001'; end if;
  if (select count(*) from public.auditoria where tabela = 'saida_tablet' and quando > now() - interval '1 hour') > 200 then return false; end if;
  insert into public.auditoria (quem, tabela, registro, acao)
  values (null, 'saida_tablet', p_ed, 'saida ' || left(regexp_replace(coalesce(p_tablet, ''), '[^A-Za-z0-9]', '', 'g'), 10));
  return true;
end $$;

-- equipe treinada gera o código (6 dígitos, 15 minutos, uso único)
create or replace function public.criar_codigo_aparelho(p_ed text, p_nome text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_cod text := lpad((floor(random() * 1000000))::int::text, 6, '0'); v_id uuid;
begin
  if not public.sou_equipe() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  if not exists (select 1 from public.edicoes where slug = p_ed) then raise exception 'edicao_inexistente' using errcode = 'P0001'; end if;
  if char_length(trim(coalesce(p_nome, ''))) not between 1 and 60 then raise exception 'nome_invalido' using errcode = 'P0001'; end if;
  insert into public.dispositivos (ed, nome, codigo_hash, codigo_expira, criado_por)
  values (p_ed, trim(p_nome), encode(sha256(convert_to(p_ed || ':' || v_cod, 'UTF8')), 'hex'), now() + interval '15 minutes', auth.uid())
  returning id into v_id;
  return jsonb_build_object('id', v_id, 'codigo', v_cod, 'expira_em', now() + interval '15 minutes');
end $$;

-- o tablet troca o código pela credencial própria (sem login)
create or replace function public.habilitar_aparelho(p_ed text, p_codigo text)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare d public.dispositivos%rowtype; v_tok text := encode(extensions.gen_random_bytes(32), 'hex');
begin
  -- contra tentativa e erro: no máximo 30 códigos errados por edição a cada 10 minutos
  if (select count(*) from public.auditoria where tabela = 'aparelho_tentativa' and registro = p_ed and quando > now() - interval '10 minutes') >= 30 then
    return jsonb_build_object('ok', false, 'motivo', 'limite'); end if;
  select * into d from public.dispositivos
   where ed = p_ed and codigo_hash = encode(sha256(convert_to(coalesce(p_ed, '') || ':' || coalesce(p_codigo, ''), 'UTF8')), 'hex')
     and codigo_expira > now() and token_hash is null and revogado_em is null
   for update;
  if not found then
    insert into public.auditoria (quem, tabela, registro, acao) values (null, 'aparelho_tentativa', p_ed, 'codigo_errado');
    return jsonb_build_object('ok', false, 'motivo', 'codigo_invalido');
  end if;
  update public.dispositivos set token_hash = encode(sha256(convert_to(v_tok, 'UTF8')), 'hex'), codigo_hash = null, codigo_expira = null,
         habilitado_em = now(), ultimo_uso = now() where id = d.id;
  return jsonb_build_object('ok', true, 'token', v_tok, 'nome', d.nome);
end $$;

create or replace function public.listar_aparelhos(p_ed text)
returns table (id uuid, nome text, criado_em timestamptz, habilitado_em timestamptz, ultimo_uso timestamptz, revogado_em timestamptz, aguardando boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.sou_equipe() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return query select x.id, x.nome, x.criado_em, x.habilitado_em, x.ultimo_uso, x.revogado_em, (x.token_hash is null and x.codigo_expira > now())
    from public.dispositivos x where x.ed = p_ed and (x.token_hash is not null or x.codigo_expira > now()) order by x.criado_em desc;
end $$;

create or replace function public.revogar_aparelho(p_id uuid)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
begin
  if not public.pode_editar_cadastros() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  update public.dispositivos set revogado_em = now(), codigo_hash = null, codigo_expira = null where id = p_id and revogado_em is null;
  return found;
end $$;

create or replace function public.definir_chave_unica(p_ed text, p_aceita boolean)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
begin
  if not public.sou_coordenador() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  update public.edicoes set chave_unica = coalesce(p_aceita, true) where slug = p_ed;
  insert into public.auditoria (quem, tabela, registro, acao) values (auth.uid(), 'edicoes', p_ed, case when p_aceita then 'chave_unica_ligada' else 'chave_unica_desligada' end);
  return coalesce(p_aceita, true);
end $$;
create or replace function public.info_chave_unica(p_ed text)
returns boolean language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.sou_equipe() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return (select chave_unica from public.edicoes where slug = p_ed);
end $$;

-- ---------- trilha proposta pelo estande ----------
alter table public.trilhas drop constraint if exists trilhas_status_check;
alter table public.trilhas add constraint trilhas_status_check check (status in ('rascunho','proposta','aprovada','encerrada'));

-- o que o estande pode usar como etapa: palestras, estandes e parceiros da cidade da edição
create or replace function public.opcoes_trilha(p_estande uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_ed text;
begin
  if not public._pode_ver_estande(p_estande) then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  select ed into v_ed from public.estandes where id = p_estande;
  return jsonb_build_object(
    'palestras', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'nome', titulo, 'inicio', inicio) order by inicio nulls last, titulo) from public.agenda where ed = v_ed and excluido_em is null), '[]'),
    'estandes', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'nome', x.nome) order by x.nome) from public.estandes s join public.expositores x on x.id = s.expositor_id where s.ed = v_ed and s.excluido_em is null), '[]'),
    'cidade', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'nome', nome) order by nome) from public.estabelecimentos where ed = v_ed and excluido_em is null), '[]'));
end $$;

create or replace function public.propor_trilha(p_estande uuid, p_titulo text, p_premio text, p_estoque int, p_prazo timestamptz,
                                                p_descricao text, p_regulamento text, p_etapas jsonb)
returns uuid language plpgsql volatile security definer set search_path = '' as $$
declare v_ed text; v_id uuid;
begin
  if not public._pode_ver_estande(p_estande) then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  select ed into v_ed from public.estandes where id = p_estande and excluido_em is null;
  if not found then raise exception 'estande_invalido' using errcode = 'P0001'; end if;
  if (select count(*) from public.trilhas where doador_estande = p_estande and status = 'proposta' and excluido_em is null) >= 3 then
    raise exception 'limite' using errcode = 'P0001'; end if;
  if not public._etapas_validas(p_etapas) then raise exception 'etapas_invalidas' using errcode = 'P0001'; end if;
  -- toda etapa precisa existir nesta edição
  if exists (select 1 from jsonb_array_elements(p_etapas) e where not (
       (e->>'tipo' = 'palestra' and exists (select 1 from public.agenda where id = (e->>'id')::uuid and ed = v_ed and excluido_em is null))
    or (e->>'tipo' = 'estande'  and exists (select 1 from public.estandes where id = (e->>'id')::uuid and ed = v_ed and excluido_em is null))
    or (e->>'tipo' = 'cidade'   and exists (select 1 from public.estabelecimentos where id = (e->>'id')::uuid and ed = v_ed and excluido_em is null)))) then
    raise exception 'etapas_invalidas' using errcode = 'P0001'; end if;
  begin
    insert into public.trilhas (ed, titulo, premio, doador_estande, estoque, prazo, descricao, regulamento, etapas, status)
    values (v_ed, trim(p_titulo), trim(p_premio), p_estande, coalesce(p_estoque, 0), p_prazo, nullif(trim(coalesce(p_descricao, '')), ''),
            nullif(trim(coalesce(p_regulamento, '')), ''), p_etapas, 'proposta') returning id into v_id;
  exception when check_violation or not_null_violation then raise exception 'valor_invalido' using errcode = 'P0001';
  end;
  return v_id;
end $$;

-- ---------- dados abertos (decisão 9): agregados públicos, grupos com 5 ou mais pessoas ----------
create or replace function public.dados_abertos(p_ed text)
returns jsonb language sql stable security definer set search_path = '' as $$
  with vis as (select * from public.visitantes where ed = p_ed),
  dias as (select (c.quando at time zone 'America/Sao_Paulo')::date dia, count(distinct c.visitante) n
             from public.checkins c join vis v on v.id = c.visitante group by 1)
  select jsonb_build_object(
    'edicao', (select jsonb_build_object('slug', slug, 'nome', nome, 'inicio', inicio, 'fim', fim) from public.edicoes where slug = p_ed),
    'gerado_em', now(),
    'regra', 'Somente agregados; grupos com menos de 5 pessoas entram em "outros" ou não aparecem.',
    'totais', jsonb_build_object(
      'respostas_pesquisa', (select count(*) from public.respostas where ed = p_ed),
      'visitantes_com_perfil', (select count(*) from vis),
      'visitas_a_estandes', (select count(*) from public.checkins c join vis v on v.id = c.visitante),
      'presencas_em_palestras', (select count(*) from public.presencas p join vis v on v.id = p.visitante),
      'checkins_na_cidade', (select count(*) from public.cidade_checkins c join vis v on v.id = c.visitante),
      'trilhas_completadas', (select count(*) from public.cupons c join public.trilhas t on t.id = c.trilha_id where t.ed = p_ed)),
    'visitantes_por_dia', coalesce((select jsonb_agg(jsonb_build_object('dia', dia, 'visitantes', n) order by dia) from dias where n >= 5), '[]'),
    'perfil', (select jsonb_object_agg(k, n) from (select k, sum(n)::int n from (select case when count(*) >= 5 then perfil->>'perfil' else 'outros' end k, count(*) n
                from vis group by perfil->>'perfil') a group by k) b),
    'faixa_etaria', (select jsonb_object_agg(k, n) from (select k, sum(n)::int n from (select case when count(*) >= 5 then perfil->>'idade' else 'outros' end k, count(*) n
                from vis group by perfil->>'idade') a group by k) b),
    'origem_uf', coalesce((select jsonb_agg(jsonb_build_object('uf', uf, 'visitantes', n) order by n desc) from (
                select (perfil->>'mun')::int / 100000 uf, count(*) n from vis where perfil->>'mun' is not null group by 1 having count(*) >= 5) a), '[]'),
    'origem_municipio', coalesce((select jsonb_agg(jsonb_build_object('ibge', mun, 'visitantes', n) order by n desc) from (
                select (perfil->>'mun')::int mun, count(*) n from vis where perfil->>'mun' is not null group by 1 having count(*) >= 5) a), '[]'),
    'origem_pais', coalesce((select jsonb_agg(jsonb_build_object('pais', pais, 'visitantes', n) order by n desc) from (
                select perfil->>'pais' pais, count(*) n from vis where coalesce(perfil->>'pais', 'BR') <> 'BR' group by 1 having count(*) >= 5) a), '[]'),
    'interesses', coalesce((select jsonb_agg(jsonb_build_object('cultura', c, 'visitantes', n) order by n desc) from (
                select c, count(*) n from vis, jsonb_array_elements_text(coalesce(perfil->'culturas', '[]')) c group by 1 having count(*) >= 5) a), '[]'),
    'visitas_por_categoria', coalesce((select jsonb_agg(jsonb_build_object('categoria', cat, 'visitantes', n) order by n desc) from (
                select coalesce(g.nome, 'Sem categoria') cat, count(distinct c.visitante) n from public.checkins c join vis v on v.id = c.visitante
                  join public.estandes s on s.id = c.estande_id join public.expositores x on x.id = s.expositor_id left join public.categorias g on g.id = x.categoria_id
                 group by 1 having count(distinct c.visitante) >= 5) a), '[]'),
    'publico_por_palestra', coalesce((select jsonb_agg(jsonb_build_object('palestra', a.titulo, 'inicio', a.inicio, 'presencas', n) order by a.inicio) from (
                select p.agenda_id, count(*) n from public.presencas p join vis v on v.id = p.visitante group by 1 having count(*) >= 5) t
                join public.agenda a on a.id = t.agenda_id), '[]'),
    'hospedagem', (select case when count(*) >= 5 then jsonb_build_object('respostas', count(*), 'noites_media', round(avg(h.noites), 1), 'pessoas_media', round(avg(h.pessoas), 1)) end
                from public.hospedagens h join vis v on v.id = h.visitante),
    'ocupacao_hoteleira', public._demanda_hoteis(p_ed))
$$;

-- ---------- permissões ----------
revoke all on function public._chave_ok(text, text)                         from public, anon, authenticated;
revoke all on function public.enviar_respostas(text, text, jsonb)           from public, anon, authenticated;
revoke all on function public.codigo_saida(text, text)                      from public, anon, authenticated;
revoke all on function public.registrar_saida(text, text, text)             from public, anon, authenticated;
revoke all on function public.criar_codigo_aparelho(text, text)             from public, anon, authenticated;
revoke all on function public.habilitar_aparelho(text, text)                from public, anon, authenticated;
revoke all on function public.listar_aparelhos(text)                        from public, anon, authenticated;
revoke all on function public.revogar_aparelho(uuid)                        from public, anon, authenticated;
revoke all on function public.definir_chave_unica(text, boolean)            from public, anon, authenticated;
revoke all on function public.info_chave_unica(text)                        from public, anon, authenticated;
revoke all on function public.opcoes_trilha(uuid)                           from public, anon, authenticated;
revoke all on function public.propor_trilha(uuid, text, text, int, timestamptz, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.dados_abertos(text)                           from public, anon, authenticated;
grant execute on function public.enviar_respostas(text, text, jsonb)        to anon, authenticated;
grant execute on function public.codigo_saida(text, text)                   to anon, authenticated;
grant execute on function public.registrar_saida(text, text, text)          to anon, authenticated;
grant execute on function public.criar_codigo_aparelho(text, text)          to authenticated;
grant execute on function public.habilitar_aparelho(text, text)             to anon, authenticated;
grant execute on function public.listar_aparelhos(text)                     to authenticated;
grant execute on function public.revogar_aparelho(uuid)                     to authenticated;
grant execute on function public.definir_chave_unica(text, boolean)         to authenticated;
grant execute on function public.info_chave_unica(text)                     to authenticated;
grant execute on function public.opcoes_trilha(uuid)                        to authenticated;
grant execute on function public.propor_trilha(uuid, text, text, int, timestamptz, text, text, jsonb) to authenticated;
grant execute on function public.dados_abertos(text)                        to anon, authenticated;
