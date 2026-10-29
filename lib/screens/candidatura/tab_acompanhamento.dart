import 'package:flutter/material.dart';

import '../../services/candidatura_service.dart';
import '../../util/atualizacao.dart';
import '../../widgets/comum.dart';

class _Dados {
  final Linha resumo;
  final List<Linha> vendas, pagamentos, acoes;
  _Dados(this.resumo, this.vendas, this.pagamentos, this.acoes);
}

/// Monitoria após o financiamento (§11): vendas, pagamentos e ações.
class TabAcompanhamento extends StatefulWidget {
  final String candidaturaId;
  const TabAcompanhamento({super.key, required this.candidaturaId});

  @override
  State<TabAcompanhamento> createState() => _TabAcompanhamentoState();
}

class _TabAcompanhamentoState extends State<TabAcompanhamento> {
  late Future<_Dados> _futuro;

  String get _id => widget.candidaturaId;

  static const _tiposAcao = {
    'contacto': 'Contacto',
    'visita': 'Visita',
    'alerta_atraso': 'Alerta de atraso',
    'plano_recuperacao': 'Plano de recuperação',
    'outra': 'Outra',
  };

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
        await CandidaturaService.resumo(_id),
        await CandidaturaService.vendas(_id),
        await CandidaturaService.pagamentos(_id),
        await CandidaturaService.acoesMonitoria(_id),
      );

  void _recarregar() {
    if (!mounted) return;
    setState(() => _futuro = _carregar());
  }

  Future<void> _venda() async {
    final hoje = DateTime.now();
    final mes = TextEditingController(text: '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}');
    final valor = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vendas do mês (conferidas)'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: mes,
            decoration: const InputDecoration(
                labelText: 'Mês (AAAA-MM)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: valor,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Valor vendido (MZN)', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    final m = mes.text.trim(), v = valor.text;
    mes.dispose();
    valor.dispose();
    if (ok != true || !mounted) return;
    final partes = m.split('-');
    final ano = partes.length == 2 ? int.tryParse(partes[0]) : null;
    final mm = partes.length == 2 ? int.tryParse(partes[1]) : null;
    final val = lerNumero(v);
    if (ano == null || mm == null || val == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usa o mês como AAAA-MM e um valor numérico.')));
      return;
    }
    await executar(context,
        () => CandidaturaService.registarVenda(_id, ano: ano, mes: mm, valor: val));
  }

  Future<void> _pagamento(Linha pag) async {
    final valor =
        TextEditingController(text: '${(pag['valor_previsto'] as num).toStringAsFixed(0)}');
    final data = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registar pagamento recebido'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: valor,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Valor pago (MZN)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: data,
            decoration: const InputDecoration(
                labelText: 'Data (AAAA-MM-DD)', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    final v = lerNumero(valor.text), d = data.text;
    valor.dispose();
    data.dispose();
    if (ok != true || !mounted) return;
    if (v == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Valor inválido.')));
      return;
    }
    await executar(context,
        () => CandidaturaService.registarPagamento(_id, pag['id'] as String, valor: v, data: d));
  }

  Future<void> _acao() async {
    var tipo = 'contacto';
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Ação de acompanhamento'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Wrap(spacing: 6, children: [
              for (final e in _tiposAcao.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: tipo == e.key,
                  onSelected: (_) => setD(() => tipo = e.key),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: desc,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'O que foi feito *', border: OutlineInputBorder()),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    final d = desc.text;
    desc.dispose();
    if (ok != true || !mounted) return;
    await executar(
        context, () => CandidaturaService.registarAcaoMonitoria(_id, tipo: tipo, descricao: d));
  }

  Widget _cabecalho(BuildContext context, String texto, {String? botao, VoidCallback? aoClicar}) =>
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Row(children: [
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.titleMedium)),
          if (botao != null) OutlinedButton(onPressed: aoClicar, child: Text(botao)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Dados>(
      future: _futuro,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final d = snap.data!;
        final hoje = DateTime.now();
        final podePlano = CandidaturaService.planoPermitidoEm.contains(d.resumo['estado']);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _cabecalho(context, 'Pagamentos',
                botao: d.pagamentos.isEmpty ? 'Gerar plano' : null,
                aoClicar: () => executar(
                    context, () => CandidaturaService.gerarPlanoPagamentos(_id))),
            if (d.pagamentos.isEmpty)
              Text(podePlano
                  ? 'Sem plano ainda. "Gerar plano" divide o valor pelo prazo, sem juros '
                      '(ajusta com o plano oficial da MZN).'
                  : 'O plano de pagamentos cria-se depois de a MZN marcar o crédito como desembolsado.'),
            for (final p in d.pagamentos) _linhaPagamento(p, hoje),
            _cabecalho(context, 'Vendas conferidas', botao: 'Registar', aoClicar: _venda),
            if (d.vendas.isEmpty) const Text('Sem vendas registadas.'),
            for (final v in d.vendas)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(v['estado'] == 'verificado'
                    ? Icons.verified_outlined
                    : Icons.edit_note),
                title: Text(formatarMzn((v['valor'] as num))),
                subtitle: Text('${soData(v['periodo']).substring(0, 7)} · '
                    '${v['estado'] == 'verificado' ? 'verificado' : 'declarado'} '
                    '(${v['registado_por_papel']})'),
              ),
            _cabecalho(context, 'Ações de acompanhamento', botao: 'Nova ação', aoClicar: _acao),
            if (d.acoes.isEmpty) const Text('Sem ações registadas.'),
            for (final a in d.acoes)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text(a['descricao'] as String),
                subtitle: Text('${_tiposAcao[a['tipo']] ?? a['tipo']} · ${soData(a['data'])}'),
              ),
          ],
        );
      },
    );
  }

  Widget _linhaPagamento(Linha p, DateTime hoje) {
    final prevista = DateTime.parse(p['data_prevista'] as String);
    final pago = p['data_pagamento'] != null;
    final atrasado = !pago && prevista.isBefore(DateTime(hoje.year, hoje.month, hoje.day));
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        pago ? Icons.check_circle : (atrasado ? Icons.error : Icons.schedule),
        color: pago ? Colors.green : (atrasado ? Colors.red : null),
      ),
      title: Text('${formatarMzn(p['valor_previsto'] as num)} · prevista ${soData(p['data_prevista'])}'),
      subtitle: Text(pago
          ? 'Pago: ${formatarMzn(p['valor_pago'] as num)} em ${soData(p['data_pagamento'])}'
          : (atrasado ? 'EM ATRASO' : 'Por pagar')),
      trailing: pago
          ? null
          : TextButton(onPressed: () => _pagamento(p), child: const Text('Registar')),
    );
  }
}
