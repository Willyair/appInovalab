/// Instruções de criação da base de dados local (SQLite).
/// Uma instrução por entrada, porque o sqflite executa uma de cada vez.
const List<String> tabelasSql = [
  '''
  create table perfis (
    id         text primary key,
    nome       text not null,
    papel      text not null check (papel in ('mzn','inovalab','mamana')),
    telefone   text,
    pin_hash   text not null,
    ativo      integer not null default 1,
    criado_em  text not null default (datetime('now'))
  )
  ''',
  '''
  create table beneficiarias (
    id                      text primary key,
    perfil_id               text references perfis(id),
    nome                    text not null,
    documento_identificacao text,
    telefone                text,
    bairro                  text,
    criado_em               text not null default (datetime('now'))
  )
  ''',
  '''
  create table negocios (
    id                       text primary key,
    beneficiaria_id          text not null references beneficiarias(id) on delete cascade,
    atividade                text not null,
    localizacao              text,
    inicio_atividade         text,
    finalidade_financiamento text
  )
  ''',
  '''
  create table candidaturas (
    id                text primary key,
    beneficiaria_id   text not null references beneficiarias(id) on delete cascade,
    negocio_id        text references negocios(id),
    valor_pedido      real,
    prazo_meses       integer,
    estado            text not null default 'recebida',
    classificacao     text,
    primeiro_credito  integer not null default 1,
    garantia_exigida  integer not null default 0,
    criado_em         text not null default (datetime('now')),
    atualizado_em     text not null default (datetime('now'))
  )
  ''',
  '''
  create table documentos_candidatura (
    id              text primary key,
    candidatura_id  text not null references candidaturas(id) on delete cascade,
    tipo            text not null,
    entregue        integer not null default 0,
    validade        text,
    observacao      text,
    ficheiro_path   text
  )
  ''',
  '''
  create table verificacoes (
    id              text primary key,
    candidatura_id  text not null references candidaturas(id) on delete cascade,
    tipo            text not null check (tipo in ('identidade','comunitaria','negocio_visita')),
    resultado       text,
    notas           text,
    data            text not null default (datetime('now'))
  )
  ''',
  '''
  create table analises_financeiras (
    id                      text primary key,
    candidatura_id          text not null unique references candidaturas(id) on delete cascade,
    vendas_mensais          real not null default 0,
    custos_mensais          real not null default 0,
    outras_dividas_mensais  real not null default 0,
    prestacao_estimada      real not null default 0,
    observacoes             text
  )
  ''',
  '''
  create table pontuacoes (
    id              text primary key,
    candidatura_id  text not null unique references candidaturas(id) on delete cascade,
    documentacao    integer not null default 0,
    negocio         integer not null default 0,
    capacidade      integer not null default 0,
    historico       integer not null default 0,
    finalidade      integer not null default 0,
    comunitaria     integer not null default 0,
    justificacao    text
  )
  ''',
  '''
  create table sinais_alerta (
    id              text primary key,
    candidatura_id  text not null references candidaturas(id) on delete cascade,
    tipo            text not null,
    grave           integer not null default 0,
    criado_em       text not null default (datetime('now'))
  )
  ''',
  '''
  create table decisoes (
    id              text primary key,
    candidatura_id  text not null references candidaturas(id) on delete cascade,
    resultado       text not null check (resultado in ('aprovado','recusado','mais_informacao')),
    fundamentacao   text not null,
    data            text not null default (datetime('now'))
  )
  ''',
  '''
  create table pagamentos (
    id              text primary key,
    candidatura_id  text not null references candidaturas(id) on delete cascade,
    data_prevista   text not null,
    valor_previsto  real not null,
    data_pagamento  text,
    valor_pago      real
  )
  ''',
  '''
  create table vendas (
    id                  text primary key,
    beneficiaria_id     text not null references beneficiarias(id) on delete cascade,
    periodo             text not null,
    valor               real not null,
    registado_por_papel text not null,
    estado              text not null default 'declarado' check (estado in ('declarado','verificado')),
    criado_em           text not null default (datetime('now'))
  )
  ''',
  '''
  create table novidades (
    id           text primary key,
    titulo       text not null,
    texto        text,
    imagem_path  text,
    ativa        integer not null default 1,
    data         text not null default (datetime('now'))
  )
  ''',
  '''
  create table parceiros (
    id         text primary key,
    nome       text not null,
    logo_path  text,
    tipo       text not null check (tipo in ('parceiro','financeiro')),
    link       text,
    ordem      integer not null default 0,
    ativo      integer not null default 1
  )
  ''',
  '''
  create table textos_institucionais (
    chave          text primary key,
    valor          text not null,
    atualizado_em  text not null default (datetime('now'))
  )
  ''',
  '''
  create table configuracoes (
    chave  text primary key,
    valor  text not null
  )
  ''',
  '''
  create table regras_documentos (
    id             text primary key,
    titulo         text not null,
    versao         text not null,
    ficheiro_path  text not null,
    em_vigor       integer not null default 1,
    data           text not null default (datetime('now'))
  )
  ''',
];

/// Valores iniciais (parâmetros e textos), inseridos depois das tabelas.
const List<String> seedsSql = [
  '''
  insert into configuracoes (chave, valor) values
    ('limiar_baixo', '75'),
    ('limiar_moderado', '50'),
    ('capacidade_minima_para_baixo', '12'),
    ('atraso_alerta_inovalab_dias', '1'),
    ('atraso_aviso_mzn_dias', '8'),
    ('atraso_revisao_dias', '30')
  ''',
  '''
  insert into textos_institucionais (chave, valor) values
    ('slogan', 'Slogan da InovaLab (editar)'),
    ('sobre_inovalab', 'Texto sobre a Fundação InovaLab (editar)'),
    ('contactos', 'Contactos da InovaLab (editar)')
  ''',
];
