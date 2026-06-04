-- Função admin: lista participantes (requer senha)
create or replace function listar_participantes(p_senha text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_senha_correta text;
  v_max_part      int;
  v_total         bigint;
begin
  select valor into v_senha_correta
  from configuracoes where chave = 'senha_admin';

  if v_senha_correta is null or p_senha <> v_senha_correta then
    return json_build_object('erro', 'senha_invalida');
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

grant execute on function listar_participantes(text) to anon;

-- Atualiza realizar_sorteio com verificação de limite
create or replace function realizar_sorteio(
  p_nome     text,
  p_telefone text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_telefone_limpo   text;
  v_client_ip        text;
  v_ip_count         int;
  v_max_part         int;
  v_total_part       bigint;
  v_sorteio          int;
  v_premio_icone     text;
  v_premio_nome      text;
  v_premio_descricao text;
  v_codigo           text;
  v_chars            text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_existente        record;
  i                  int;
begin
  begin
    v_client_ip := trim(split_part(
      coalesce(current_setting('request.headers', true)::json->>'x-forwarded-for', ''),
      ',', 1
    ));
    if v_client_ip = '' then v_client_ip := null; end if;
  exception when others then
    v_client_ip := null;
  end;

  v_telefone_limpo := regexp_replace(p_telefone, '[^0-9]', '', 'g');

  if length(trim(p_nome)) < 2 then
    return json_build_object('erro', 'nome_invalido');
  end if;
  if length(v_telefone_limpo) < 10 then
    return json_build_object('erro', 'telefone_invalido');
  end if;

  -- Limite máximo de participantes (0 = sem limite)
  select coalesce(valor::int, 0) into v_max_part
  from configuracoes where chave = 'max_participantes';

  if v_max_part > 0 then
    select count(*) into v_total_part from participantes;
    if v_total_part >= v_max_part then
      return json_build_object('erro', 'sorteio_encerrado');
    end if;
  end if;

  if v_client_ip is not null then
    select count(*) into v_ip_count
      from participantes
     where ip = v_client_ip
       and criado_em > now() - interval '24 hours';
    if v_ip_count >= 3 then
      return json_build_object('erro', 'limite_ip_atingido');
    end if;
  end if;

  v_sorteio := floor(random() * 100 + 1)::int;

  if    v_sorteio <= 35 then v_premio_icone := '🏷️'; v_premio_nome := '5% de desconto';        v_premio_descricao := 'Apresente ao caixa antes de fechar a conta';
  elsif v_sorteio <= 65 then v_premio_icone := '🏷️'; v_premio_nome := '10% de desconto';       v_premio_descricao := 'Apresente ao caixa antes de fechar a conta';
  elsif v_sorteio <= 77 then v_premio_icone := '☕';  v_premio_nome := 'Café coado 150 ml';    v_premio_descricao := 'Retire no balcão — diga o código';
  elsif v_sorteio <= 87 then v_premio_icone := '☕';  v_premio_nome := 'Expresso';             v_premio_descricao := 'Retire no balcão — diga o código';
  elsif v_sorteio <= 93 then v_premio_icone := '🥛';  v_premio_nome := 'Cappuccino 200 ml';    v_premio_descricao := 'Retire no balcão — diga o código';
  elsif v_sorteio <= 97 then v_premio_icone := '🫐';  v_premio_nome := 'Açaizinho tradicional'; v_premio_descricao := 'Retire no balcão — diga o código';
  else                        v_premio_icone := '⚡';  v_premio_nome := 'Açaízinho energético';  v_premio_descricao := 'Retire no balcão — diga o código';
  end if;

  loop
    v_codigo := 'CC-';
    for i in 1..6 loop
      v_codigo := v_codigo || substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
    end loop;
    exit when not exists (select 1 from participantes where voucher_codigo = v_codigo);
  end loop;

  insert into participantes
    (nome, telefone, ip, premio_icone, premio_nome, premio_descricao, voucher_codigo)
  values
    (trim(p_nome), v_telefone_limpo, v_client_ip,
     v_premio_icone, v_premio_nome, v_premio_descricao, v_codigo);

  return json_build_object(
    'sucesso', true, 'premio_icone', v_premio_icone,
    'premio_nome', v_premio_nome, 'premio_descricao', v_premio_descricao,
    'voucher_codigo', v_codigo
  );

exception when unique_violation then
  select premio_nome, voucher_codigo into v_existente
  from participantes where telefone = v_telefone_limpo limit 1;
  return json_build_object(
    'erro', 'ja_participou',
    'premio_nome', v_existente.premio_nome,
    'voucher_codigo', v_existente.voucher_codigo
  );
end;
$$;
