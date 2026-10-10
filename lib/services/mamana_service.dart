import '../db/database_helper.dart';
import '../models/perfil.dart';
import '../util/atualizacao.dart';
import '../util/ids.dart';
import 'auth_service.dart';
import 'candidatura_service.dart';

/// O que a própria Mamana pode ver e fazer. Cada operação confirma que a
/// candidatura é DELA; ela nunca vê a pontuação interna nem os sinais de
/// alerta (são ferramentas de análise), mas vê o estado, os documentos, as
/// decisões com a fundamentação e os pagamentos.
class MamanaService {
  static Perfil _exigirMamana() {
    final p = AuthService.perfilAtual;
    if (p == null || p.papel != Papel.mamana) {
      throw StateError('Só a beneficiária pode ver esta informação.');
    }
    return p;
  }

  static Future<String> _minhaBeneficiaria() async {
    final p = _exigirMamana();
    final db = await DatabaseHelper.instancia.db;
    final r = await db.query('beneficiarias', where: 'perfil_id = ?', whereArgs: [p.id]);
    if (r.isEmpty) throw StateError('Ainda não tens um pedido registado.');
    return r.first['id'] as String;
  }

  static Future<List<Linha>> meusPedidos() async {
    final p = _exigirMamana();
    final db = await DatabaseHelper.instancia.db;
    return db.rawQuery('''
      select c.id, c.valor_pedido, c.prazo_meses, c.estado, c.criado_em,
             n.atividade
      from candidaturas c
      join beneficiarias b on b.id = c.beneficiaria_id
      left join negocios n on n.id = c.negocio_id
      where b.perfil_id = ?
      order by c.criado_em desc
    ''', [p.id]);
  }

  static Future<List<Linha>> documentos(String candId) async {
    await CandidaturaService.exigirBeneficiaria(candId);
    return CandidaturaService.documentos(candId);
  }

  static Future<List<Linha>> decisoes(String candId) async {
    await CandidaturaService.exigirBeneficiaria(candId);
    return CandidaturaService.decisoes(candId);
  }

  static Future<List<Linha>> pagamentos(String candId) async {
    await CandidaturaService.exigirBeneficiaria(candId);
    return CandidaturaService.pagamentos(candId);
  }

  /// A Mamana envia o ficheiro; fica "por validar" até a InovaLab conferir.
  static Future<void> enviarDocumento(String candId, String docId,
      {required String origem, required String nome}) {
    return CandidaturaService.anexarDocumento(candId, docId,
        origem: origem, nomeOriginal: nome, pelaBeneficiaria: true);
  }

  static Future<List<Linha>> minhasVendas() async {
    final ben = await _minhaBeneficiaria();
    final db = await DatabaseHelper.instancia.db;
    return db.query('vendas',
        where: 'beneficiaria_id = ?', whereArgs: [ben], orderBy: 'periodo desc');
  }

  /// Vendas que ela declara. Se a InovaLab já verificou aquele mês, não se
  /// sobrepõe.
  static Future<void> declararVenda({
    required int ano,
    required int mes,
    required double valor,
  }) async {
    final p = _exigirMamana();
    final ben = await _minhaBeneficiaria();
    final agora = DateTime.now();
    if (mes < 1 || mes > 12 || valor < 0) throw StateError('Mês ou valor inválido.');
    if (DateTime(ano, mes).isAfter(DateTime(agora.year, agora.month))) {
      throw StateError('Não podes registar vendas de um mês que ainda não chegou.');
    }
    final db = await DatabaseHelper.instancia.db;
    final periodo = DateTime(ano, mes, 1).toIso8601String();
    final ex = await db.query('vendas',
        where: 'beneficiaria_id = ? and periodo = ?', whereArgs: [ben, periodo]);
    if (ex.isEmpty) {
      await db.insert('vendas', {
        'id': novoId(),
        'beneficiaria_id': ben,
        'periodo': periodo,
        'valor': valor,
        'registado_por_papel': 'mamana',
        'estado': 'declarado',
      });
    } else if (ex.first['estado'] == 'verificado') {
      throw StateError('Esse mês já foi confirmado pela InovaLab. Fala com a equipa se estiver errado.');
    } else {
      await db.update('vendas', {'valor': valor},
          where: 'id = ?', whereArgs: [ex.first['id']]);
    }
    await AuthService.registarAtividade(
        perfilId: p.id, papel: p.papel.name, acao: 'venda_declarada');
    Atualizacao.notificar();
  }
}
