import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/perfil.dart';
import '../util/ids.dart';

class LoginException implements Exception {
  final String mensagem;
  LoginException(this.mensagem);
  @override
  String toString() => mensagem;
}

class AuthService {
  static Perfil? _perfilAtual;

  // PIN: PBKDF2-HMAC-SHA256 com salt aleatório por perfil.
  // Formato guardado: pbkdf2$<iterações>$<salt b64>$<hash b64>
  // (20 000 iterações é um compromisso para telemóveis modestos; um PIN de
  // 4 dígitos continua fraco contra quem copie a base de dados — por isso
  // há também bloqueio por tentativas e, na fase de servidor, o PIN deve
  // ser verificado lá.)
  static const _iteracoes = 20000;
  static const _maxTentativas = 5;
  static const _minutosBloqueio = 5;

  static List<int> _pbkdf2(List<int> pin, List<int> salt, int iteracoes) {
    final hmac = Hmac(sha256, pin);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < iteracoes; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    return t;
  }

  static String _hashNovo(String pin) {
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final h = _pbkdf2(utf8.encode(pin), salt, _iteracoes);
    return 'pbkdf2\$$_iteracoes\$${base64.encode(salt)}\$${base64.encode(h)}';
  }

  static bool _iguais(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var r = 0;
    for (var i = 0; i < a.length; i++) {
      r |= a[i] ^ b[i];
    }
    return r == 0;
  }

  static bool _pinConfere(String pin, String guardado) {
    if (!guardado.startsWith('pbkdf2\$')) {
      // Formato antigo (v1): SHA-256 simples. Aceite uma última vez e
      // convertido para o formato novo no login.
      return _iguais(
        utf8.encode(sha256.convert(utf8.encode(pin)).toString()),
        utf8.encode(guardado),
      );
    }
    final partes = guardado.split('\$');
    if (partes.length != 4) return false;
    final h = _pbkdf2(
      utf8.encode(pin),
      base64.decode(partes[2]),
      int.parse(partes[1]),
    );
    return _iguais(h, base64.decode(partes[3]));
  }

  /// Garante que existem 3 contas de demonstração (PIN 1234).
  /// Identificadores: `inovalab`, `mzn` e `258840000000` (a Mamana).
  static Future<void> semearContasDemonstracao() async {
    final db = await DatabaseHelper.instancia.db;
    final existentes = Sqflite.firstIntValue(
      await db.rawQuery('select count(*) from perfis'),
    );
    if (existentes != null && existentes > 0) return;

    final pin = _hashNovo('1234');
    final idInovalab = novoId();
    final idMzn = novoId();
    final idMamana = novoId();

    await db.insert('perfis', {
      'id': idInovalab,
      'nome': 'Técnico InovaLab (demo)',
      'papel': 'inovalab',
      'login': 'inovalab',
      'pin_hash': pin,
    });
    await db.insert('perfis', {
      'id': idMzn,
      'nome': 'Analista MZN (demo)',
      'papel': 'mzn',
      'login': 'mzn',
      'pin_hash': pin,
    });
    await db.insert('perfis', {
      'id': idMamana,
      'nome': 'Mamana Teste',
      'papel': 'mamana',
      'login': '258840000000',
      'telefone': '258840000000',
      'pin_hash': pin,
    });
    await db.insert('beneficiarias', {
      'id': novoId(),
      'perfil_id': idMamana,
      'nome': 'Mamana Teste',
      'telefone': '258840000000',
      'bairro': 'Bairro de teste',
    });
  }

  /// Entra com identificador + PIN. A mensagem de erro é sempre a mesma,
  /// exista ou não o identificador, para não revelar quem tem conta.
  static Future<Perfil> entrar(String login, String pin) async {
    const generico = 'Identificador ou PIN incorreto.';
    final db = await DatabaseHelper.instancia.db;
    final linhas = await db.query(
      'perfis',
      where: 'login = ? and ativo = 1',
      whereArgs: [login.trim()],
    );
    if (linhas.isEmpty) {
      // Gasta o mesmo tempo, para não distinguir "não existe" de "PIN errado".
      _pbkdf2(utf8.encode(pin), List.filled(16, 0), _iteracoes);
      throw LoginException(generico);
    }
    final p = linhas.first;
    final id = p['id'] as String;

    final bloqueadoAte = DateTime.tryParse((p['bloqueado_ate'] as String?) ?? '');
    if (bloqueadoAte != null && bloqueadoAte.isAfter(DateTime.now().toUtc())) {
      final min = bloqueadoAte.difference(DateTime.now().toUtc()).inMinutes + 1;
      throw LoginException('Demasiadas tentativas. Tenta de novo em $min min.');
    }

    if (!_pinConfere(pin, p['pin_hash'] as String)) {
      final falhas = ((p['tentativas_falhadas'] as int?) ?? 0) + 1;
      final bloquear = falhas >= _maxTentativas;
      await db.update(
        'perfis',
        {
          'tentativas_falhadas': bloquear ? 0 : falhas,
          'bloqueado_ate': bloquear
              ? DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: _minutosBloqueio))
                  .toIso8601String()
              : null,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await registarAtividade(
        perfilId: id,
        papel: p['papel'] as String,
        acao: bloquear ? 'login_bloqueado' : 'login_falhado',
      );
      throw LoginException(generico);
    }

    // Sucesso: limpa falhas e actualiza hash antigo, se for o caso.
    await db.update(
      'perfis',
      {
        'tentativas_falhadas': 0,
        'bloqueado_ate': null,
        if (!(p['pin_hash'] as String).startsWith('pbkdf2\$'))
          'pin_hash': _hashNovo(pin),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _perfilAtual = Perfil.fromMap(p);
    await registarAtividade(
      perfilId: id,
      papel: p['papel'] as String,
      acao: 'login',
    );
    return _perfilAtual!;
  }

  static String _pinAleatorio() => (1000 + Random.secure().nextInt(9000)).toString();

  /// A InovaLab cria (ou repõe) o acesso de uma beneficiária. O login é o
  /// telefone e o PIN é aleatório: mostra-se UMA vez, para ser entregue à
  /// Mamana pessoalmente. Ela deve mudá-lo no primeiro acesso.
  static Future<({String login, String pin, bool novo})> criarAcessoBeneficiaria(
      String beneficiariaId) async {
    final quem = _perfilAtual;
    if (quem == null || quem.papel != Papel.inovalab) {
      throw LoginException('Só a InovaLab cria acessos.');
    }
    final db = await DatabaseHelper.instancia.db;
    final b = await db.query('beneficiarias', where: 'id = ?', whereArgs: [beneficiariaId]);
    if (b.isEmpty) throw LoginException('Beneficiária não encontrada.');
    final tel = ((b.first['telefone'] as String?) ?? '').replaceAll(RegExp(r'\D'), '');
    if (tel.length < 9) {
      throw LoginException('Regista primeiro o telefone da Mamana (editar dados).');
    }
    final pin = _pinAleatorio();
    final hash = _hashNovo(pin);
    final perfilId = b.first['perfil_id'] as String?;

    if (perfilId != null) {
      await db.update(
        'perfis',
        {'pin_hash': hash, 'tentativas_falhadas': 0, 'bloqueado_ate': null},
        where: 'id = ?',
        whereArgs: [perfilId],
      );
      final per = await db.query('perfis', where: 'id = ?', whereArgs: [perfilId]);
      await registarAtividade(
          acao: 'acesso_reposto', entidade: 'beneficiaria', entidadeId: beneficiariaId);
      return (login: per.first['login'] as String, pin: pin, novo: false);
    }

    final existente = await db.query('perfis', where: 'login = ?', whereArgs: [tel]);
    if (existente.isNotEmpty) {
      throw LoginException('Este telefone já está associado a outra conta.');
    }
    final novoPerfil = novoId();
    await db.transaction((txn) async {
      await txn.insert('perfis', {
        'id': novoPerfil,
        'nome': b.first['nome'],
        'papel': 'mamana',
        'login': tel,
        'telefone': tel,
        'pin_hash': hash,
      });
      await txn.update('beneficiarias', {'perfil_id': novoPerfil},
          where: 'id = ?', whereArgs: [beneficiariaId]);
    });
    await registarAtividade(
        acao: 'acesso_criado', entidade: 'beneficiaria', entidadeId: beneficiariaId);
    return (login: tel, pin: pin, novo: true);
  }

  /// Cada pessoa muda o seu próprio PIN.
  static Future<void> alterarPin(String atual, String novo) async {
    final p = _perfilAtual;
    if (p == null) throw LoginException('Sessão terminada.');
    if (!RegExp(r'^\d{4,6}$').hasMatch(novo)) {
      throw LoginException('O PIN deve ter 4 a 6 números.');
    }
    if (RegExp(r'^(\d)\1+$').hasMatch(novo) || const ['1234', '4321', '123456'].contains(novo)) {
      throw LoginException('PIN fácil de adivinhar. Escolhe outro.');
    }
    final db = await DatabaseHelper.instancia.db;
    final r = await db.query('perfis', where: 'id = ?', whereArgs: [p.id]);
    if (r.isEmpty || !_pinConfere(atual, r.first['pin_hash'] as String)) {
      throw LoginException('O PIN atual está incorreto.');
    }
    await db.update('perfis', {'pin_hash': _hashNovo(novo)}, where: 'id = ?', whereArgs: [p.id]);
    await registarAtividade(acao: 'pin_alterado');
  }

  /// Acrescenta uma linha ao registo de atividade (só de acrescentar).
  static Future<void> registarAtividade({
    String? perfilId,
    String? papel,
    required String acao,
    String? entidade,
    String? entidadeId,
  }) async {
    final db = await DatabaseHelper.instancia.db;
    await db.insert('registo_atividade', {
      'id': novoId(),
      'perfil_id': perfilId ?? _perfilAtual?.id,
      'papel': papel ?? _perfilAtual?.papel.name,
      'acao': acao,
      'entidade': entidade,
      'entidade_id': entidadeId,
    });
  }

  static Perfil? get perfilAtual => _perfilAtual;

  static void sair() {
    final p = _perfilAtual;
    _perfilAtual = null;
    if (p != null) {
      registarAtividade(perfilId: p.id, papel: p.papel.name, acao: 'logout');
    }
  }
}
