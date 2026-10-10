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

  Database? _db;

  Future<Database> get db async {
    _db ??= await _abrir();
    return _db!;
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
