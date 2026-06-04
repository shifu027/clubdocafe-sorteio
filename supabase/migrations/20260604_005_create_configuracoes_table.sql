-- Tabela de configurações (senha admin + limite de participantes)
create table if not exists configuracoes (
  chave text primary key,
  valor text not null
);

alter table configuracoes enable row level security;

-- 0 = sem limite de participantes
insert into configuracoes (chave, valor) values
  ('senha_admin',       'gerente2024'),
  ('max_participantes', '0')
on conflict (chave) do nothing;
