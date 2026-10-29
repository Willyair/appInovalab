import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'schema.dart';
import 'schema_v2.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instancia = DatabaseHelper._();

  Future<Database>? _abertura;

  /// Guarda a abertura em curso (e não só o resultado), para que dois pedidos
  /// em simultâneo não abram a base duas vezes. Se a abertura falhar, esquece-a
  /// para ser possível tentar de novo.
  Future<Database> get db async {
    try {
      return await (_abertura ??= _abrir());
    } catch (_) {
      _abertura = null;
      rethrow;
    }
  }

  Future<Database> _abrir() async {
    // No Windows e Linux, o sqflite precisa do motor "ffi".
    // No Android, iOS e macOS, usa-se o motor normal.
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final pasta = await getDatabasesPath();
    final caminho = join(pasta, 'inovalab_credito.db');

    return openDatabase(
      caminho,
      version: 2,
      onConfigure: (db) => db.execute('pragma foreign_keys = on'),
      onCreate: (db, versao) async {
        for (final instrucao in tabelasSql) {
          await db.execute(instrucao);
        }
        for (final instrucao in seedsSql) {
          await db.execute(instrucao);
        }
        for (final instrucao in migracaoV2Sql) {
          await db.execute(instrucao);
        }
      },
      onUpgrade: (db, antiga, nova) async {
        if (antiga < 2) {
          // Tudo ou nada: se uma instrução falhar, a base fica como estava.
          await db.transaction((txn) async {
            for (final instrucao in migracaoV2Sql) {
              await txn.execute(instrucao);
            }
          });
        }
      },
    );
  }
}
