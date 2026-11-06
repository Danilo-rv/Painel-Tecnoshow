-- =====================================================================
-- Migração 005: saída protegida dos tablets de coleta (decisão 24)
-- Rode depois da 004. Pode ser rodada de novo sem perder dados.
--
-- O tablet fica travado na coleta. Para sair: tocar e segurar o logotipo por 3 segundos
-- e digitar um código de 4 a 6 dígitos, definido pela coordenação para cada edição.
-- O banco guarda só o sha256 de "edição:código". O tablet só recebe esse hash se apresentar
-- a chave da coleta, e guarda o hash para conferir o código mesmo sem internet.
-- =====================================================================

alter table public.edicoes add column if not exists codigo_saida_hash text check (codigo_saida_hash ~ '^[0-9a-f]{64}$');
alter table public.edicoes add column if not exists codigo_saida_em timestamptz;

create or replace function public.definir_codigo_saida(p_ed text, p_codigo text)
returns timestamptz language plpgsql volatile security definer set search_path = '' as $$
declare v_em timestamptz := now();
begin
  if not public.sou_coordenador() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  if coalesce(p_codigo, '') !~ '^[0-9]{4,6}$' then raise exception 'codigo_invalido' using errcode = 'P0001'; end if;
  update public.edicoes set codigo_saida_hash = encode(sha256(convert_to(p_ed || ':' || p_codigo, 'UTF8')), 'hex'), codigo_saida_em = v_em
   where slug = p_ed;
  if not found then raise exception 'edicao_inexistente' using errcode = 'P0001'; end if;
  insert into public.auditoria (quem, tabela, registro, acao) values (auth.uid(), 'edicoes', p_ed, 'codigo_saida');
  return v_em;
end $$;

create or replace function public.info_codigo_saida(p_ed text)
returns timestamptz language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.sou_coordenador() then raise exception 'sem_permissao' using errcode = 'P0001'; end if;
  return (select codigo_saida_em from public.edicoes where slug = p_ed);
end $$;

-- o tablet busca o hash com a chave da coleta
create or replace function public.codigo_saida(p_ed text, p_chave text)
returns text language plpgsql stable security definer set search_path = '' as $$
declare e public.edicoes%rowtype;
begin
  select * into e from public.edicoes where slug = p_ed;
  if not found or encode(sha256(convert_to(coalesce(p_chave, ''), 'UTF8')), 'hex') <> e.chave_hash then
    raise exception 'chave_invalida' using errcode = 'P0001'; end if;
  return e.codigo_saida_hash;
end $$;

-- registro de uso do código (decisão 24: "com registro de uso na auditoria")
create or replace function public.registrar_saida(p_ed text, p_chave text, p_tablet text)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
declare e public.edicoes%rowtype;
begin
  select * into e from public.edicoes where slug = p_ed;
  if not found or encode(sha256(convert_to(coalesce(p_chave, ''), 'UTF8')), 'hex') <> e.chave_hash then
    raise exception 'chave_invalida' using errcode = 'P0001'; end if;
  if (select count(*) from public.auditoria where tabela = 'saida_tablet' and quando > now() - interval '1 hour') > 200 then return false; end if;
  insert into public.auditoria (quem, tabela, registro, acao)
  values (null, 'saida_tablet', p_ed, 'saida ' || left(regexp_replace(coalesce(p_tablet, ''), '[^A-Za-z0-9]', '', 'g'), 10));
  return true;
end $$;

revoke all on function public.definir_codigo_saida(text, text)      from public, anon, authenticated;
revoke all on function public.info_codigo_saida(text)               from public, anon, authenticated;
revoke all on function public.codigo_saida(text, text)              from public, anon, authenticated;
revoke all on function public.registrar_saida(text, text, text)     from public, anon, authenticated;
grant execute on function public.definir_codigo_saida(text, text)   to authenticated;
grant execute on function public.info_codigo_saida(text)            to authenticated;
grant execute on function public.codigo_saida(text, text)           to anon, authenticated;
grant execute on function public.registrar_saida(text, text, text)  to anon, authenticated;
