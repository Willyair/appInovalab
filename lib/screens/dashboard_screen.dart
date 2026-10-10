import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/estatisticas.dart';
import '../models/novidade.dart';
import '../models/parceiro.dart';
import '../models/perfil.dart';
import '../services/dashboard_service.dart';
import '../services/demo_data_service.dart';
import '../util/atualizacao.dart';
import '../widgets/grafico_acompanhamento.dart';
import '../widgets/header_banner.dart';
import '../widgets/novidades_carousel.dart';
import '../widgets/parceiros_carousel.dart';

class DashboardScreen extends StatefulWidget {
  final Perfil perfil;
  final VoidCallback aoSair;

  const DashboardScreen({super.key, required this.perfil, required this.aoSair});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DadosDashboard {
  final List<Novidade> novidades;
  final List<Parceiro> parceiros;
  final String slogan;
  final String sobreInovalab;
  final EstatisticasPessoais? pessoais;
  final EstatisticasAgregadas? agregadas;

  _DadosDashboard({
    required this.novidades,
    required this.parceiros,
    required this.slogan,
    required this.sobreInovalab,
    this.pessoais,
    this.agregadas,
  });
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DadosDashboard> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _carregar();
    Atualizacao.versao.addListener(_recarregar);
  }

  @override
  void dispose() {
    Atualizacao.versao.removeListener(_recarregar);
    super.dispose();
  }

  void _recarregar() {
    if (!mounted) return;
    setState(() => _futuro = _carregar());
  }

  Future<_DadosDashboard> _carregar() async {
    // Semeia dados de exemplo (só na primeira vez) para haver algo nos gráficos.
    final idBeneficiariaDemo = await _idBeneficiariaMamanaTeste();
    if (idBeneficiariaDemo != null) {
      await DemoDataService.semear(beneficiariaMamanaTesteId: idBeneficiariaDemo);
    }

    final novidades = await DashboardService.novidadesAtivas();
    final parceiros = await DashboardService.parceirosAtivos();
    final textos = await DashboardService.textosInstitucionais();

    EstatisticasPessoais? pessoais;
    EstatisticasAgregadas? agregadas;
    if (widget.perfil.papel == Papel.mamana) {
      pessoais = await DashboardService.estatisticasPessoais(widget.perfil.id);
    } else {
      agregadas = await DashboardService.estatisticasAgregadas();
    }

    return _DadosDashboard(
      novidades: novidades,
      parceiros: parceiros,
      slogan: textos['slogan'] ?? 'Slogan da InovaLab',
      sobreInovalab: textos['sobre_inovalab'] ?? '',
      pessoais: pessoais,
      agregadas: agregadas,
    );
  }

  /// Procura a beneficiária "Mamana Teste" (criada automaticamente no
  /// login de demonstração), para ligar a ela os dados de exemplo.
  Future<String?> _idBeneficiariaMamanaTeste() async {
    final db = await DatabaseHelper.instancia.db;
    final linhas = await db.query(
      'beneficiarias',
      where: 'nome = ?',
      whereArgs: ['Mamana Teste'],
      limit: 1,
    );
    return linhas.isEmpty ? null : linhas.first['id'] as String;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_DadosDashboard>(
        future: _futuro,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: HeaderBanner(
                  perfil: widget.perfil,
                  slogan: d.slogan,
                  aoSair: widget.aoSair,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _Seccao(
                      titulo: 'Novidades recentes',
                      child: NovidadesCarousel(novidades: d.novidades),
                    ),
                    _Seccao(
                      titulo: widget.perfil.papel == Papel.mamana
                          ? 'O meu acompanhamento'
                          : 'Acompanhamento acumulado',
                      child: widget.perfil.papel == Papel.mamana
                          ? GraficoPessoal(dados: d.pessoais!)
                          : GraficoAgregado(dados: d.agregadas!),
                    ),
                    _Seccao(
                      titulo: 'Sobre a InovaLab',
                      child: Text(d.sobreInovalab),
                    ),
                    _Seccao(
                      titulo: 'Parceiros e financeiros',
                      child: ParceirosCarousel(parceiros: d.parceiros),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Seccao extends StatelessWidget {
  final String titulo;
  final Widget child;
  const _Seccao({required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
