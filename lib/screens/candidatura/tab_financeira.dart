import 'package:flutter/material.dart';

import '../../services/candidatura_service.dart';
import '../../services/risco_service.dart';
import '../../widgets/comum.dart';

class TabFinanceira extends StatefulWidget {
  final String candidaturaId;
  final double valorPedido;
  final int prazoMeses;
  final VoidCallback aoAlterar;
  const TabFinanceira({
    super.key,
    required this.candidaturaId,
    required this.valorPedido,
    required this.prazoMeses,
    required this.aoAlterar,
  });

  @override
  State<TabFinanceira> createState() => _TabFinanceiraState();
}

class _TabFinanceiraState extends State<TabFinanceira> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _vendas = TextEditingController();
  final _custos = TextEditingController();
  final _dividas = TextEditingController(text: '0');
  final _prestacao = TextEditingController();
  final _obs = TextEditingController();
  bool _aCarregar = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final a = await CandidaturaService.analise(widget.candidaturaId);
    if (a != null) {
      _vendas.text = '${a['vendas_mensais']}';
      _custos.text = '${a['custos_mensais']}';
      _dividas.text = '${a['outras_dividas_mensais']}';
      _prestacao.text = '${a['prestacao_estimada']}';
      _obs.text = (a['observacoes'] as String?) ?? '';
    }
    if (mounted) setState(() => _aCarregar = false);
  }

  @override
  void dispose() {
    for (final c in [_vendas, _custos, _dividas, _prestacao, _obs]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _v => lerNumero(_vendas.text) ?? 0;
  double get _c => lerNumero(_custos.text) ?? 0;
  double get _d => lerNumero(_dividas.text) ?? 0;
  double get _p => lerNumero(_prestacao.text) ?? 0;

  Future<void> _guardar() async {
    // Cada campo tem de ser um número. Antes, texto que não fosse número (ou
    // "5000MZN") era lido como 0 e a análise era guardada sem aviso.
    final v = lerNumero(_vendas.text);
    final c = lerNumero(_custos.text);
    final d = _dividas.text.trim().isEmpty ? 0.0 : lerNumero(_dividas.text);
    final p = lerNumero(_prestacao.text);
    if (v == null || c == null || d == null || p == null || p <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Preenche vendas, custos e a prestação estimada só com números '
              '(a prestação tem de ser maior que 0).')));
      return;
    }
    if (v < 0 || c < 0 || d < 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Os valores não podem ser negativos.')));
      return;
    }
    final ok = await executar(
        context,
        () => CandidaturaService.guardarAnalise(widget.candidaturaId,
            vendas: v, custos: c, outrasDividas: d, prestacao: p, observacoes: _obs.text));
    if (ok && mounted) {
      widget.aoAlterar();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Análise guardada.')));
    }
  }

  Widget _campo(String rotulo, TextEditingController c, {int linhas = 1, bool numero = true}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: linhas,
          keyboardType: numero ? TextInputType.number : TextInputType.text,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: rotulo, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_aCarregar) return const Center(child: CircularProgressIndicator());
    final excedente = RiscoService.excedenteMensal(vendas: _v, custos: _c, outrasDividas: _d);
    final cob = RiscoService.cobertura(
        vendas: _v, custos: _c, outrasDividas: _d, prestacao: _p);
    final sugestao = RiscoService.sugerirCapacidade(cob);
    final fraco = cob != null && cob < 1;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Valores mensais, estimados e conferidos na visita. '
          'Pedido: ${formatarMzn(widget.valorPedido)} em ${widget.prazoMeses} meses.',
        ),
        const SizedBox(height: 16),
        _campo('Vendas mensais (MZN)', _vendas),
        _campo('Custos mensais (MZN)', _custos),
        _campo('Outras dívidas/prestações por mês (MZN)', _dividas),
        _campo('Prestação mensal estimada (MZN)', _prestacao),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Sugerir: valor ÷ prazo (sem juros)'),
            onPressed: () => setState(() => _prestacao.text =
                RiscoService.prestacaoSimples(widget.valorPedido, widget.prazoMeses)
                    .toStringAsFixed(0)),
          ),
        ),
        const Text(
          'Os juros e taxas são definidos pela MZN: ajusta a prestação com a '
          'simulação da MZN antes de concluir.',
          style: TextStyle(fontSize: 12),
        ),
        _campo('Observações', _obs, linhas: 3, numero: false),
        Card(
          color: fraco
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Excedente mensal: ${formatarMzn(excedente)}'),
                Text(cob == null
                    ? 'Cobertura da prestação: —'
                    : 'Cobertura da prestação: ${cob.toStringAsFixed(2)}×'),
                Text('Pontuação sugerida para capacidade: $sugestao/25'),
                if (fraco)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Atenção: o fluxo de caixa não cobre a prestação. '
                      'Considera o sinal de alerta "Fluxo de caixa incompatível" '
                      'ou um valor/prazo diferente.',
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _guardar, child: const Text('Guardar análise')),
      ],
    );
  }
}
