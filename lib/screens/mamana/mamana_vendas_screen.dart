import 'package:flutter/material.dart';

import '../../services/candidatura_service.dart';
import '../../services/mamana_service.dart';
import '../../util/atualizacao.dart';
import '../../widgets/comum.dart';

class MamanaVendasScreen extends StatefulWidget {
  const MamanaVendasScreen({super.key});

  @override
  State<MamanaVendasScreen> createState() => _MamanaVendasScreenState();
}

class _MamanaVendasScreenState extends State<MamanaVendasScreen> {
  late Future<List<Linha>> _futuro;

  static const _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    _futuro = MamanaService.minhasVendas();
    Atualizacao.versao.addListener(_recarregar);
  }

  @override
  void dispose() {
    Atualizacao.versao.removeListener(_recarregar);
    super.dispose();
  }

  void _recarregar() {
    if (!mounted) return;
    setState(() => _futuro = MamanaService.minhasVendas());
  }

  Future<void> _registar() async {
    final hoje = DateTime.now();
    var ano = hoje.year, mes = hoje.month;
    final valor = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Vendas do mês'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              IconButton(
                  onPressed: () => setD(() {
                        mes--;
                        if (mes < 1) {
                          mes = 12;
                          ano--;
                        }
                      }),
                  icon: const Icon(Icons.chevron_left)),
              Expanded(
                  child: Text('${_meses[mes - 1]} $ano',
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx).textTheme.titleMedium)),
              IconButton(
                  onPressed: () => setD(() {
                        mes++;
                        if (mes > 12) {
                          mes = 1;
                          ano++;
                        }
                      }),
                  icon: const Icon(Icons.chevron_right)),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: valor,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Total vendido no mês (MZN)', border: OutlineInputBorder()),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    final v = lerNumero(valor.text);
    valor.dispose();
    if (ok != true || !mounted) return;
    if (v == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Escreve o valor em números.')));
      return;
    }
    await executar(context, () => MamanaService.declararVenda(ano: ano, mes: mes, valor: v));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('As minhas vendas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _registar,
        icon: const Icon(Icons.add),
        label: const Text('Registar vendas'),
      ),
      body: FutureBuilder<List<Linha>>(
        future: _futuro,
        builder: (context, snap) {
          if (!snap.hasData) {
            return Center(
                child: snap.hasError
                    ? Padding(padding: const EdgeInsets.all(24), child: Text('${snap.error}'))
                    : const CircularProgressIndicator());
          }
          final vendas = snap.data!;
          if (vendas.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ainda não registaste vendas. Regista o total de cada mês: '
                  'ajuda a mostrar como o teu negócio cresce.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: vendas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final v = vendas[i];
              final data = DateTime.parse(v['periodo'] as String);
              final verificado = v['estado'] == 'verificado';
              return Card(
                child: ListTile(
                  leading: Icon(verificado ? Icons.verified : Icons.edit_note,
                      color: verificado ? Colors.green : null),
                  title: Text('${_meses[data.month - 1]} ${data.year}'),
                  subtitle: Text(verificado ? 'Confirmado pela InovaLab' : 'Declarado por ti'),
                  trailing: Text(formatarMzn(v['valor'] as num),
                      style: Theme.of(context).textTheme.titleSmall),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
