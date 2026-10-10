import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../util/ids.dart';

String _id() => novoId();
String _data(DateTime d) => d.toIso8601String();
String _mes(DateTime d) => DateTime(d.year, d.month, 1).toIso8601String();

class DemoDataService {
  /// Cria conteúdo de exemplo (novidades, parceiros e algumas candidaturas,
  /// pagamentos e vendas) só se a base ainda estiver vazia dessas coisas.
  /// Serve para ver o dashboard com dados reais de imediato; apaga-se
  /// facilmente mais tarde (ver LEIA-ME).
  static Future<void> semear({required String beneficiariaMamanaTesteId}) async {
    final db = await DatabaseHelper.instancia.db;

    final jaTemNovidades = (await db.query('novidades', limit: 1)).isNotEmpty;
    if (!jaTemNovidades) {
      await db.insert('novidades', {
        'id': _id(),
        'titulo': 'Nova parceria com a MZN Microcrédito',
        'texto': 'A InovaLab e a MZN iniciam um modelo conjunto de análise de risco de crédito.',
        'ativa': 1,
      });
      await db.insert('novidades', {
        'id': _id(),
        'titulo': 'Formação para Mamanas Empreendedoras',
        'texto': 'Nova turma de capacitação em gestão de pequenos negócios.',
        'ativa': 1,
      });
    }

    final jaTemParceiros = (await db.query('parceiros', limit: 1)).isNotEmpty;
    if (!jaTemParceiros) {
      await db.insert('parceiros', {
        'id': _id(), 'nome': 'MZN Microcrédito', 'tipo': 'financeiro', 'ordem': 1,
      });
      await db.insert('parceiros', {
        'id': _id(), 'nome': 'Fundação InovaLab', 'tipo': 'parceiro', 'ordem': 2,
      });
    }

    // Mais 2 beneficiárias "de exemplo", sem conta de login, só para os
    // gráficos acumulados terem mais de um caso.
    final outras = await db.query(
      'beneficiarias',
      where: "nome in ('Felizarda Chambal','Rosa Mondlane')",
    );
    final idsOutras = <String>[];
    if (outras.isEmpty) {
      for (final nome in ['Felizarda Chambal', 'Rosa Mondlane']) {
        final id = _id();
        idsOutras.add(id);
        await db.insert('beneficiarias', {
          'id': id,
          'nome': nome,
          'bairro': 'Mercado Central',
        });
      }
    } else {
      idsOutras.addAll(outras.map((b) => b['id'] as String));
    }

    final jaTemCandidaturas = (await db.query('candidaturas', limit: 1)).isNotEmpty;
    if (!jaTemCandidaturas) {
      await _criarCandidaturaDemo(
        db,
        beneficiariaId: beneficiariaMamanaTesteId,
        valor: 15000,
        estado: 'em_monitoria',
        classificacao: 'baixo',
        comPagamentos: true,
      );
      await _criarCandidaturaDemo(
        db,
        beneficiariaId: idsOutras[0],
        valor: 8000,
        estado: 'formalizada',
        classificacao: 'moderado',
        comPagamentos: false,
      );
      await _criarCandidaturaDemo(
        db,
        beneficiariaId: idsOutras[1],
        valor: 5000,
        estado: 'desembolsada',
        classificacao: 'elevado',
        comPagamentos: false,
      );
    }

    final jaTemVendas = (await db.query('vendas', limit: 1)).isNotEmpty;
    if (!jaTemVendas) {
      final hoje = DateTime.now();
      for (var i = 5; i >= 0; i--) {
        final mes = DateTime(hoje.year, hoje.month - i, 1);
        await db.insert('vendas', {
          'id': _id(),
          'beneficiaria_id': beneficiariaMamanaTesteId,
          'periodo': _mes(mes),
          'valor': 3000 + (5 - i) * 400.0,
          'registado_por_papel': 'mamana',
          'estado': 'declarado',
        });
        await db.insert('vendas', {
          'id': _id(),
          'beneficiaria_id': idsOutras[0],
          'periodo': _mes(mes),
          'valor': 2000 + (5 - i) * 150.0,
          'registado_por_papel': 'inovalab',
          'estado': 'verificado',
        });
      }
    }
  }

  static Future<void> _criarCandidaturaDemo(
    Database db, {
    required String beneficiariaId,
    required double valor,
    required String estado,
    required String classificacao,
    required bool comPagamentos,
  }) async {
    final candidaturaId = _id();
    await db.insert('candidaturas', {
      'id': candidaturaId,
      'beneficiaria_id': beneficiariaId,
      'valor_pedido': valor,
      'prazo_meses': 6,
      'estado': estado,
      'classificacao': classificacao,
    });
    await db.insert('pontuacoes', {
      'id': _id(),
      'candidatura_id': candidaturaId,
      'documentacao': 18,
      'negocio': 17,
      'capacidade': 20,
      'historico': 10,
      'finalidade': 8,
      'comunitaria': 8,
    });
    if (comPagamentos) {
      final hoje = DateTime.now();
      await db.insert('pagamentos', {
        'id': _id(),
        'candidatura_id': candidaturaId,
        'data_prevista': _data(hoje.subtract(const Duration(days: 30))),
        'valor_previsto': 2500,
        'data_pagamento': _data(hoje.subtract(const Duration(days: 29))),
        'valor_pago': 2500,
      });
      await db.insert('pagamentos', {
        'id': _id(),
        'candidatura_id': candidaturaId,
        'data_prevista': _data(hoje),
        'valor_previsto': 2500,
      });
    }
  }
}
