-- Função leve para keep-alive (mantém o projeto Free acordado)
create or replace function ping()
returns json
language sql
security definer
set search_path = public
as $$
  select json_build_object('ok', true, 'ts', now());
$$;

grant execute on function ping() to anon;
