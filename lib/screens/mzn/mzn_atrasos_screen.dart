import 'package:flutter/material.dart';

import '../../services/mzn_service.dart';
import '../../util/atualizacao.dart';
import '../../widgets/comum.dart';
import 'mzn_detalhe_screen.dart';

class MznAtrasosScreen extends StatefulWidget {
  const MznAtrasosScreen({super.key});

  @override
  State<MznAtrasosScreen> createState() => _MznAtrasosScreenState();
}

class _MznAtrasosScreenState extends State<MznAtrasosScreen> {
  late Future<List<Atraso>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = MznService.atrasos();
    Atualizacao.versao.addListener(_recarregar);
  }

  @override
  void dispose() {
    Atualizacao.versao.removeListener(_recarregar);
    super.dispose();
  }

  void _recarregar() {
    if (!mounted) return;
    setState(() => _futuro = MznService.atrasos());
  }

  (String, Color) _rotulo(String escalao) => switch (escalao) {
        'revisao' => ('Revisão obrigatória', const Color(0xFFC62828)),
        'aviso_mzn' => ('Aviso à MZN', const Color(0xFFEF6C00)),
        _ => ('Atraso recente — InovaLab acompanha', Colors.grey),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamentos em atraso')),
      body: FutureBuilder<List<Atraso>>(
        future: _futuro,
        builder: (context, snap) {
          if (!snap.hasData) {
            return Center(
                child: snap.hasError
                    ? Text('Erro: ${snap.error}')
                    : const CircularProgressIndicator());
          }
          final itens = snap.data!;
          if (itens.isEmpty) {
            return const Center(child: Text('Sem pagamentos em atraso.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: itens.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final a = itens[i];
              final (texto, cor) = _rotulo(a.escalao);
              return Card(
                child: ListTile(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        MznDetalheScreen(candidaturaId: a.linha['candidatura_id'] as String),
                  )),
                  leading: Icon(Icons.error_outline, color: cor),
                  title: Text('${a.linha['nome']} · ${a.dias} dias'),
                  subtitle: Text(
                      '${formatarMzn(a.linha['valor_previsto'] as num)} previstos para '
                      '${soData(a.linha['data_prevista'])}\n$texto'),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
