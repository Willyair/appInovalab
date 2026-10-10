import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/candidatura_service.dart';
import '../../services/mamana_service.dart';
import '../../util/abrir_anexo.dart';
import '../../util/atualizacao.dart';
import '../../util/seletor_ficheiros.dart';
import '../../widgets/comum.dart';

class MamanaPedidoScreen extends StatefulWidget {
  const MamanaPedidoScreen({super.key});

  @override
  State<MamanaPedidoScreen> createState() => _MamanaPedidoScreenState();
}

class _MamanaPedidoScreenState extends State<MamanaPedidoScreen> {
  late Future<List<Linha>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = MamanaService.meusPedidos();
    Atualizacao.versao.addListener(_recarregar);
  }

  @override
  void dispose() {
    Atualizacao.versao.removeListener(_recarregar);
    super.dispose();
  }

  void _recarregar() {
    if (!mounted) return;
    setState(() => _futuro = MamanaService.meusPedidos());
  }

  Future<void> _alterarPin() async {
    final atual = TextEditingController();
    final novo = TextEditingController();
    final repetir = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterar PIN'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final e in [
            ('PIN atual', atual),
            ('PIN novo (4 a 6 números)', novo),
            ('Repetir PIN novo', repetir),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: e.$2,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: e.$1, border: const OutlineInputBorder()),
              ),
            ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    final a = atual.text, n = novo.text, r = repetir.text;
    atual.dispose();
    novo.dispose();
    repetir.dispose();
    if (ok != true || !mounted) return;
    if (n != r) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Os dois PIN novos não são iguais.')));
      return;
    }
    final feito = await executar(context, () => AuthService.alterarPin(a, n));
    if (feito && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('PIN alterado.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('O meu pedido'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => _alterarPin(),
            itemBuilder: (_) =>
                const [PopupMenuItem(value: 'pin', child: Text('Alterar PIN'))],
          ),
        ],
      ),
      body: FutureBuilder<List<Linha>>(
        future: _futuro,
        builder: (context, snap) {
          if (!snap.hasData) {
            return Center(
                child: snap.hasError
                    ? Text('${snap.error}')
                    : const CircularProgressIndicator());
          }
          final pedidos = snap.data!;
          if (pedidos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ainda não tens um pedido registado. Fala com a equipa da InovaLab.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [for (final p in pedidos) _PedidoCard(pedido: p)],
          );
        },
      ),
    );
  }
}

class _Dados {
  final List<Linha> documentos, decisoes, pagamentos;
  _Dados(this.documentos, this.decisoes, this.pagamentos);
}

class _PedidoCard extends StatefulWidget {
  final Linha pedido;
  const _PedidoCard({required this.pedido});

  @override
  State<_PedidoCard> createState() => _PedidoCardState();
}

class _PedidoCardState extends State<_PedidoCard> {
  late Future<_Dados> _futuro;

  String get _id => widget.pedido['id'] as String;

  static const _passos = [
    ('Pedido recebido', 'recebida'),
    ('Documentos e negócio verificados', 'negocio_verificado'),
    ('Análise concluída', 'risco_classificado'),
    ('Enviado à MZN', 'encaminhada'),
    ('Decisão da MZN', 'decidida'),
    ('Contrato assinado', 'formalizada'),
    ('Crédito entregue', 'desembolsada'),
    ('Em acompanhamento', 'em_monitoria'),
  ];

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

  Future<_Dados> _carregar() async => _Dados(
        await MamanaService.documentos(_id),
        await MamanaService.decisoes(_id),
        await MamanaService.pagamentos(_id),
      );

  void _recarregar() {
    if (!mounted) return;
    setState(() => _futuro = _carregar());
  }

  Future<void> _enviar(Linha doc) async {
    final f = await escolherFicheiro();
    if (f == null || !mounted) return;
    final ok = await executar(
        context,
        () => MamanaService.enviarDocumento(_id, doc['id'] as String,
            origem: f.caminho, nome: f.nome));
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento enviado. A InovaLab vai conferir.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.pedido['estado'] as String;
    final idx = CandidaturaService.ordemEstados.indexOf(estado);
    final recusada = estado == 'recusada';
    final tema = Theme.of(context);
    final aberto = !recusada && idx >= 0 && idx < CandidaturaService.ordemEstados.indexOf('encaminhada');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<_Dados>(
          future: _futuro,
          builder: (context, snap) {
            final d = snap.data;
            final ultima = (d == null || d.decisoes.isEmpty) ? null : d.decisoes.first;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.pedido['atividade'] ?? 'Pedido'} · '
                  '${formatarMzn((widget.pedido['valor_pedido'] as num?) ?? 0)}',
                  style: tema.textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(rotuloEstadoMamana(estado), style: tema.textTheme.bodyLarge),

                if (ultima != null && (estado == 'recusada' || aberto || ultima['resultado'] == 'aprovado'))
                  Card(
                    color: tema.colorScheme.surfaceContainerHighest,
                    margin: const EdgeInsets.only(top: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            switch (ultima['resultado']) {
                              'aprovado' => 'Decisão da MZN: aprovado',
                              'recusado' => 'Decisão da MZN: não aprovado',
                              _ => 'A MZN pediu mais informação',
                            },
                            style: tema.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(ultima['fundamentacao'] as String),
                        ],
                      ),
                    ),
                  ),

                titulo(context, 'Em que ponto estamos'),
                for (final (rotulo, minimo) in _passos)
                  Builder(builder: (_) {
                    final limite = recusada ? 3 : idx; // recusada: parou na decisão
                    final feito = limite >= CandidaturaService.ordemEstados.indexOf(minimo);
                    final falhou = recusada && minimo == 'decidida';
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        falhou
                            ? Icons.cancel
                            : (feito ? Icons.check_circle : Icons.radio_button_unchecked),
                        color: falhou ? Colors.red : (feito ? Colors.green : Colors.grey),
                      ),
                      title: Text(rotulo),
                    );
                  }),

                if (d != null) ...[
                  titulo(context, 'Os meus documentos'),
                  for (final doc in d.documentos) _linhaDocumento(context, doc, aberto),
                  if (d.pagamentos.isNotEmpty) ...[
                    titulo(context, 'Os meus pagamentos'),
                    for (final p in d.pagamentos) _linhaPagamento(p),
                  ],
                ] else if (snap.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _linhaDocumento(BuildContext context, Linha doc, bool aberto) {
    final entregue = doc['entregue'] == 1;
    final enviado = doc['ficheiro_path'] != null;
    final subtitulo = entregue
        ? 'Recebido'
        : enviado
            ? 'Enviado — a InovaLab vai conferir'
            : (doc['obrigatorio'] == 1 ? 'Falta' : 'Se aplicável');
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        entregue ? Icons.check_circle : (enviado ? Icons.hourglass_top : Icons.radio_button_unchecked),
        color: entregue ? Colors.green : (enviado ? Colors.orange : Colors.grey),
      ),
      title: Text(doc['titulo'] as String),
      subtitle: Text(subtitulo),
      trailing: entregue
          ? (enviado
              ? TextButton(
                  onPressed: () => abrirAnexo(context, doc['ficheiro_path'] as String),
                  child: const Text('Ver'))
              : null)
          : (aberto
              ? TextButton(
                  onPressed: () => _enviar(doc),
                  child: Text(enviado ? 'Substituir' : 'Enviar'))
              : null),
    );
  }

  Widget _linhaPagamento(Linha p) {
    final pago = p['data_pagamento'] != null;
    final hoje = DateTime.now();
    final atrasado = !pago &&
        DateTime.parse(p['data_prevista'] as String)
            .isBefore(DateTime(hoje.year, hoje.month, hoje.day));
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        pago ? Icons.check_circle : (atrasado ? Icons.error : Icons.schedule),
        color: pago ? Colors.green : (atrasado ? Colors.red : null),
      ),
      title: Text('${formatarMzn(p['valor_previsto'] as num)} · ${soData(p['data_prevista'])}'),
      subtitle: Text(pago ? 'Pago em ${soData(p['data_pagamento'])}' : (atrasado ? 'Em atraso' : 'Por pagar')),
    );
  }
}
