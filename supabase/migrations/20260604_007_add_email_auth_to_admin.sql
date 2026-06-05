-- Adiciona e-mail da admin ao banco
insert into configuracoes (chave, valor) values
  ('email_admin', 'virnapereirabersot@gmail.com')
on conflict (chave) do update set valor = excluded.valor;

-- Atualiza função para exigir e-mail + senha (dupla validação)
create or replace function listar_participantes(p_email text, p_senha text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email_correto text;
  v_senha_correta text;
  v_max_part      int;
  v_total         bigint;
begin
  select valor into v_email_correto
  from configuracoes where chave = 'email_admin';

  select valor into v_senha_correta
  from configuracoes where chave = 'senha_admin';

  if v_email_correto is null or lower(trim(p_email)) <> lower(trim(v_email_correto)) then
    return json_build_object('erro', 'credenciais_invalidas');
  end if;

  if v_senha_correta is null or p_senha <> v_senha_correta then
    return json_build_object('erro', 'credenciais_invalidas');
  end if;

  select coalesce(valor::int, 0) into v_max_part
  from configuracoes where chave = 'max_participantes';

  select count(*) into v_total from participantes;

  return json_build_object(
    'sucesso',           true,
    'total',             v_total,
    'max_participantes', coalesce(v_max_part, 0),
    'participantes', coalesce(
      (select json_agg(
        json_build_object(
          'nome',           nome,
          'telefone',       telefone,
          'premio_icone',   premio_icone,
          'premio_nome',    premio_nome,
          'voucher_codigo', voucher_codigo,
          'criado_em',      to_char(criado_em at time zone 'America/Sao_Paulo',
                                   'DD/MM/YYYY HH24:MI')
        ) order by criado_em desc
      ) from participantes),
      '[]'::json
    )
  );
end;
$$;

drop function if exists listar_participantes(text);

grant execute on function listar_participantes(text, text) to anon;
