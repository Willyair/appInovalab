import '../db/database_helper.dart';
import '../models/estatisticas.dart';
import '../models/novidade.dart';
import '../models/parceiro.dart';

const _nomesMeses = [
  'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
  'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
];

/// Estados em que o crédito já foi aprovado pela MZN.
const _estadosAprovados = ['decidida', 'formalizada', 'desembolsada', 'em_monitoria'];

class DashboardService {
  static Future<List<Novidade>> novidadesAtivas() async {
    final db = await DatabaseHelper.instancia.db;
    final linhas = await db.query(
      'novidades',
      where: 'ativa = 1',
      orderBy: 'data desc',
    );
    return linhas.map(Novidade.fromMap).toList();
  }

  static Future<List<Parceiro>> parceirosAtivos() async {
    final db = await DatabaseHelper.instancia.db;
    final linhas = await db.query(
      'parceiros',
      where: 'ativo = 1',
      orderBy: 'ordem, nome',
    );
    return linhas.map(Parceiro.fromMap).toList();
  }

  static Future<Map<String, String>> textosInstitucionais() async {
    final db = await DatabaseHelper.instancia.db;
    final linhas = await db.query('textos_institucionais');
    return {for (final l in linhas) l['chave'] as String: l['valor'] as String};
  }

  /// Indicadores da própria Mamana (beneficiária ligada ao perfil com sessão).
  static Future<EstatisticasPessoais> estatisticasPessoais(String perfilId) async {
    final db = await DatabaseHelper.instancia.db;

    final beneficiarias =
        await db.query('beneficiarias', where: 'perfil_id = ?', whereArgs: [perfilId]);
    if (beneficiarias.isEmpty) {
      return const EstatisticasPessoais(
        valorConcedido: 0,
        estadoCredito: 'Sem candidatura registada',
        totalPrevisto: 0,
        totalPago: 0,
        vendasPorMes: [],
      );
    }
    final beneficiariaId = beneficiarias.first['id'] as String;

    final candidaturas = await db.query(
      'candidaturas',
      where: 'beneficiaria_id = ?',
      whereArgs: [beneficiariaId],
      orderBy: 'criado_em desc',
    );

    double valorConcedido = 0;
    String estadoCredito = 'Sem candidatura registada';
    double totalPrevisto = 0;
    double totalPago = 0;

    if (candidaturas.isNotEmpty) {
      final atual = candidaturas.first;
      // "Valor concedido" só conta pedidos aprovados. Antes mostrava o valor
      // pedido mesmo em candidaturas só recebidas, em análise ou recusadas.
      final aprovadas =
          candidaturas.where((c) => _estadosAprovados.contains(c['estado'])).toList();
      valorConcedido =
          aprovadas.isEmpty ? 0 : (aprovadas.first['valor_pedido'] as num?)?.toDouble() ?? 0;
      estadoCredito = _rotuloEstado(atual['estado'] as String);

      final idsCandidaturas = candidaturas.map((c) => c['id'] as String).toList();
      final marcadores = List.filled(idsCandidaturas.length, '?').join(',');
      final pagamentos = await db.rawQuery(
        'select valor_previsto, valor_pago from pagamentos where candidatura_id in ($marcadores)',
        idsCandidaturas,
      );
      for (final p in pagamentos) {
        totalPrevisto += (p['valor_previsto'] as num?)?.toDouble() ?? 0;
        totalPago += (p['valor_pago'] as num?)?.toDouble() ?? 0;
      }
    }

    final vendas = await db.query(
      'vendas',
      where: 'beneficiaria_id = ?',
      whereArgs: [beneficiariaId],
      orderBy: 'periodo asc',
    );
    final vendasPorMes = vendas.map((v) {
      final data = DateTime.parse(v['periodo'] as String);
      return PontoMensal(_nomesMeses[data.month - 1], (v['valor'] as num).toDouble());
    }).toList();

    return EstatisticasPessoais(
      valorConcedido: valorConcedido,
      estadoCredito: estadoCredito,
      totalPrevisto: totalPrevisto,
      totalPago: totalPago,
      vendasPorMes: vendasPorMes,
    );
  }

  /// Indicadores acumulados de todas as Mamanas, só com números agregados.
  static Future<EstatisticasAgregadas> estatisticasAgregadas() async {
    final db = await DatabaseHelper.instancia.db;

    // Só pedidos aprovados contam como "apoiados" / "concedidos". Antes entrava
    // tudo o que não estava recusado (inclusive pedidos acabados de receber).
    final aprovados = _estadosAprovados.map((e) => "'$e'").join(',');
    final numeroMamanas = _primeiroInt(await db.rawQuery(
      "select count(distinct beneficiaria_id) as n from candidaturas where estado in ($aprovados)",
    ));

    final valorTotal = _primeiroDouble(await db.rawQuery(
      "select coalesce(sum(valor_pedido),0) as s from candidaturas where estado in ($aprovados)",
    ));

    // Compara só o dia (sem horas): um pagamento previsto para hoje ainda não
    // está em atraso. "Em dia" = pago até à data prevista; pago depois dela
    // conta como atrasado (antes contava como "em dia").
    DateTime soDia(DateTime d) => DateTime(d.year, d.month, d.day);
    final pagamentos = await db.query('pagamentos');
    final hoje = soDia(DateTime.now());
    var emDia = 0;
    var atrasados = 0;
    for (final p in pagamentos) {
      final prevista = soDia(DateTime.parse(p['data_prevista'] as String));
      final pagoEm = p['data_pagamento'] == null
          ? null
          : soDia(DateTime.parse(p['data_pagamento'] as String));
      if (pagoEm != null) {
        if (pagoEm.isAfter(prevista)) {
          atrasados++;
        } else {
          emDia++;
        }
      } else if (prevista.isBefore(hoje)) {
        atrasados++;
      }
    }

    final distribuicao = <String, int>{'baixo': 0, 'moderado': 0, 'elevado': 0};
    final classificacoes = await db.rawQuery(
      "select classificacao, count(*) as n from candidaturas where classificacao is not null group by classificacao",
    );
    for (final c in classificacoes) {
      final chave = c['classificacao'] as String;
      distribuicao[chave] = c['n'] as int;
    }

    final vendasMensais = await db.rawQuery(
      "select periodo, avg(valor) as media from vendas group by periodo order by periodo",
    );
    final crescimento = vendasMensais.map((v) {
      final data = DateTime.parse(v['periodo'] as String);
      return PontoMensal(_nomesMeses[data.month - 1], (v['media'] as num).toDouble());
    }).toList();

    return EstatisticasAgregadas(
      numeroMamanasApoiadas: numeroMamanas,
      valorTotalConcedido: valorTotal,
      pagamentosEmDia: emDia,
      pagamentosAtrasados: atrasados,
      distribuicaoRisco: distribuicao,
      crescimentoMedioNegocios: crescimento,
    );
  }

  static String _rotuloEstado(String estado) => switch (estado) {
        'recebida' => 'Candidatura recebida',
        'identidade_verificada' => 'Identidade verificada',
        'confirmacao_comunitaria' => 'Em confirmação comunitária',
        'negocio_verificado' => 'Negócio verificado',
        'analise_financeira' => 'Em análise financeira',
        'risco_classificado' => 'Risco classificado',
        'medidas_definidas' => 'Medidas definidas',
        'encaminhada' => 'Encaminhada à MZN',
        'decidida' => 'Decisão tomada',
        'recusada' => 'Candidatura recusada',
        'formalizada' => 'Crédito formalizado',
        'desembolsada' => 'Crédito desembolsado',
        'em_monitoria' => 'Em acompanhamento',
        _ => estado,
      };

  static int _primeiroInt(List<Map<String, Object?>> linhas) =>
      (linhas.first.values.first as num?)?.toInt() ?? 0;

  static double _primeiroDouble(List<Map<String, Object?>> linhas) =>
      (linhas.first.values.first as num?)?.toDouble() ?? 0;
}
