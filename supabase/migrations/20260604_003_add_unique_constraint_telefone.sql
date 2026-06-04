-- Adiciona constraint UNIQUE em telefone para fechar race condition de concorrência
alter table participantes
  add constraint uq_participantes_telefone unique (telefone);
