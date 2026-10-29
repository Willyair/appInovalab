import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as pth;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/perfil.dart';
import '../util/atualizacao.dart';
import '../util/ids.dart';
import 'auth_service.dart';
import 'risco_service.dart';

typedef Linha = Map<String, Object?>;

/// Valores sugeridos para a ficha de pontuação (o técnico pode alterar).
class Sugestoes {
  final int documentacao;
  final int comunitaria;
  final int capacidade;
  const Sugestoes(this.documentacao, this.comunitaria, this.capacidade);
}

/// Pontuação gravada (ou null) + classificação calculada agora.
class Avaliacao {
  final Pontuacao? pontuacao;
  final String? justificacao;
  final ResultadoClassificacao? resultado;
  const Avaliacao(this.pontuacao, this.justificacao, this.resultado);
}

/// Operações da InovaLab sobre candidaturas. Quem altera tem de ser do perfil
/// "inovalab" (a decisão de crédito é da MZN — §14 do documento).
class CandidaturaService {
  static const ordemEstados = [
    'recebida',
    'identidade_verificada',
    'confirmacao_comunitaria',
    'negocio_verificado',
    'analise_financeira',
    'risco_classificado',
    'medidas_definidas',
    'encaminhada',
    'decidida',
    'formalizada',
    'desembolsada',
    'em_monitoria',
  ];

  static Future<Database> get _db => DatabaseHelper.instancia.db;

  static Perfil _exigirInovalab() {
    final p = AuthService.perfilAtual;
    if (p == null || p.papel != Papel.inovalab) {
      throw StateError('Só a equipa da InovaLab pode alterar a análise.');
    }
    return p;
  }

  /// Pagamentos e plano: tanto a InovaLab (acompanhamento) como a MZN
  /// (credora) os podem registar.
  static Perfil _exigirInovalabOuMzn() {
    final p = AuthService.perfilAtual;
    if (p == null || (p.papel != Papel.inovalab && p.papel != Papel.mzn)) {
      throw StateError('Sem permissão para registar pagamentos.');
    }
    return p;
  }

  /// Confirma que quem está com sessão é a beneficiária DONA desta candidatura.
  /// Devolve o id da beneficiária.
  static Future<String> exigirBeneficiaria(String candId) async {
    final p = AuthService.perfilAtual;
    if (p == null || p.papel != Papel.mamana) {
      throw StateError('Só a beneficiária pode fazer esta operação.');
    }
    final db = await _db;
    final r = await db.rawQuery('''
      select b.id from candidaturas c
      join beneficiarias b on b.id = c.beneficiaria_id
      where c.id = ? and b.perfil_id = ?
    ''', [candId, p.id]);
    if (r.isEmpty) throw StateError('Esta candidatura não é tua.');
    return r.first['id'] as String;
  }

  /// A análise só se altera enquanto a candidatura não foi encaminhada à MZN.
  static Future<void> _exigirAberta(String candId) async {
    final r = await resumo(candId);
    final i = ordemEstados.indexOf(r['estado'] as String);
    if (i < 0 || i >= ordemEstados.indexOf('encaminhada')) {
      throw StateError(
          'A candidatura já foi encaminhada à MZN e a análise não pode ser alterada.');
    }
  }

  /// Regista a ação e avisa os ecrãs de que os dados mudaram.
  static Future<void> _log(String acao, String candidaturaId) async {
    await AuthService.registarAtividade(
      acao: acao,
      entidade: 'candidatura',
      entidadeId: candidaturaId,
    );
    Atualizacao.notificar();
  }

  /// Só avança o estado (nunca recua).
  static Future<void> _avancar(DatabaseExecutor db, String id, String novo) async {
    final r = await db.query('candidaturas',
        columns: ['estado'], where: 'id = ?', whereArgs: [id]);
    if (r.isEmpty) return;
    final atual = ordemEstados.indexOf(r.first['estado'] as String);
    final destino = ordemEstados.indexOf(novo);
    if (atual >= 0 && destino > atual) {
      await db.update(
        'candidaturas',
        {'estado': novo, 'atualizado_em': DateTime.now().toUtc().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  // ---------------------------------------------------------------- criar

  static Future<String> criar({
    required String nome,
    required String documentoIdentificacao,
    String? telefone,
    String? bairro,
    required String atividade,
    String? localizacao,
    String? inicioAtividade,
    required String finalidade,
    required double valor,
    required int prazoMeses,
    required bool primeiroCredito,
  }) async {
    _exigirInovalab();
    final db = await _db;
    final benId = novoId();
    final negId = novoId();
    final candId = novoId();
    await db.transaction((txn) async {
      await txn.insert('beneficiarias', {
        'id': benId,
        'nome': nome.trim(),
        'documento_identificacao': documentoIdentificacao.trim(),
        'telefone': telefone?.trim(),
        'bairro': bairro?.trim(),
      });
      await txn.insert('negocios', {
        'id': negId,
        'beneficiaria_id': benId,
        'atividade': atividade.trim(),
        'localizacao': localizacao?.trim(),
        'inicio_atividade': inicioAtividade?.trim(),
        'finalidade_financiamento': finalidade.trim(),
      });
      await txn.insert('candidaturas', {
        'id': candId,
        'beneficiaria_id': benId,
        'negocio_id': negId,
        'valor_pedido': valor,
        'prazo_meses': prazoMeses,
        'primeiro_credito': primeiroCredito ? 1 : 0,
      });
      for (final t in await txn.query('tipos_documento')) {
        await txn.insert('documentos_candidatura', {
          'id': novoId(),
          'candidatura_id': candId,
          'tipo': t['codigo'],
          'entregue': 0,
        });
      }
    });
    await _log('candidatura_criada', candId);
    return candId;
  }

  // --------------------------------------------------------- editar dados

  static const _estadosQueBloqueiamEdicao = [
    'encaminhada', 'decidida', 'recusada', 'formalizada', 'desembolsada', 'em_monitoria'
  ];

  /// Corrige os dados da candidatura. Depois de decidida, já não se altera.
  static Future<void> atualizarDados(
    String candId, {
    required String nome,
    required String documentoIdentificacao,
    String? telefone,
    String? bairro,
    required String atividade,
    String? localizacao,
    String? inicioAtividade,
    required String finalidade,
    required double valor,
    required int prazoMeses,
    required bool primeiroCredito,
  }) async {
    _exigirInovalab();
    final db = await _db;
    final r = await resumo(candId);
    if (_estadosQueBloqueiamEdicao.contains(r['estado'])) {
      throw StateError('Esta candidatura já foi encaminhada à MZN e não pode ser editada.');
    }
    await db.transaction((txn) async {
      await txn.update(
        'beneficiarias',
        {
          'nome': nome.trim(),
          'documento_identificacao': documentoIdentificacao.trim(),
          'telefone': telefone?.trim(),
          'bairro': bairro?.trim(),
        },
        where: 'id = ?',
        whereArgs: [r['beneficiaria_id']],
      );
      await txn.update(
        'negocios',
        {
          'atividade': atividade.trim(),
          'localizacao': localizacao?.trim(),
          'inicio_atividade': inicioAtividade?.trim(),
          'finalidade_financiamento': finalidade.trim(),
        },
        where: 'beneficiaria_id = ?',
        whereArgs: [r['beneficiaria_id']],
      );
      await txn.update(
        'candidaturas',
        {
          'valor_pedido': valor,
          'prazo_meses': prazoMeses,
          'primeiro_credito': primeiroCredito ? 1 : 0,
          'atualizado_em': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [candId],
      );
    });
    await _log('candidatura_editada', candId);
  }

  // ------------------------------------------------------------- anexos

  static const extensoesPermitidas = {'pdf', 'jpg', 'jpeg', 'png'};
  static const tamanhoMaximoBytes = 10 * 1024 * 1024;

  static Future<String> caminhoAbsoluto(String relativo) async =>
      pth.join((await getApplicationSupportDirectory()).path, relativo);

  /// Nome para mostrar (sem o prefixo numérico que usamos para não repetir).
  static String nomeAnexo(String relativo) =>
      pth.basename(relativo).replaceFirst(RegExp(r'^\d+_'), '');

  /// Copia o ficheiro escolhido para a pasta da app e liga-o ao documento.
  static Future<void> anexarDocumento(
    String candId,
    String docId, {
    required String origem,
    required String nomeOriginal,
    bool pelaBeneficiaria = false,
}) async {
    if (pelaBeneficiaria) {
      await exigirBeneficiaria(candId);
    } else {
      _exigirInovalab();
    }
    await _exigirAberta(candId);
    final ext = pth.extension(nomeOriginal).replaceFirst('.', '').toLowerCase();
    if (!extensoesPermitidas.contains(ext)) {
      throw StateError('Formato não permitido. Usa PDF, JPG ou PNG.');
    }
    final f = File(origem);
    if (!await f.exists()) throw StateError('Não consegui ler o ficheiro escolhido.');
    if (await f.length() > tamanhoMaximoBytes) {
      throw StateError('Ficheiro demasiado grande (máximo 10 MB).');
    }
    final db = await _db;
    final doc = await db.query('documentos_candidatura',
        columns: ['ficheiro_path', 'entregue'],
        where: 'id = ? and candidatura_id = ?',
        whereArgs: [docId, candId]);
    if (doc.isEmpty) throw StateError('Documento não encontrado.');
    // A beneficiária não troca um documento que a InovaLab já validou (o ecrã
    // já esconde o botão, mas o serviço também tem de recusar).
    if (pelaBeneficiaria && doc.first['entregue'] == 1) {
      throw StateError('Este documento já foi validado pela InovaLab.');
    }

    final seguro = pth
        .basenameWithoutExtension(nomeOriginal)
        .replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '_');
    final relativo = pth.join(
        'anexos', candId, '${DateTime.now().millisecondsSinceEpoch}_$seguro.$ext');
    final destino = File(await caminhoAbsoluto(relativo));
    await destino.parent.create(recursive: true);
    await f.copy(destino.path);

    await db.update(
      'documentos_candidatura',
      // Enviado pela Mamana fica "por validar" até a InovaLab conferir.
      {'ficheiro_path': relativo, if (!pelaBeneficiaria) 'entregue': 1},
      where: 'id = ?',
      whereArgs: [docId],
    );
    final antigo = doc.first['ficheiro_path'] as String?;
    if (antigo != null) {
      try {
        await File(await caminhoAbsoluto(antigo)).delete();
      } catch (_) {}
    }
    await _log(pelaBeneficiaria ? 'documento_enviado_pela_beneficiaria' : 'documento_anexado', candId);
  }

  static Future<void> removerAnexo(String candId, String docId) async {
    _exigirInovalab();
    await _exigirAberta(candId);
    final db = await _db;
    final doc = await db.query('documentos_candidatura',
        columns: ['ficheiro_path'],
        where: 'id = ? and candidatura_id = ?',
        whereArgs: [docId, candId]);
    if (doc.isEmpty) return;
    final antigo = doc.first['ficheiro_path'] as String?;
    await db.update('documentos_candidatura', {'ficheiro_path': null},
        where: 'id = ?', whereArgs: [docId]);
    if (antigo != null) {
      try {
        await File(await caminhoAbsoluto(antigo)).delete();
      } catch (_) {}
    }
    await _log('anexo_removido', candId);
  }

  // ------------------------------------------------- acompanhamento (§11)

  static Future<List<Linha>> vendas(String candId) async {
    final db = await _db;
    final r = await resumo(candId);
    return db.query('vendas',
        where: 'beneficiaria_id = ?',
        whereArgs: [r['beneficiaria_id']],
        orderBy: 'periodo desc');
  }

  /// Vendas do mês, conferidas pela InovaLab (ficam "verificadas").
  static Future<void> registarVenda(String candId,
      {required int ano, required int mes, required double valor}) async {
    _exigirInovalab();
    if (mes < 1 || mes > 12 || valor < 0) throw StateError('Mês ou valor inválido.');
    // "26-10" (ano com 2 dígitos) gravava o ano 26 e o mês ficava fora de sítio.
    final agora = DateTime.now();
    if (ano < 2000 || DateTime(ano, mes).isAfter(DateTime(agora.year, agora.month))) {
      throw StateError('Ano ou mês fora do intervalo (usa AAAA-MM, até ao mês atual).');
    }
    final db = await _db;
    final r = await resumo(candId);
    final periodo = DateTime(ano, mes, 1).toIso8601String();
    final ex = await db.query('vendas',
        where: 'beneficiaria_id = ? and periodo = ?',
        whereArgs: [r['beneficiaria_id'], periodo]);
    if (ex.isEmpty) {
      await db.insert('vendas', {
        'id': novoId(),
        'beneficiaria_id': r['beneficiaria_id'],
        'periodo': periodo,
        'valor': valor,
        'registado_por_papel': 'inovalab',
        'estado': 'verificado',
      });
    } else {
      await db.update(
          'vendas', {'valor': valor, 'registado_por_papel': 'inovalab', 'estado': 'verificado'},
          where: 'id = ?', whereArgs: [ex.first['id']]);
    }
    await _log('venda_registada', candId);
  }

  static Future<List<Linha>> pagamentos(String candId) async {
    final db = await _db;
    return db.query('pagamentos',
        where: 'candidatura_id = ?', whereArgs: [candId], orderBy: 'data_prevista');
  }

  /// Estados em que já se pode criar o plano de pagamentos.
  static const planoPermitidoEm = ['desembolsada', 'em_monitoria'];

  /// Plano simples: prestações iguais (valor ÷ prazo), uma por mês, a começar
  /// no mês seguinte. Os juros reais são da MZN: ajustar quando houver o
  /// plano oficial.
  static Future<void> gerarPlanoPagamentos(String candId) async {
    _exigirInovalabOuMzn();
    final db = await _db;
    final r = await resumo(candId);
    // Só depois do desembolso. Antes aceitava-se "formalizada", e como o plano
    // avança o estado para "em_monitoria", o passo "desembolsada" ficava
    // saltado e a MZN já não conseguia marcar o desembolso.
    if (!planoPermitidoEm.contains(r['estado'])) {
      throw StateError('O plano só se cria depois de o crédito ser desembolsado.');
    }
    if ((await pagamentos(candId)).isNotEmpty) {
      throw StateError('Esta candidatura já tem plano de pagamentos.');
    }
    final valor = (r['valor_pedido'] as num).toDouble();
    final prazo = (r['prazo_meses'] as int?) ?? 0;
    if (prazo <= 0) throw StateError('Prazo inválido.');
    final prestacao = (valor / prazo * 100).round() / 100;
    final hoje = DateTime.now();
    final dia = hoje.day > 28 ? 28 : hoje.day;
    await db.transaction((txn) async {
      for (var i = 1; i <= prazo; i++) {
        final ultima = i == prazo;
        await txn.insert('pagamentos', {
          'id': novoId(),
          'candidatura_id': candId,
          'data_prevista': DateTime(hoje.year, hoje.month + i, dia).toIso8601String(),
          'valor_previsto':
              ultima ? ((valor - prestacao * (prazo - 1)) * 100).round() / 100 : prestacao,
        });
      }
    });
    await _avancar(db, candId, 'em_monitoria');
    await _log('plano_pagamentos_gerado', candId);
  }

  static Future<void> registarPagamento(String candId, String pagamentoId,
      {required double valor, required String data}) async {
    _exigirInovalabOuMzn();
    if (valor <= 0) throw StateError('O valor pago tem de ser positivo.');
    if (DateTime.tryParse(data.trim()) == null) {
      throw StateError('Data inválida. Usa AAAA-MM-DD.');
    }
    final db = await _db;
    final alteradas = await db.update(
      'pagamentos',
      {'valor_pago': valor, 'data_pagamento': DateTime.parse(data.trim()).toIso8601String()},
      // "data_pagamento is null": não se sobrepõe um pagamento já registado.
      where: 'id = ? and candidatura_id = ? and data_pagamento is null',
      whereArgs: [pagamentoId, candId],
    );
    // Antes: se o pagamento não existisse (ou já estivesse pago) não acontecia
    // nada, mas a app dizia que tinha corrido bem e registava a atividade.
    if (alteradas == 0) {
      throw StateError('Pagamento não encontrado ou já registado.');
    }
    await _log('pagamento_registado', candId);
  }

  static Future<List<Linha>> acoesMonitoria(String candId) async {
    final db = await _db;
    return db.query('acoes_monitoria',
        where: 'candidatura_id = ?', whereArgs: [candId], orderBy: 'data desc');
  }

  static Future<void> registarAcaoMonitoria(String candId,
      {required String tipo, required String descricao}) async {
    final p = _exigirInovalab();
    if (descricao.trim().isEmpty) throw StateError('Descreve a ação.');
    final db = await _db;
    await db.insert('acoes_monitoria', {
      'id': novoId(),
      'candidatura_id': candId,
      'tipo': tipo,
      'descricao': descricao.trim(),
      'feita_por': p.id,
      'data': DateTime.now().toUtc().toIso8601String(),
    });
    await _log('acao_monitoria', candId);
  }

  /// SÓ PARA DESENVOLVIMENTO: salta etapas para testar o acompanhamento
  /// enquanto os ecrãs da MZN não existem. Não funciona em versões finais.
  static Future<void> definirEstadoDev(String candId, String estado) async {
    if (!kDebugMode) throw StateError('Só disponível em modo de desenvolvimento.');
    _exigirInovalab();
    final db = await _db;
    await db.update('candidaturas', {'estado': estado}, where: 'id = ?', whereArgs: [candId]);
    await _log('estado_definido_dev_$estado', candId);
  }

  // --------------------------------------------------------------- leitura

  static Future<List<Linha>> listar() async {
    final db = await _db;
    return db.rawQuery('''
      select c.id, b.nome, n.atividade, c.valor_pedido, c.estado,
             c.classificacao, c.criado_em
      from candidaturas c
      join beneficiarias b on b.id = c.beneficiaria_id
      left join negocios n on n.id = c.negocio_id
      order by c.criado_em desc
    ''');
  }

  static Future<Linha> resumo(String id) async {
    final db = await _db;
    final r = await db.rawQuery('''
      select c.id, c.beneficiaria_id, c.valor_pedido, c.prazo_meses, c.estado,
             c.classificacao, c.primeiro_credito, b.nome,
             b.documento_identificacao, b.telefone, b.bairro, n.atividade,
             n.localizacao, n.inicio_atividade, n.finalidade_financiamento
      from candidaturas c
      join beneficiarias b on b.id = c.beneficiaria_id
      left join negocios n on n.id = c.negocio_id
      where c.id = ?
    ''', [id]);
    if (r.isEmpty) throw StateError('Candidatura não encontrada.');
    return r.first;
  }

  // ------------------------------------------------------------ documentos

  static Future<List<Linha>> documentos(String candId) async {
    final db = await _db;
    return db.rawQuery('''
      select d.id, d.tipo, d.entregue, d.validade, d.observacao,
             d.ficheiro_path, t.titulo, t.obrigatorio
      from documentos_candidatura d
      join tipos_documento t on t.codigo = d.tipo
      where d.candidatura_id = ?
      order by t.rowid
    ''', [candId]);
  }

  static Future<void> atualizarDocumento(
    String candId,
    String docId, {
    required bool entregue,
    String? validade,
    String? observacao,
  }) async {
    _exigirInovalab();
    await _exigirAberta(candId);
    final db = await _db;
    await db.update(
      'documentos_candidatura',
      {
        'entregue': entregue ? 1 : 0,
        'validade': (validade == null || validade.trim().isEmpty) ? null : validade.trim(),
        'observacao':
            (observacao == null || observacao.trim().isEmpty) ? null : observacao.trim(),
      },
      where: 'id = ? and candidatura_id = ?',
      whereArgs: [docId, candId],
    );
    await _log('documento_atualizado', candId);
  }

  // ----------------------------------------------------------- verificações

  static Future<List<Linha>> verificacoes(String candId) async {
    final db = await _db;
    return db.query('verificacoes',
        where: 'candidatura_id = ?', whereArgs: [candId], orderBy: 'data desc');
  }

  /// tipo: 'identidade' | 'comunitaria' | 'negocio_visita'
  /// resultado: 'conforme' | 'inconsistente'
  static Future<void> registarVerificacao(
    String candId, {
    required String tipo,
    required String resultado,
    String? notas,
  }) async {
    _exigirInovalab();
    await _exigirAberta(candId);
    final db = await _db;
    await db.insert('verificacoes', {
      'id': novoId(),
      'candidatura_id': candId,
      'tipo': tipo,
      'resultado': resultado,
      'notas': notas?.trim(),
      'data': DateTime.now().toUtc().toIso8601String(),
    });
    if (resultado == 'conforme') {
      final novo = switch (tipo) {
        'identidade' => 'identidade_verificada',
        'comunitaria' => 'confirmacao_comunitaria',
        _ => 'negocio_verificado',
      };
      await _avancar(db, candId, novo);
    }
    await _log('verificacao_$tipo', candId);
  }

  // ----------------------------------------------------- comunidade e líderes

  static Future<List<Linha>> declaracoesBairro(String candId) async {
    final db = await _db;
    return db.query('declaracoes_bairro',
        where: 'candidatura_id = ?', whereArgs: [candId], orderBy: 'data_emissao desc');
  }

  static Future<void> registarDeclaracaoBairro(
    String candId, {
    required String emitidaPor,
    required String dataEmissao,
    String? validade,
    String? observacao,
  }) async {
    _exigirInovalab();
    await _exigirAberta(candId);
    final db = await _db;
    await db.insert('declaracoes_bairro', {
      'id': novoId(),
      'candidatura_id': candId,
      'emitida_por': emitidaPor.trim(),
      'data_emissao': dataEmissao.trim(),
      'validade': (validade == null || validade.trim().isEmpty) ? null : validade.trim(),
      'observacao': observacao?.trim(),
    });
    await _log('declaracao_bairro_registada', candId);
  }

  static Future<List<Linha>> confirmacoesLideres(String candId) async {
    final db = await _db;
    return db.rawQuery('''
      select c.id, c.facto, c.confirmado, c.notas, c.data, l.nome, l.mercado
      from confirmacoes_lideres c
      join lideres_mercado l on l.id = c.lider_id
      where c.candidatura_id = ?
      order by c.data desc, l.nome
    ''', [candId]);
  }

  /// O líder só confirma factos verificáveis (§5): existência, localização
  /// aproximada e atividade. Nunca é garantia financeira.
  static Future<void> registarConfirmacaoLider(
    String candId, {
    required String nomeLider,
    required String mercado,
    String? contacto,
    required Map<String, bool> factos,
    String? notas,
  }) async {
    _exigirInovalab();
    await _exigirAberta(candId);
    final db = await _db;
    final dataAgora = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      final existente = await txn.query('lideres_mercado',
          where: 'nome = ? and mercado = ?',
          whereArgs: [nomeLider.trim(), mercado.trim()]);
      final liderId = existente.isNotEmpty ? existente.first['id'] as String : novoId();
      if (existente.isEmpty) {
        await txn.insert('lideres_mercado', {
          'id': liderId,
          'nome': nomeLider.trim(),
          'mercado': mercado.trim(),
          'contacto': contacto?.trim(),
        });
      }
      for (final e in factos.entries) {
        await txn.insert('confirmacoes_lideres', {
          'id': novoId(),
          'candidatura_id': candId,
          'lider_id': liderId,
          'facto': e.key,
          'confirmado': e.value ? 1 : 0,
          'notas': notas?.trim(),
          'data': dataAgora,
        });
      }
    });
    await registarVerificacao(
      candId,
      tipo: 'comunitaria',
      resultado: factos.values.every((v) => v) ? 'conforme' : 'inconsistente',
      notas: 'Líder $nomeLider ($mercado)',
    );
  }

  // ------------------------------------------------------------- visitas

  static Future<List<Linha>> fichasVisita(String candId) async {
    final db = await _db;
    return db.query('fichas_visita',
        where: 'candidatura_id = ?', whereArgs: [candId], orderBy: 'data desc');
  }

  static Future<void> registarFichaVisita(
    String candId, {
    required bool localConfirmado,
    required bool atividadeConfirmada,
    String? stock,
    String? equipamentos,
    String? volume,
    String? notas,
  }) async {
    final p = _exigirInovalab();
    await _exigirAberta(candId);
    final db = await _db;
    await db.insert('fichas_visita', {
      'id': novoId(),
      'candidatura_id': candId,
      'fase': 'pre_credito',
      'local_confirmado': localConfirmado ? 1 : 0,
      'atividade_confirmada': atividadeConfirmada ? 1 : 0,
      'stock_observado': stock?.trim(),
      'equipamentos': equipamentos?.trim(),
      'volume_aproximado': volume?.trim(),
      'notas': notas?.trim(),
      'feita_por': p.id,
      'data': DateTime.now().toUtc().toIso8601String(),
    });
    await registarVerificacao(
      candId,
      tipo: 'negocio_visita',
      resultado: (localConfirmado && atividadeConfirmada) ? 'conforme' : 'inconsistente',
      notas: 'Ficha de visita',
    );
  }

  // --------------------------------------------------- análise financeira

  static Future<Linha?> analise(String candId) async {
    final db = await _db;
    final r = await db.query('analises_financeiras',
        where: 'candidatura_id = ?', whereArgs: [candId]);
    return r.isEmpty ? null : r.first;
  }

  static Future<void> guardarAnalise(
    String candId, {
    required double vendas,
    required double custos,
    required double outrasDividas,
    required double prestacao,
    String? observacoes,
  }) async {
    _exigirInovalab();
    await _exigirAberta(candId);
    final db = await _db;
    final existente = await analise(candId);
    final dados = {
      'vendas_mensais': vendas,
      'custos_mensais': custos,
      'outras_dividas_mensais': outrasDividas,
      'prestacao_estimada': prestacao,
      'observacoes': observacoes?.trim(),
    };
    if (existente == null) {
      await db.insert('analises_financeiras',
          {'id': novoId(), 'candidatura_id': candId, ...dados});
    } else {
      await db.update('analises_financeiras', dados,
          where: 'candidatura_id = ?', whereArgs: [candId]);
    }
    await _avancar(db, candId, 'analise_financeira');
    await _log('analise_financeira_guardada', candId);
  }

  // ------------------------------------------------ encaminhar à MZN (§13)

  static Future<List<Linha>> decisoes(String candId) async {
    final db = await _db;
    return db.rawQuery('''
      select d.id, d.resultado, d.fundamentacao, d.data, d.decisor_papel,
             p.nome as decisor_nome
      from decisoes d left join perfis p on p.id = d.decisor_id
      where d.candidatura_id = ? order by d.data desc
    ''', [candId]);
  }

  /// Razões que impedem de encaminhar. Lista vazia = pode encaminhar.
  static Future<List<String>> motivosBloqueioEncaminhar(String candId) async {
    final r = await resumo(candId);
    final motivos = <String>[];
    final i = ordemEstados.indexOf(r['estado'] as String);
    if (i >= ordemEstados.indexOf('encaminhada')) {
      motivos.add('Já foi encaminhada à MZN.');
      return motivos;
    }
    if (await analise(candId) == null) motivos.add('Falta a análise financeira.');
    final av = await avaliacao(candId);
    if (av.resultado == null || r['classificacao'] == null) {
      motivos.add('Falta classificar o risco (separador Risco).');
    } else if (av.resultado!.nivel.name != r['classificacao']) {
      motivos.add('A classificação está desatualizada: volta a classificar.');
    }
    final docs = await documentos(candId);
    for (final d in docs) {
      if (d['entregue'] == 0 && RiscoService.documentosEssenciais.contains(d['tipo'])) {
        motivos.add('Documento essencial em falta: ${d['titulo']}.');
      }
    }
    return motivos;
  }

  /// Passa a candidatura para a MZN decidir. A partir daqui a análise fica
  /// bloqueada (a MZN decide sobre o que viu).
  static Future<void> encaminharParaMzn(String candId) async {
    _exigirInovalab();
    final motivos = await motivosBloqueioEncaminhar(candId);
    if (motivos.isNotEmpty) throw StateError(motivos.join(' '));
    final db = await _db;
    await _avancar(db, candId, 'encaminhada');
    await _log('encaminhada_mzn', candId);
  }

  // ------------------------------------------------------ sinais de alerta

  static Future<List<Linha>> tiposSinal() async {
    final db = await _db;
    return db.query('tipos_sinal_alerta', orderBy: 'rowid');
  }

  static Future<List<Linha>> sinais(String candId) async {
    final db = await _db;
    return db.rawQuery('''
      select s.id, s.tipo, s.grave, t.titulo
      from sinais_alerta s join tipos_sinal_alerta t on t.codigo = s.tipo
      where s.candidatura_id = ?
    ''', [candId]);
  }

  static Future<void> alternarSinal(String candId, String codigo, bool ativo) async {
    _exigirInovalab();
    await _exigirAberta(candId);
    final db = await _db;
    if (ativo) {
      final t = await db.query('tipos_sinal_alerta',
          where: 'codigo = ?', whereArgs: [codigo]);
      await db.insert('sinais_alerta', {
        'id': novoId(),
        'candidatura_id': candId,
        'tipo': codigo,
        'grave': t.first['grave_por_defeito'],
      });
    } else {
      await db.delete('sinais_alerta',
          where: 'candidatura_id = ? and tipo = ?', whereArgs: [candId, codigo]);
    }
    await _log(ativo ? 'sinal_alerta_ligado' : 'sinal_alerta_removido', candId);
  }

  // ------------------------------------------------- pontuação e risco

  static Future<ParametrosRisco> parametros() async {
    final db = await _db;
    final linhas = await db.query('configuracoes');
    final m = {for (final l in linhas) l['chave'] as String: l['valor'] as String};
    const d = ParametrosRisco();
    return ParametrosRisco(
      limiarBaixo: int.tryParse(m['limiar_baixo'] ?? '') ?? d.limiarBaixo,
      limiarModerado: int.tryParse(m['limiar_moderado'] ?? '') ?? d.limiarModerado,
      capacidadeMinimaParaBaixo: int.tryParse(m['capacidade_minima_para_baixo'] ?? '') ??
          d.capacidadeMinimaParaBaixo,
    );
  }

  static Pontuacao _pontuacaoDe(Linha l) => Pontuacao(
        documentacao: l['documentacao'] as int,
        negocio: l['negocio'] as int,
        capacidade: l['capacidade'] as int,
        historico: l['historico'] as int,
        finalidade: l['finalidade'] as int,
        comunitaria: l['comunitaria'] as int,
      );

  static Future<Avaliacao> avaliacao(String candId) async {
    final db = await _db;
    final r = await db.query('pontuacoes',
        where: 'candidatura_id = ?', whereArgs: [candId]);
    if (r.isEmpty) return const Avaliacao(null, null, null);
    final pont = _pontuacaoDe(r.first);

    final docs = await documentos(candId);
    final emFalta = docs.where((d) => d['entregue'] == 0).toList();
    final essenciais = emFalta
        .where((d) => RiscoService.documentosEssenciais.contains(d['tipo']))
        .map((d) => d['titulo'] as String)
        .toList();
    final obrigatorios = emFalta
        .where((d) =>
            d['obrigatorio'] == 1 && !RiscoService.documentosEssenciais.contains(d['tipo']))
        .map((d) => d['titulo'] as String)
        .toList();

    final sin = await sinais(candId);
    final resultado = RiscoService.classificar(
      pontuacao: pont,
      parametros: await parametros(),
      sinaisGraves: sin.where((s) => s['grave'] == 1).map((s) => s['titulo'] as String).toList(),
      sinaisLeves: sin.where((s) => s['grave'] != 1).map((s) => s['titulo'] as String).toList(),
      documentosEssenciaisEmFalta: essenciais,
      documentosObrigatoriosEmFalta: obrigatorios,
    );
    return Avaliacao(pont, r.first['justificacao'] as String?, resultado);
  }

  static Future<Sugestoes> sugestoes(String candId) async {
    final docs = await documentos(candId);
    final obrig = docs.where((d) => d['obrigatorio'] == 1).toList();
    final entregues = obrig.where((d) => d['entregue'] == 1).length;
    final sugDoc = obrig.isEmpty ? 0 : (20 * entregues / obrig.length).round();

    final conf = await confirmacoesLideres(candId);
    final bairro = await declaracoesBairro(candId);
    final ratio = conf.isEmpty
        ? 0.0
        : conf.where((c) => c['confirmado'] == 1).length / conf.length;
    final sugCom = ((6 * ratio) + (bairro.isNotEmpty ? 4 : 0)).round();

    final a = await analise(candId);
    final sugCap = a == null
        ? 0
        : RiscoService.sugerirCapacidade(RiscoService.cobertura(
            vendas: (a['vendas_mensais'] as num).toDouble(),
            custos: (a['custos_mensais'] as num).toDouble(),
            outrasDividas: (a['outras_dividas_mensais'] as num).toDouble(),
            prestacao: (a['prestacao_estimada'] as num).toDouble(),
          ));
    return Sugestoes(sugDoc, sugCom, sugCap);
  }

  /// Guarda a pontuação e a justificação, e devolve a classificação.
  /// A justificação é obrigatória (§3: registo das decisões).
  static Future<Avaliacao> guardarPontuacaoEClassificar(
    String candId, {
    required Pontuacao pontuacao,
    required String justificacao,
  }) async {
    _exigirInovalab();
    await _exigirAberta(candId);
    if (justificacao.trim().isEmpty) {
      throw StateError('Escreve a justificação da pontuação.');
    }
    final invalida = pontuacao.dimensaoInvalida();
    if (invalida != null) {
      throw StateError('Valor fora dos limites em: ${Pontuacao.rotulos[invalida]}.');
    }
    final db = await _db;
    final dados = {
      'documentacao': pontuacao.documentacao,
      'negocio': pontuacao.negocio,
      'capacidade': pontuacao.capacidade,
      'historico': pontuacao.historico,
      'finalidade': pontuacao.finalidade,
      'comunitaria': pontuacao.comunitaria,
      'justificacao': justificacao.trim(),
    };
    final ex = await db.query('pontuacoes',
        where: 'candidatura_id = ?', whereArgs: [candId]);
    if (ex.isEmpty) {
      await db.insert('pontuacoes', {'id': novoId(), 'candidatura_id': candId, ...dados});
    } else {
      await db.update('pontuacoes', dados,
          where: 'candidatura_id = ?', whereArgs: [candId]);
    }
    final av = await avaliacao(candId);
    await db.update(
      'candidaturas',
      {
        'classificacao': av.resultado!.nivel.name,
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [candId],
    );
    await _avancar(db, candId, 'risco_classificado');
    await _log('risco_classificado_${av.resultado!.nivel.name}', candId);
    return av;
  }
}
