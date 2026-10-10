/// Migração v2: lacunas entre o documento "Análise e Gestão de Risco de
/// Crédito" e o schema v1. Uma instrução por entrada.
///
/// Corre em `onUpgrade` (v1 -> v2) e também em `onCreate` (base nova),
/// logo a seguir às tabelas da v1.
const List<String> migracaoV2Sql = [
  // ---------- Listas fixas (substituem texto livre) ----------
  '''
  create table tipos_documento (
    codigo       text primary key,
    titulo       text not null,
    obrigatorio  integer not null default 1
  )
  ''',
  '''
  insert into tipos_documento (codigo, titulo, obrigatorio) values
    ('identificacao',        'Documento de identificação válido', 1),
    ('declaracao_bairro',    'Declaração do bairro', 1),
    ('recibo_energia_agua',  'Recibo de energia/água em nome do titular', 0),
    ('confirmacao_lideres',  'Confirmação dos líderes locais', 1),
    ('prova_negocio',        'Prova da existência e funcionamento do negócio', 1),
    ('plano_negocio',        'Ficha ou plano do negócio', 1),
    ('termo_compromisso',    'Termo de compromisso da beneficiária', 1),
    ('termo_garantia',       'Termo de garantia documental (quando exigido pela MZN)', 0)
  ''',
  '''
  create table tipos_sinal_alerta (
    codigo            text primary key,
    titulo            text not null,
    grave_por_defeito integer not null default 0
  )
  ''',
  '''
  insert into tipos_sinal_alerta (codigo, titulo, grave_por_defeito) values
    ('informacoes_contraditorias',  'Informações contraditórias', 1),
    ('negocio_nao_localizado',      'Negócio não localizado', 1),
    ('documentos_em_falta',         'Ausência injustificada de documentos essenciais', 1),
    ('finalidade_pouco_clara',      'Finalidade comercial pouco clara', 0),
    ('fluxo_incompativel',          'Fluxo de caixa incompatível com a obrigação', 1),
    ('endividamento_elevado',       'Endividamento elevado', 0),
    ('mudancas_frequentes',         'Alterações frequentes de atividade ou localização sem explicação', 0),
    ('desvio_finalidade',           'Utilização dos recursos para finalidade diferente da acordada', 1)
  ''',

  // ---------- Perfis: login por identificador, PIN com salt, bloqueio ----------
  "alter table perfis add column login text",
  "alter table perfis add column tentativas_falhadas integer not null default 0",
  "alter table perfis add column bloqueado_ate text",
  '''
  update perfis set login = case papel
    when 'inovalab' then 'inovalab'
    when 'mzn' then 'mzn'
    else coalesce(telefone, id) end
  where login is null
  ''',
  "create unique index idx_perfis_login on perfis(login)",

  // ---------- Decisões: quem decidiu ----------
  "alter table decisoes add column decisor_id text references perfis(id)",
  "alter table decisoes add column decisor_papel text",

  // ---------- Líderes dos mercados e confirmação comunitária (§5) ----------
  '''
  create table lideres_mercado (
    id        text primary key,
    nome      text not null,
    mercado   text not null,
    contacto  text,
    ativo     integer not null default 1
  )
  ''',
  '''
  create table confirmacoes_lideres (
    id              text primary key,
    candidatura_id  text not null references candidaturas(id) on delete cascade,
    lider_id        text not null references lideres_mercado(id),
    facto           text not null check (facto in ('existencia','localizacao','atividade')),
    confirmado      integer not null,
    notas           text,
    data            text not null default (datetime('now'))
  )
  ''',

  // ---------- Declaração do bairro (§4) ----------
  '''
  create table declaracoes_bairro (
    id              text primary key,
    candidatura_id  text not null references candidaturas(id) on delete cascade,
    emitida_por     text not null,
    data_emissao    text not null,
    validade        text,
    ficheiro_path   text,
    observacao      text
  )
  ''',

  // ---------- Termos de compromisso e garantia documental (§9) ----------
  '''
  create table termos (
    id              text primary key,
    candidatura_id  text not null references candidaturas(id) on delete cascade,
    tipo            text not null check (tipo in ('compromisso','garantia_documental')),
    estado          text not null default 'preparado'
                    check (estado in ('preparado','assinado','revogado')),
    valor           real,
    prazo_meses     integer,
    juridicamente_validado integer not null default 0,
    ficheiro_path   text,
    assinado_em     text
  )
  ''',

  // ---------- Fichas de visita padronizadas (§10) ----------
  '''
  create table fichas_visita (
    id                     text primary key,
    candidatura_id         text not null references candidaturas(id) on delete cascade,
    fase                   text not null check (fase in ('pre_credito','pos_credito')),
    local_confirmado       integer not null,
    atividade_confirmada   integer not null,
    stock_observado        text,
    equipamentos           text,
    volume_aproximado      text,
    recursos_bem_usados    integer,
    notas                  text,
    feita_por              text not null references perfis(id),
    data                   text not null default (datetime('now'))
  )
  ''',

  // ---------- Monitoria após o financiamento (§11) ----------
  '''
  create table acoes_monitoria (
    id              text primary key,
    candidatura_id  text not null references candidaturas(id) on delete cascade,
    tipo            text not null check (tipo in
                      ('contacto','visita','alerta_atraso','plano_recuperacao','outra')),
    descricao       text not null,
    feita_por       text not null references perfis(id),
    data            text not null default (datetime('now'))
  )
  ''',

  // ---------- Registo de atividade (quem fez o quê) ----------
  '''
  create table registo_atividade (
    id           text primary key,
    perfil_id    text references perfis(id),
    papel        text,
    acao         text not null,
    entidade     text,
    entidade_id  text,
    data         text not null default (datetime('now'))
  )
  ''',

  // ---------- Integridade que o SQLite não deixa pôr com ALTER ----------
  // Pontuação: máximos do §8 (20/20/25/15/10/10 = 100).
  '''
  create trigger pontuacoes_limites_ins before insert on pontuacoes
  when new.documentacao not between 0 and 20 or new.negocio not between 0 and 20
    or new.capacidade not between 0 and 25 or new.historico not between 0 and 15
    or new.finalidade not between 0 and 10 or new.comunitaria not between 0 and 10
  begin select raise(abort, 'Pontuação fora dos limites (20/20/25/15/10/10).'); end
  ''',
  '''
  create trigger pontuacoes_limites_upd before update on pontuacoes
  when new.documentacao not between 0 and 20 or new.negocio not between 0 and 20
    or new.capacidade not between 0 and 25 or new.historico not between 0 and 15
    or new.finalidade not between 0 and 10 or new.comunitaria not between 0 and 10
  begin select raise(abort, 'Pontuação fora dos limites (20/20/25/15/10/10).'); end
  ''',
  // Sinais de alerta e documentos só aceitam códigos das listas fixas.
  '''
  create trigger sinais_tipo_valido before insert on sinais_alerta
  when not exists (select 1 from tipos_sinal_alerta where codigo = new.tipo)
  begin select raise(abort, 'Tipo de sinal de alerta inválido.'); end
  ''',
  '''
  create trigger documentos_tipo_valido before insert on documentos_candidatura
  when not exists (select 1 from tipos_documento where codigo = new.tipo)
  begin select raise(abort, 'Tipo de documento inválido.'); end
  ''',
  // Toda a decisão tem de dizer quem a tomou (§3: registo das decisões).
  '''
  create trigger decisoes_com_decisor before insert on decisoes
  when new.decisor_id is null or new.decisor_papel is null
  begin select raise(abort, 'A decisão tem de identificar quem decidiu.'); end
  ''',
  // Decisões e atividade não se alteram nem se apagam (arquivo auditável).
  '''
  create trigger decisoes_imutaveis_upd before update on decisoes
  begin select raise(abort, 'Decisões não podem ser alteradas.'); end
  ''',
  '''
  create trigger decisoes_imutaveis_del before delete on decisoes
  when exists (select 1 from candidaturas where id = old.candidatura_id)
  begin select raise(abort, 'Decisões não podem ser apagadas.'); end
  ''',
  '''
  create trigger atividade_imutavel_upd before update on registo_atividade
  begin select raise(abort, 'O registo de atividade é só de acrescentar.'); end
  ''',
  '''
  create trigger atividade_imutavel_del before delete on registo_atividade
  begin select raise(abort, 'O registo de atividade é só de acrescentar.'); end
  ''',
];
