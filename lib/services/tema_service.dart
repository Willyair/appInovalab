import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';

/// Tema da aplicação (claro, escuro ou automático, que segue o telemóvel).
/// A escolha fica guardada neste aparelho e vale para todos os perfis.
class TemaService {
  static const _chave = 'tema_local';

  static final ValueNotifier<ThemeMode> modo = ValueNotifier(ThemeMode.system);

  static ThemeMode _de(String? v) => switch (v) {
        'claro' => ThemeMode.light,
        'escuro' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _para(ThemeMode m) => switch (m) {
        ThemeMode.light => 'claro',
        ThemeMode.dark => 'escuro',
        ThemeMode.system => 'sistema',
      };

  /// Lê a escolha guardada (chamar uma vez ao arrancar).
  static Future<void> carregar() async {
    try {
      final db = await DatabaseHelper.instancia.db;
      final r = await db.query('configuracoes', where: 'chave = ?', whereArgs: [_chave]);
      modo.value = _de(r.isEmpty ? null : r.first['valor'] as String);
    } catch (e) {
      // Não escondemos o erro: o ecrã de entrada volta a tentar abrir a base
      // e mostra a mensagem. Aqui só se usa o tema do sistema.
      debugPrint('TemaService.carregar: não consegui abrir a base de dados: $e');
      modo.value = ThemeMode.system;
    }
  }

  static Future<void> definir(ThemeMode novo) async {
    modo.value = novo; // muda já; guardar é secundário
    try {
      final db = await DatabaseHelper.instancia.db;
      await db.insert('configuracoes', {'chave': _chave, 'valor': _para(novo)},
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }
}
