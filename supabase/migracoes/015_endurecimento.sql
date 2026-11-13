-- =====================================================================
-- Migração 015: endurecimento apontado pela revisão de segurança do Supabase (13/11/2026)
-- Rode depois da 014. Pode ser rodada de novo sem perder dados.
--
-- As funções auxiliares das regras do depósito de vídeo saem do esquema "public" (que a API
-- publica como /rest/v1/rpc/...) e vão para o esquema "privado", que a API não publica.
-- As regras do depósito continuam usando-as normalmente.
-- =====================================================================

create schema if not exists privado;
revoke all on schema privado from public;
grant usage on schema privado to anon, authenticated;

create or replace function privado.video_reservado(p_nome text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.publicacoes where video_path = p_nome and status = 'aguardando_upload' and quando > now() - interval '15 minutes')
$$;
create or replace function privado.video_legivel(p_nome text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.pode_moderar() or (public.sou_equipe() and exists (select 1 from public.publicacoes where video_path = p_nome and status = 'aprovado'))
$$;
revoke all on function privado.video_reservado(text) from public, anon, authenticated;
revoke all on function privado.video_legivel(text)   from public, anon, authenticated;
grant execute on function privado.video_reservado(text) to anon, authenticated;
grant execute on function privado.video_legivel(text)   to authenticated;

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    execute 'drop policy if exists videos_envia on storage.objects';
    execute 'drop policy if exists videos_le on storage.objects';
    execute $p$create policy videos_envia on storage.objects for insert to anon, authenticated
             with check (bucket_id = 'mural-videos' and (select privado.video_reservado(name)))$p$;
    execute $p$create policy videos_le on storage.objects for select to authenticated
             using (bucket_id = 'mural-videos' and (select privado.video_legivel(name)))$p$;
  end if;
end $$;

drop function if exists public._video_reservado(text);
drop function if exists public._video_legivel(text);
