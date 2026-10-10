import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/botao_tema.dart';
import '../widgets/logo_inovalab.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback aoEntrar;

  const LoginScreen({super.key, required this.aoEntrar});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _campoLogin = TextEditingController();
  final _campoPin = TextEditingController();
  bool _aCarregar = true;
  bool _aEntrar = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    await AuthService.semearContasDemonstracao();
    setState(() => _aCarregar = false);
  }

  Future<void> _entrar() async {
    if (_aEntrar) return;
    setState(() {
      _erro = null;
      _aEntrar = true;
    });
    try {
      await AuthService.entrar(_campoLogin.text, _campoPin.text);
      widget.aoEntrar();
    } on LoginException catch (e) {
      setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _aEntrar = false);
    }
  }

  @override
  void dispose() {
    _campoLogin.dispose();
    _campoPin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_aCarregar) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [BotaoTema()],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: LogoInovalab(altura: 120)),
                const SizedBox(height: 16),
                Text(
                  'InovaLab Crédito',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Protótipo local — dados só neste aparelho',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _campoLogin,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Identificador (telefone ou código)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _campoPin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _entrar(),
                  decoration: const InputDecoration(
                    labelText: 'PIN',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _erro!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _aEntrar ? null : _entrar,
                  child: const Text('Entrar'),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Só em modo de desenvolvimento — contas de demonstração '
                    '(PIN 1234): inovalab · mzn · 258840000000',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
