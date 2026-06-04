create or replace function realizar_sorteio(
  p_nome      text,
  p_telefone  text,
  p_ip        text
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_telefone_limpo  text;
  v_ip_count        int;
  v_sorteio         int;
  v_premio_icone    text;
  v_premio_nome     text;
  v_premio_descricao text;
  v_codigo          text;
  v_chars           text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_existente       record;
  i                 int;
begin
  -- Normalizar telefone (apenas dígitos)
  v_telefone_limpo := regexp_replace(p_telefone, '[^0-9]', '', 'g');

  -- Validações básicas
  if length(trim(p_nome)) < 2 then
    return json_build_object('erro', 'nome_invalido');
  end if;

  if length(v_telefone_limpo) < 10 then
    return json_build_object('erro', 'telefone_invalido');
  end if;

  -- Anti-fraude: telefone já cadastrado?
  select id, premio_nome, voucher_codigo
    into v_existente
    from participantes
   where telefone = v_telefone_limpo
   limit 1;

  if found then
    return json_build_object(
      'erro',           'ja_participou',
      'premio_nome',    v_existente.premio_nome,
      'voucher_codigo', v_existente.voucher_codigo
    );
  end if;

  -- Anti-fraude: mesmo IP nas últimas 24h (máx 3 participações)
  if p_ip is not null and p_ip <> '' then
    select count(*) into v_ip_count
      from participantes
     where ip = p_ip
       and criado_em > now() - interval '24 hours';

    if v_ip_count >= 3 then
      return json_build_object('erro', 'limite_ip_atingido');
    end if;
  end if;

  -- Sorteio ponderado (1–100)
  v_sorteio := floor(random() * 100 + 1)::int;

  if    v_sorteio <= 35 then
    v_premio_icone    := '🏷️';
    v_premio_nome     := '5% de desconto';
    v_premio_descricao := 'Apresente ao caixa antes de fechar a conta';
  elsif v_sorteio <= 65 then
    v_premio_icone    := '🏷️';
    v_premio_nome     := '10% de desconto';
    v_premio_descricao := 'Apresente ao caixa antes de fechar a conta';
  elsif v_sorteio <= 77 then
    v_premio_icone    := '☕';
    v_premio_nome     := 'Café coado 150 ml';
    v_premio_descricao := 'Retire no balcão — diga o código';
  elsif v_sorteio <= 87 then
    v_premio_icone    := '☕';
    v_premio_nome     := 'Expresso';
    v_premio_descricao := 'Retire no balcão — diga o código';
  elsif v_sorteio <= 93 then
    v_premio_icone    := '🥛';
    v_premio_nome     := 'Cappuccino 200 ml';
    v_premio_descricao := 'Retire no balcão — diga o código';
  elsif v_sorteio <= 97 then
    v_premio_icone    := '🫐';
    v_premio_nome     := 'Açaizinho tradicional';
    v_premio_descricao := 'Retire no balcão — diga o código';
  else
    v_premio_icone    := '⚡';
    v_premio_nome     := 'Açaízinho energético';
    v_premio_descricao := 'Retire no balcão — diga o código';
  end if;

  -- Gerar código de voucher único
  loop
    v_codigo := 'CC-';
    for i in 1..6 loop
      v_codigo := v_codigo || substr(v_chars,
        floor(random() * length(v_chars) + 1)::int, 1);
    end loop;
    exit when not exists (
      select 1 from participantes where voucher_codigo = v_codigo
    );
  end loop;

  -- Gravar participação
  insert into participantes
    (nome, telefone, ip, premio_icone, premio_nome, premio_descricao, voucher_codigo)
  values
    (trim(p_nome), v_telefone_limpo, nullif(trim(p_ip), ''),
     v_premio_icone, v_premio_nome, v_premio_descricao, v_codigo);

  return json_build_object(
    'sucesso',          true,
    'premio_icone',     v_premio_icone,
    'premio_nome',      v_premio_nome,
    'premio_descricao', v_premio_descricao,
    'voucher_codigo',   v_codigo
  );
end;
$$;

-- Conceder execução para clientes anônimos (chave anon)
grant execute on function realizar_sorteio(text, text, text) to anon;
grant execute on function realizar_sorteio(text, text, text) to authenticated;
