import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/tema_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TemaService.carregar();
  runApp(const InovaLabApp());
}

class InovaLabApp extends StatelessWidget {
  const InovaLabApp({super.key});

  static ThemeData _tema(Brightness brilho) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A0DC),
          brightness: brilho,
        ),
        useMaterial3: true,
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: TemaService.modo,
      builder: (context, modo, _) => MaterialApp(
        title: 'InovaLab Crédito',
        debugShowCheckedModeBanner: false,
        theme: _tema(Brightness.light),
        darkTheme: _tema(Brightness.dark),
        themeMode: modo,
        home: const PortaDeEntrada(),
      ),
    );
  }
}

class PortaDeEntrada extends StatefulWidget {
  const PortaDeEntrada({super.key});

  @override
  State<PortaDeEntrada> createState() => _PortaDeEntradaState();
}

class _PortaDeEntradaState extends State<PortaDeEntrada> {
  @override
  Widget build(BuildContext context) {
    final perfil = AuthService.perfilAtual;
    if (perfil == null) {
      return LoginScreen(aoEntrar: () => setState(() {}));
    }
    return HomeShell(perfil: perfil, aoSair: () => setState(() {}));
  }
}
