-- =====================================================================
-- Migração 014: vídeos curtos no mural e moderação com IA (CEIA Lumi)
-- Rode depois da 013. Pode ser rodada de novo sem perder dados.
--
-- Vídeo: o visitante adulto envia um vídeo de até 20 segundos e 12 MB. O arquivo vai para um
--   depósito privado (Storage); o banco só aceita o envio de um arquivo "reservado" antes por uma
--   função que confere o visitante, o tamanho e o limite de 2 vídeos por hora.
-- Moderação: nada aparece sem aprovação. A IA (CEIA Lumi) pode dar um parecer; o administrador
--   geral escolhe se ela só sugere ou se aprova e recusa sozinha.
-- Chave da API: gravada por função, guardada na tabela de segredos (que a API não lê) e
--   nunca devolvida ao navegador.
-- =====================================================================

-- ---------- vídeo nas publicações ----------
alter table public.publicacoes add column if not exists video_path text unique
  check (video_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(mp4|webm|mov)$');
alter table public.publicacoes add column if not exists video_tipo text check (video_tipo in ('video/mp4','video/webm','video/quicktime'));
alter table public.publicacoes add column if not exists video_segundos numeric(5,1) check (video_segundos between 0.5 and 21);
alter table public.publicacoes add column if not exists ia_parecer text check (ia_parecer in ('aprovar','recusar','revisar'));
alter table public.publicacoes add column if not exists ia_motivo text check (char_length(ia_motivo) <= 500);
alter table public.publicacoes add column if not exists ia_em timestamptz;
alter table public.publicacoes drop constraint if exists publicacoes_status_check;
alter table public.publicacoes add constraint publicacoes_status_check check (status in ('aguardando_upload','pendente','aprovado','recusado'));
alter table public.publicacoes drop constraint if exists publicacoes_check;
alter table public.publicacoes drop constraint if exists publicacoes_conteudo;
alter table public.publicacoes add constraint publicacoes_conteudo check (texto is not null or foto is not null or video_path is not null);

-- 1) reserva: confere tudo e devolve o caminho onde o arquivo pode ser enviado
create or replace function public.reservar_video(p_token text, p_alvo_tipo text, p_alvo_id uuid, p_texto text, p_tipo text, p_bytes int, p_segundos numeric)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante(p_token); tx text := nullif(trim(coalesce(p_texto, '')), ''); v_ext text; v_path text; v_id bigint;
begin
  if v.menor then raise exception 'menor' using errcode = 'P0001'; end if;
  if p_alvo_tipo = 'estande' then
    if not exists (select 1 from public.estandes where id = p_alvo_id and ed = v.ed and excluido_em is null) then raise exception 'alvo_invalido' using errcode = 'P0001'; end if;
  elsif p_alvo_tipo = 'palestra' then
    if not exists (select 1 from public.agenda where id = p_alvo_id and ed = v.ed and excluido_em is null) then raise exception 'alvo_invalido' using errcode = 'P0001'; end if;
  else raise exception 'alvo_invalido' using errcode = 'P0001'; end if;
  if char_length(tx) > 140 then raise exception 'texto_longo' using errcode = 'P0001'; end if;
  v_ext := case p_tipo when 'video/mp4' then 'mp4' when 'video/webm' then 'webm' when 'video/quicktime' then 'mov' end;
  if v_ext is null then raise exception 'video_invalido' using errcode = 'P0001'; end if;
  if coalesce(p_bytes, 0) not between 1000 and 12582912 then raise exception 'video_grande' using errcode = 'P0001'; end if;
  if coalesce(p_segundos, 0) not between 0.5 and 21 then raise exception 'video_longo' using errcode = 'P0001'; end if;
  delete from public.publicacoes where status = 'aguardando_upload' and quando < now() - interval '30 minutes';
  if (select count(*) from public.publicacoes where visitante = v.id and video_path is not null and quando > now() - interval '1 hour') >= 2 then
    raise exception 'limite' using errcode = 'P0001'; end if;
  v_path := gen_random_uuid()::text || '.' || v_ext;
  insert into public.publicacoes (ed, visitante, alvo_tipo, alvo_id, texto, video_path, video_tipo, video_segundos, status)
  values (v.ed, v.id, p_alvo_tipo, p_alvo_id, tx, v_path, p_tipo, p_segundos, 'aguardando_upload') returning id into v_id;
  return jsonb_build_object('id', v_id, 'caminho', v_path);
end $$;

-- usada pela regra do Storage: só aceita o arquivo reservado nos últimos 15 minutos
create or replace function public._video_reservado(p_nome text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.publicacoes where video_path = p_nome and status = 'aguardando_upload' and quando > now() - interval '15 minutes')
$$;
-- quem pode assistir: a moderação vê todos; o restante da equipe (telões), só os aprovados
create or replace function public._video_legivel(p_nome text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.pode_moderar() or (public.sou_equipe() and exists (select 1 from public.publicacoes where video_path = p_nome and status = 'aprovado'))
$$;

-- 2) confirmação: o arquivo chegou; a publicação entra na fila de moderação
create or replace function public.confirmar_video(p_token text, p_id bigint)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v public.visitantes%rowtype := public._visitante(p_token); p public.publicacoes%rowtype; v_ok boolean := true;
begin
  select * into p from public.publicacoes where id = p_id and visitante = v.id and status = 'aguardando_upload' for update;
  if not found then raise exception 'publicacao_invalida' using errcode = 'P0001'; end if;
  if to_regclass('storage.objects') is not null then
    execute 'select exists (select 1 from storage.objects where bucket_id = ''mural-videos'' and name = $1)' into v_ok using p.video_path;
  end if;
  if not v_ok then raise exception 'video_ausente' using errcode = 'P0001'; end if;
  update public.publicacoes set status = 'pendente', quando = now() where id = p.id;
  return jsonb_build_object('ok', true, 'status', 'pendente');
end $$;

-- ---------- moderação: lista com vídeo e parecer da IA ----------
drop function if exists public.listar_mural(text, text);
create or replace function public.listar_mural(p_ed text, p_status text default 'pendente')
returns table (id bigint, texto text, tem_foto boolean, video text, alvo_tipo text, alvo text, quando timestamptz, status text, ia_parecer text, ia_motivo text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.pode_moderar() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return query select p.id, p.texto, p.foto is not null, p.video_path, p.alvo_tipo, public._nome_alvo(p.alvo_tipo, p.alvo_id), p.quando, p.status, p.ia_parecer, p.ia_motivo
    from public.publicacoes p where p.ed = p_ed and p.status = coalesce(p_status, 'pendente') order by p.id limit 300;
end $$;

create or replace function public.mural_telao(p_ed text, p_depois bigint default 0)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.sou_equipe() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return jsonb_build_object(
    'publicacoes', coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'texto', p.texto, 'tem_foto', p.foto is not null, 'video', p.video_path,
        'alvo_tipo', p.alvo_tipo, 'alvo', public._nome_alvo(p.alvo_tipo, p.alvo_id), 'pos', public._posicao(p.alvo_tipo, p.alvo_id),
        'quando', p.quando) order by p.id)
      from (select * from public.publicacoes where ed = p_ed and status = 'aprovado' and id > coalesce(p_depois, 0) order by id desc limit 60) p), '[]'),
    'em_alta', public._em_alta(p_ed),
    'assuntos', public._assuntos(p_ed),
    'planta', (select jsonb_build_object('url', imagem_url, 'largura', largura, 'altura', altura) from public.plantas
                where ed = p_ed and ativa and excluido_em is null order by criado_em desc limit 1),
    'lotes', coalesce((select jsonb_agg(poligono) from public.lotes where ed = p_ed and excluido_em is null and poligono is not null), '[]'));
end $$;

-- ---------- configuração da IA de moderação ----------
create table if not exists public.config_ia (
  id            int primary key default 1 check (id = 1),
  provedor      text not null default 'ceia_lumi',
  url           text check (url ~ '^https://[A-Za-z0-9.-]+(:[0-9]+)?(/[^ ]*)?$' and char_length(url) <= 300),
  modelo        text check (char_length(modelo) <= 80),
  modo          text not null default 'desligada' check (modo in ('desligada','sugerir','automatica')),
  chave_em      timestamptz,
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
alter table public.config_ia enable row level security;
revoke all on table public.config_ia from anon, authenticated, public;
insert into public.config_ia (id) values (1) on conflict (id) do nothing;

-- só o administrador geral grava; a chave só entra, nunca sai
create or replace function public.definir_config_ia(p_url text, p_modelo text, p_modo text, p_chave text default null)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
begin
  if not public.sou_admin_geral() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  if coalesce(p_modo, '') not in ('desligada','sugerir','automatica') then raise exception 'modo_invalido' using errcode = 'P0001'; end if;
  if nullif(trim(coalesce(p_url, '')), '') is null and p_modo <> 'desligada' then raise exception 'url_invalida' using errcode = 'P0001'; end if;
  begin
    update public.config_ia set url = nullif(trim(coalesce(p_url, '')), ''), modelo = nullif(trim(coalesce(p_modelo, '')), ''), modo = p_modo,
           atualizado_em = now(), atualizado_por = auth.uid() where id = 1;
  exception when check_violation then raise exception 'url_invalida' using errcode = 'P0001';
  end;
  if nullif(trim(coalesce(p_chave, '')), '') is not null then
    if char_length(p_chave) > 500 then raise exception 'chave_invalida' using errcode = 'P0001'; end if;
    insert into public._segredos (nome, valor) values ('ia_chave', trim(p_chave)) on conflict (nome) do update set valor = excluded.valor;
    update public.config_ia set chave_em = now() where id = 1;
  end if;
  if p_modo <> 'desligada' and not exists (select 1 from public._segredos where nome = 'ia_chave') then raise exception 'falta_chave' using errcode = 'P0001'; end if;
  insert into public.auditoria (quem, tabela, registro, acao, depois) values (auth.uid(), 'config_ia', '1', 'configurar', jsonb_build_object('modo', p_modo, 'url', p_url, 'chave_trocada', p_chave is not null));
  return public.info_config_ia();
end $$;

create or replace function public.info_config_ia()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.pode_moderar() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return (select jsonb_build_object('provedor', provedor, 'url', url, 'modelo', modelo, 'modo', modo,
            'tem_chave', exists (select 1 from public._segredos where nome = 'ia_chave'), 'chave_em', chave_em, 'atualizado_em', atualizado_em)
            from public.config_ia where id = 1);
end $$;

-- parecer da IA: gravado só pelo serviço de moderação (sem permissão para o navegador)
create or replace function public.registrar_parecer_ia(p_id bigint, p_parecer text, p_motivo text default null)
returns text language plpgsql volatile security definer set search_path = '' as $$
declare v_modo text; v_status text;
begin
  if coalesce(p_parecer, '') not in ('aprovar','recusar','revisar') then raise exception 'parecer_invalido' using errcode = 'P0001'; end if;
  select modo into v_modo from public.config_ia where id = 1;
  update public.publicacoes set ia_parecer = p_parecer, ia_motivo = left(p_motivo, 500), ia_em = now(),
         status = case when v_modo = 'automatica' and status = 'pendente' and p_parecer = 'aprovar' then 'aprovado'
                       when v_modo = 'automatica' and status = 'pendente' and p_parecer = 'recusar' then 'recusado' else status end
   where id = p_id returning status into v_status;
  if not found then raise exception 'publicacao_invalida' using errcode = 'P0001'; end if;
  return v_status;
end $$;

-- limpeza: devolve também os arquivos de vídeo, para o app apagá-los do depósito
create or replace function public.videos_da_edicao(p_ed text)
returns setof text language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.sou_admin_geral() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return query select video_path from public.publicacoes where ed = p_ed and video_path is not null;
end $$;

-- ---------- depósito privado dos vídeos (só no Supabase) ----------
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values ('mural-videos', 'mural-videos', false, 12582912, array['video/mp4','video/webm','video/quicktime'])
    on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
    execute 'drop policy if exists videos_envia on storage.objects';
    execute 'drop policy if exists videos_le on storage.objects';
    execute 'drop policy if exists videos_apaga on storage.objects';
    execute $p$create policy videos_envia on storage.objects for insert to anon, authenticated
             with check (bucket_id = 'mural-videos' and (select public._video_reservado(name)))$p$;
    execute $p$create policy videos_le on storage.objects for select to authenticated
             using (bucket_id = 'mural-videos' and (select public._video_legivel(name)))$p$;
    execute $p$create policy videos_apaga on storage.objects for delete to authenticated
             using (bucket_id = 'mural-videos' and (select public.pode_moderar()))$p$;
    -- plantas: imagem SVG pode carregar código; fica fora dos tipos aceitos
    update storage.buckets set allowed_mime_types = array['image/png','image/jpeg','image/webp'] where id = 'plantas';
  end if;
end $$;

revoke all on function public.reservar_video(text, text, uuid, text, text, int, numeric) from public, anon, authenticated;
revoke all on function public._video_reservado(text)             from public, anon, authenticated;
revoke all on function public._video_legivel(text)               from public, anon, authenticated;
revoke all on function public.confirmar_video(text, bigint)      from public, anon, authenticated;
revoke all on function public.listar_mural(text, text)           from public, anon, authenticated;
revoke all on function public.mural_telao(text, bigint)          from public, anon, authenticated;
revoke all on function public.definir_config_ia(text, text, text, text) from public, anon, authenticated;
revoke all on function public.info_config_ia()                   from public, anon, authenticated;
revoke all on function public.registrar_parecer_ia(bigint, text, text) from public, anon, authenticated;
revoke all on function public.videos_da_edicao(text)             from public, anon, authenticated;
grant execute on function public.reservar_video(text, text, uuid, text, text, int, numeric) to anon, authenticated;
grant execute on function public._video_reservado(text)          to anon, authenticated;   -- usada pela regra do depósito
grant execute on function public._video_legivel(text)            to authenticated;         -- usada pela regra do depósito
grant execute on function public.confirmar_video(text, bigint)   to anon, authenticated;
grant execute on function public.listar_mural(text, text)        to authenticated;
grant execute on function public.mural_telao(text, bigint)       to authenticated;
grant execute on function public.definir_config_ia(text, text, text, text) to authenticated;
grant execute on function public.info_config_ia()                to authenticated;
grant execute on function public.videos_da_edicao(text)          to authenticated;
