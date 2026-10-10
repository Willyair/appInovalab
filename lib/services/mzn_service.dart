import '../db/database_helper.dart';
import '../models/perfil.dart';
import '../util/atualizacao.dart';
import '../util/ids.dart';
import 'auth_service.dart';
import 'candidatura_service.dart';

/// Atraso de um pagamento, com o escalão que lhe corresponde (§11).
class Atraso {
  final Linha linha;
  final int dias;
  final String escalao;
  const Atraso(this.linha, this.dias, this.escalao);
}

/// Operações da MZN (credora): decidir, formalizar, desembolsar e seguir
/// atrasos. A MZN só vê candidaturas já encaminhadas pela InovaLab (§14:
/// funções do credor separadas das da InovaLab).
class MznService {
  static const resultados = {'aprovado', 'recusado', 'mais_informacao'};

  static Perfil _exigirMzn() {
    final p = AuthService.perfilAtual;
    if (p == null || p.papel != Papel.mzn) {
      throw StateError('Só a MZN pode fazer esta operação.');
    }
    return p;
  }

  static int _indice(String estado) => CandidaturaService.ordemEstados.indexOf(estado);

  static Future<void> _log(String acao, String candId) async {
    await AuthService.registarAtividade(
        acao: acao, entidade: 'candidatura', entidadeId: candId);
    Atualizacao.notificar();
  }

  /// Candidaturas visíveis para a MZN: encaminhadas em diante, e recusadas.
  static Future<List<Linha>> listar() async {
    _exigirMzn();
    final todas = await CandidaturaService.listar();
    final limite = _indice('encaminhada');
    return todas.where((c) {
      final e = c['estado'] as String;
      return e == 'recusada' || _indice(e) >= limite;
    }).toList();
  }

  /// A MZN só abre candidaturas que lhe foram encaminhadas.
  static Future<void> _exigirVisivel(String candId) async {
    final r = await CandidaturaService.resumo(candId);
    final e = r['estado'] as String;
    if (e != 'recusada' && _indice(e) < _indice('encaminhada')) {
      throw StateError('Esta candidatura ainda não foi encaminhada à MZN.');
    }
  }

  static Future<Linha> resumo(String candId) async {
    _exigirMzn();
    await _exigirVisivel(candId);
    return CandidaturaService.resumo(candId);
  }

  /// Decide. Exige fundamentação (registo das decisões, §3). A decisão fica
  /// gravada com quem decidiu e não pode ser alterada.
  static Future<void> decidir(String candId,
      {required String resultado, required String fundamentacao}) async {
    final p = _exigirMzn();
    if (!resultados.contains(resultado)) throw StateError('Resultado inválido.');
    if (fundamentacao.trim().length < 15) {
      throw StateError('Escreve a fundamentação da decisão (mínimo 15 caracteres).');
    }
    final r = await CandidaturaService.resumo(candId);
    if (r['estado'] != 'encaminhada') {
      throw StateError('Só se decide uma candidatura encaminhada e ainda sem decisão.');
    }
    final db = await DatabaseHelper.instancia.db;
    await db.transaction((txn) async {
      await txn.insert('decisoes', {
        'id': novoId(),
        'candidatura_id': candId,
        'resultado': resultado,
        'fundamentacao': fundamentacao.trim(),
        'decisor_id': p.id,
        'decisor_papel': p.papel.name,
        'data': DateTime.now().toUtc().toIso8601String(),
      });
      final novoEstado = switch (resultado) {
        'aprovado' => 'decidida',
        'recusado' => 'recusada',
        // Volta à InovaLab para completar o que falta e encaminhar de novo.
        _ => 'risco_classificado',
      };
      await txn.update(
        'candidaturas',
        {'estado': novoEstado, 'atualizado_em': DateTime.now().toUtc().toIso8601String()},
        where: 'id = ?',
        whereArgs: [candId],
      );
    });
    await _log('decisao_$resultado', candId);
  }

  static Future<void> _mudarEstado(String candId,
      {required String de, required String para, required String acao}) async {
    _exigirMzn();
    final r = await CandidaturaService.resumo(candId);
    if (r['estado'] != de) {
      throw StateError('Estado atual: ${r['estado']}. Esta ação exige "$de".');
    }
    final db = await DatabaseHelper.instancia.db;
    await db.update(
      'candidaturas',
      {'estado': para, 'atualizado_em': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [candId],
    );
    await _log(acao, candId);
  }

  /// Contrato assinado (formalização contratual, passo 9 do fluxo).
  static Future<void> formalizar(String candId) =>
      _mudarEstado(candId, de: 'decidida', para: 'formalizada', acao: 'formalizada');

  /// Dinheiro entregue (desembolso, passo 10 do fluxo).
  static Future<void> desembolsar(String candId) =>
      _mudarEstado(candId, de: 'formalizada', para: 'desembolsada', acao: 'desembolsada');

  /// Pagamentos em falta, com o escalão do §11 (limiares em `configuracoes`).
  static Future<List<Atraso>> atrasos() async {
    _exigirMzn();
    final db = await DatabaseHelper.instancia.db;
    final cfg = {
      for (final l in await db.query('configuracoes'))
        l['chave'] as String: int.tryParse(l['valor'] as String)
    };
    final aviso = cfg['atraso_aviso_mzn_dias'] ?? 8;
    final revisao = cfg['atraso_revisao_dias'] ?? 30;
    final linhas = await db.rawQuery('''
      select p.id, p.candidatura_id, p.data_prevista, p.valor_previsto, b.nome
      from pagamentos p
      join candidaturas c on c.id = p.candidatura_id
      join beneficiarias b on b.id = c.beneficiaria_id
      where p.data_pagamento is null
      order by p.data_prevista
    ''');
    final hoje = DateTime.now();
    final saida = <Atraso>[];
    for (final l in linhas) {
      final dias = hoje.difference(DateTime.parse(l['data_prevista'] as String)).inDays;
      if (dias < 1) continue;
      final escalao = dias >= revisao
          ? 'revisao'
          : dias >= aviso
              ? 'aviso_mzn'
              : 'recente';
      saida.add(Atraso(l, dias, escalao));
    }
    saida.sort((a, b) => b.dias.compareTo(a.dias));
    return saida;
  }
}
