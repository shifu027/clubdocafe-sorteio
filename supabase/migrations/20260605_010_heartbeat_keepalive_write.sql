-- Tabela heartbeat: uma única linha, atualizada a cada ping.
-- Garante ATIVIDADE DE ESCRITA real (mais robusto que só leitura),
-- sem acumular dados.
create table if not exists heartbeat (
  id          int primary key default 1,
  ultimo_ping timestamptz not null default now(),
  total_pings bigint not null default 0,
  constraint heartbeat_single_row check (id = 1)
);

alter table heartbeat enable row level security;

insert into heartbeat (id) values (1)
on conflict (id) do nothing;

-- ping() agora escreve no heartbeat (upsert na linha única).
create or replace function ping()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total bigint;
begin
  update heartbeat
     set ultimo_ping = now(),
         total_pings = total_pings + 1
   where id = 1
  returning total_pings into v_total;

  return json_build_object('ok', true, 'ts', now(), 'pings', v_total);
end;
$$;

grant execute on function ping() to anon;
