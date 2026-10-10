import 'package:flutter/material.dart';

import '../models/perfil.dart';
import '../services/auth_service.dart';
import 'candidaturas_screen.dart';
import 'dashboard_screen.dart';
import 'mamana/mamana_pedido_screen.dart';
import 'mamana/mamana_vendas_screen.dart';
import 'mzn/mzn_atrasos_screen.dart';
import 'mzn/mzn_candidaturas_screen.dart';

class HomeShell extends StatefulWidget {
  final Perfil perfil;
  final VoidCallback aoSair;

  const HomeShell({super.key, required this.perfil, required this.aoSair});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final dashboard = DashboardScreen(
      perfil: widget.perfil,
      aoSair: () {
        AuthService.sair();
        widget.aoSair();
      },
    );

    // InovaLab: candidaturas. MZN: decisões e atrasos.
    // Mamana: o seu pedido (estado, documentos, pagamentos) e as suas vendas.
    final List<Widget> paginas;
    final List<NavigationDestination> destinos;
    switch (widget.perfil.papel) {
      case Papel.inovalab:
        paginas = [dashboard, const CandidaturasScreen(podeCriar: true)];
        destinos = const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.folder_open), label: 'Candidaturas'),
        ];
      case Papel.mzn:
        paginas = [dashboard, const MznCandidaturasScreen(), const MznAtrasosScreen()];
        destinos = const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.gavel), label: 'Decisões'),
          NavigationDestination(icon: Icon(Icons.error_outline), label: 'Atrasos'),
        ];
      case Papel.mamana:
        paginas = [dashboard, const MamanaPedidoScreen(), const MamanaVendasScreen()];
        destinos = const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'O meu pedido'),
          NavigationDestination(icon: Icon(Icons.trending_up), label: 'Vendas'),
        ];
    }

    return Scaffold(
      body: IndexedStack(index: _indice, children: paginas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: destinos,
      ),
    );
  }
}
