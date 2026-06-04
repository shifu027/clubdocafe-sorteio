-- Extensão UUID
create extension if not exists "uuid-ossp";

-- Tabela de participantes
create table if not exists participantes (
  id            uuid default uuid_generate_v4() primary key,
  nome          text not null,
  telefone      text not null,
  ip            text,
  premio_icone  text not null,
  premio_nome   text not null,
  premio_descricao text not null,
  voucher_codigo text not null unique,
  criado_em     timestamptz default now() not null
);

-- Índices para consultas anti-fraude
create index if not exists idx_participantes_telefone  on participantes(telefone);
create index if not exists idx_participantes_ip        on participantes(ip);
create index if not exists idx_participantes_criado_em on participantes(criado_em);

-- Habilitar RLS — sem acesso direto pelo cliente
alter table participantes enable row level security;

-- Nenhuma policy de select/insert/update/delete direta
-- Tudo passa pela função RPC com SECURITY DEFINER
