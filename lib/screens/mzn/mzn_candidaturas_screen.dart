import 'package:flutter/material.dart';

import '../../services/candidatura_service.dart';
import '../../services/mzn_service.dart';
import '../../util/atualizacao.dart';
import '../../widgets/comum.dart';
import 'mzn_detalhe_screen.dart';

class MznCandidaturasScreen extends StatefulWidget {
  const MznCandidaturasScreen({super.key});

  @override
  State<MznCandidaturasScreen> createState() => _MznCandidaturasScreenState();
}

class _MznCandidaturasScreenState extends State<MznCandidaturasScreen> {
  late Future<List<Linha>> _futuro;
  String _filtro = 'decidir'; // decidir | seguimento | todas

  @override
  void initState() {
    super.initState();
    _futuro = MznService.listar();
    Atualizacao.versao.addListener(_recarregar);
  }

  @override
  void dispose() {
    Atualizacao.versao.removeListener(_recarregar);
    super.dispose();
  }

  void _recarregar() {
    if (!mounted) return;
    setState(() => _futuro = MznService.listar());
  }

  bool _passa(Linha c) {
    final e = c['estado'] as String;
    return switch (_filtro) {
      'decidir' => e == 'encaminhada',
      'seguimento' => e != 'encaminhada',
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Candidaturas — MZN')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 8, children: [
              for (final f in const {
                'decidir': 'Para decidir',
                'seguimento': 'Decididas e em curso',
                'todas': 'Todas',
              }.entries)
                ChoiceChip(
                  label: Text(f.value),
                  selected: _filtro == f.key,
                  onSelected: (_) => setState(() => _filtro = f.key),
                ),
            ]),
          ),
          Expanded(
            child: FutureBuilder<List<Linha>>(
              future: _futuro,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Center(
                      child: snap.hasError
                          ? Text('Erro: ${snap.error}')
                          : const CircularProgressIndicator());
                }
                final itens = snap.data!.where(_passa).toList();
                if (itens.isEmpty) {
                  return const Center(child: Text('Nada nesta lista.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: itens.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = itens[i];
                    return Card(
                      child: ListTile(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => MznDetalheScreen(candidaturaId: c['id'] as String),
                        )),
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
          ),
        ],
      ),
    );
  }
}
