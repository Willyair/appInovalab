import 'package:flutter/material.dart';

import '../services/candidatura_service.dart';
import '../util/atualizacao.dart';
import '../widgets/comum.dart';
import 'candidatura/candidatura_detalhe_screen.dart';
import 'candidatura/nova_candidatura_screen.dart';

class CandidaturasScreen extends StatefulWidget {
  final bool podeCriar;
  const CandidaturasScreen({super.key, required this.podeCriar});

  @override
  State<CandidaturasScreen> createState() => _CandidaturasScreenState();
}

class _CandidaturasScreenState extends State<CandidaturasScreen> {
  late Future<List<Linha>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = CandidaturaService.listar();
    Atualizacao.versao.addListener(_recarregar);
  }

  @override
  void dispose() {
    Atualizacao.versao.removeListener(_recarregar);
    super.dispose();
  }

  void _recarregar() {
    if (!mounted) return;
    setState(() => _futuro = CandidaturaService.listar());
  }

  Future<void> _abrir(String id) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CandidaturaDetalheScreen(candidaturaId: id),
    ));
    _recarregar();
  }

  Future<void> _nova() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const NovaCandidaturaScreen()),
    );
    _recarregar();
    if (id != null && mounted) await _abrir(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Candidaturas')),
      floatingActionButton: widget.podeCriar
          ? FloatingActionButton.extended(
              onPressed: _nova,
              icon: const Icon(Icons.add),
              label: const Text('Nova candidatura'),
            )
          : null,
      body: FutureBuilder<List<Linha>>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erro: ${snap.error}'));
          }
          final itens = snap.data!;
          if (itens.isEmpty) {
            return const Center(child: Text('Ainda não há candidaturas.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: itens.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = itens[i];
              return Card(
                child: ListTile(
                  onTap: () => _abrir(c['id'] as String),
                  title: Text(c['nome'] as String),
                  subtitle: Text([
                    if (c['atividade'] != null) c['atividade'] as String,
                    formatarMzn((c['valor_pedido'] as num?) ?? 0),
                    rotuloEstado(c['estado'] as String),
                  ].join(' · ')),
                  trailing: EtiquetaRisco(c['classificacao'] as String?),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
