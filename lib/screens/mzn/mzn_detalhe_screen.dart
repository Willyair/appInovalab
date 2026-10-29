import 'package:flutter/material.dart';

import '../../services/candidatura_service.dart';
import '../../services/risco_service.dart';
import '../../services/mzn_service.dart';
import '../../util/abrir_anexo.dart';
import '../../util/atualizacao.dart';
import '../../widgets/comum.dart';

class _Dados {
  final Linha resumo;
  final Avaliacao avaliacao;
  final List<Linha> documentos, sinais, verificacoes, decisoes, pagamentos;
  final Linha? analise;
  _Dados(this.resumo, this.avaliacao, this.documentos, this.sinais, this.verificacoes,
      this.decisoes, this.pagamentos, this.analise);
}

class MznDetalheScreen extends StatefulWidget {
  final String candidaturaId;
  const MznDetalheScreen({super.key, required this.candidaturaId});

  @override
  State<MznDetalheScreen> createState() => _MznDetalheScreenState();
}

class _MznDetalheScreenState extends State<MznDetalheScreen> {
  late Future<_Dados> _futuro;

  String get _id => widget.candidaturaId;

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

  Future<_Dados> _carregar() async => _Dados(
        await MznService.resumo(_id),
        await CandidaturaService.avaliacao(_id),
        await CandidaturaService.documentos(_id),
        await CandidaturaService.sinais(_id),
        await CandidaturaService.verificacoes(_id),
        await CandidaturaService.decisoes(_id),
        await CandidaturaService.pagamentos(_id),
        await CandidaturaService.analise(_id),
      );

  Future<void> _decidir(String resultado) async {
    final rotulo = switch (resultado) {
      'aprovado' => 'Aprovar',
      'recusado' => 'Recusar',
      _ => 'Pedir mais informação',
    };
    final texto = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(rotulo),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'A fundamentação fica registada com o teu nome e não pode ser alterada.',
              style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          TextField(
            controller: texto,
            maxLines: 5,
            decoration: const InputDecoration(
                labelText: 'Fundamentação *', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(rotulo)),
        ],
      ),
    );
    final f = texto.text;
    texto.dispose();
    if (ok != true || !mounted) return;
    final feito = await executar(
        context, () => MznService.decidir(_id, resultado: resultado, fundamentacao: f));
    // "Pedir mais informação" devolve a candidatura à InovaLab e ela deixa de
    // ser visível para a MZN: sem isto o ecrã passava a mostrar um erro.
    if (feito && resultado == 'mais_informacao' && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _registarPagamento(Linha pag) async {
    final valor =
        TextEditingController(text: (pag['valor_previsto'] as num).toStringAsFixed(0));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Candidatura')),
      body: FutureBuilder<_Dados>(
        future: _futuro,
        builder: (context, snap) {
          if (!snap.hasData) {
            return Center(
                child: snap.hasError
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('${snap.error}'),
                      )
                    : const CircularProgressIndicator());
          }
          final d = snap.data!;
          final r = d.resumo;
          final estado = r['estado'] as String;
          final res = d.avaliacao.resultado;
          final pont = d.avaliacao.pontuacao;
          final tema = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(child: Text(r['nome'] as String, style: tema.textTheme.headlineSmall)),
                EtiquetaRisco(r['classificacao'] as String?),
              ]),
              const SizedBox(height: 4),
              Text([
                if (r['atividade'] != null) r['atividade'] as String,
                if ((r['localizacao'] as String?)?.isNotEmpty ?? false) r['localizacao'] as String,
                if ((r['bairro'] as String?)?.isNotEmpty ?? false) 'Bairro ${r['bairro']}',
              ].join(' · ')),
              Text('${formatarMzn((r['valor_pedido'] as num?) ?? 0)} em ${r['prazo_meses']} meses'
                  '${r['primeiro_credito'] == 1 ? ' · primeiro crédito' : ''}'),
              Text('Estado: ${rotuloEstado(estado)}', style: tema.textTheme.bodySmall),
              if ((r['finalidade_financiamento'] as String?)?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Finalidade: ${r['finalidade_financiamento']}'),
                ),

              // ---- decisão
              ..._accoes(context, estado, d),

              // ---- risco
              if (res != null) ...[
                titulo(context, 'Análise de risco da InovaLab'),
                if (res.nivel == NivelRisco.elevado)
                  Card(
                    color: tema.colorScheme.errorContainer,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Risco elevado: o modelo exige revisão antes de qualquer decisão.'),
                    ),
                  ),
                Text('Pontuação ${res.total}/100',
                    style: tema.textTheme.titleMedium),
                if (pont != null)
                  for (final e in Pontuacao.maximos.entries)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        Expanded(flex: 5, child: Text(Pontuacao.rotulos[e.key]!)),
                        Expanded(
                          flex: 3,
                          child: LinearProgressIndicator(value: pont.valor(e.key) / e.value),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text('${pont.valor(e.key)}/${e.value}',
                              textAlign: TextAlign.end),
                        ),
                      ]),
                    ),
                const SizedBox(height: 8),
                for (final f in res.fatores)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [const Text('• '), Expanded(child: Text(f))],
                    ),
                  ),
                if ((d.avaliacao.justificacao ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Justificação do técnico: ${d.avaliacao.justificacao}'),
                  ),
              ],

              // ---- financeira
              if (d.analise != null) ..._financeira(context, d.analise!),

              // ---- documentos
              titulo(context, 'Documentos'),
              for (final doc in d.documentos)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    doc['entregue'] == 1 ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: doc['entregue'] == 1 ? Colors.green : Colors.grey,
                  ),
                  title: Text(doc['titulo'] as String),
                  subtitle: Text(doc['obrigatorio'] == 1 ? 'Obrigatório' : 'Quando aplicável'),
                  trailing: doc['ficheiro_path'] == null
                      ? null
                      : TextButton(
                          onPressed: () => abrirAnexo(context, doc['ficheiro_path'] as String),
                          child: const Text('Abrir'),
                        ),
                ),

              // ---- verificações e sinais
              titulo(context, 'Verificações'),
              if (d.verificacoes.isEmpty) const Text('Sem verificações registadas.'),
              for (final v in d.verificacoes)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    v['resultado'] == 'conforme' ? Icons.check_circle : Icons.warning_amber,
                    color: v['resultado'] == 'conforme' ? Colors.green : Colors.orange,
                  ),
                  title: Text(switch (v['tipo']) {
                    'identidade' => 'Identidade',
                    'comunitaria' => 'Confirmação comunitária',
                    _ => 'Visita ao negócio',
                  }),
                  subtitle: Text('${v['resultado']} · ${soData(v['data'])}'
                      '${(v['notas'] as String?)?.isNotEmpty ?? false ? ' · ${v['notas']}' : ''}'),
                ),
              if (d.sinais.isNotEmpty) ...[
                titulo(context, 'Sinais de alerta'),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final s in d.sinais)
                    Chip(
                      label: Text(s['titulo'] as String),
                      backgroundColor: s['grave'] == 1 ? tema.colorScheme.errorContainer : null,
                    ),
                ]),
              ],

              // ---- decisões anteriores
              if (d.decisoes.isNotEmpty) ...[
                titulo(context, 'Histórico de decisões'),
                for (final dec in d.decisoes)
                  Card(
                    child: ListTile(
                      title: Text(switch (dec['resultado']) {
                        'aprovado' => 'Aprovada',
                        'recusado' => 'Recusada',
                        _ => 'Pedida mais informação',
                      }),
                      subtitle: Text(
                          '${dec['fundamentacao']}\n— ${dec['decisor_nome'] ?? 'MZN'}, ${soData(dec['data'])}'),
                      isThreeLine: true,
                    ),
                  ),
              ],

              // ---- pagamentos
              ..._pagamentos(context, estado, d.pagamentos),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _accoes(BuildContext context, String estado, _Dados d) {
    if (estado == 'encaminhada') {
      return [
        titulo(context, 'Decisão'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
              onPressed: () => _decidir('aprovado'),
              icon: const Icon(Icons.check),
              label: const Text('Aprovar')),
          OutlinedButton.icon(
              onPressed: () => _decidir('mais_informacao'),
              icon: const Icon(Icons.help_outline),
              label: const Text('Pedir mais informação')),
          OutlinedButton.icon(
              onPressed: () => _decidir('recusado'),
              icon: const Icon(Icons.close),
              label: const Text('Recusar')),
        ]),
      ];
    }
    if (estado == 'decidida') {
      return [
        titulo(context, 'Contratação'),
        FilledButton(
          onPressed: () => executar(context, () => MznService.formalizar(_id)),
          child: const Text('Marcar crédito como formalizado (contrato assinado)'),
        ),
      ];
    }
    if (estado == 'formalizada') {
      return [
        titulo(context, 'Desembolso'),
        FilledButton(
          onPressed: () => executar(context, () => MznService.desembolsar(_id)),
          child: const Text('Marcar como desembolsado'),
        ),
      ];
    }
    return [];
  }

  List<Widget> _financeira(BuildContext context, Linha a) {
    final v = (a['vendas_mensais'] as num).toDouble();
    final c = (a['custos_mensais'] as num).toDouble();
    final o = (a['outras_dividas_mensais'] as num).toDouble();
    final p = (a['prestacao_estimada'] as num).toDouble();
    final exc = RiscoService.excedenteMensal(vendas: v, custos: c, outrasDividas: o);
    final cob = RiscoService.cobertura(vendas: v, custos: c, outrasDividas: o, prestacao: p);
    return [
      titulo(context, 'Capacidade de pagamento'),
      Text('Vendas ${formatarMzn(v)} · custos ${formatarMzn(c)} · outras dívidas ${formatarMzn(o)}'),
      Text('Prestação estimada ${formatarMzn(p)} · excedente ${formatarMzn(exc)}'
          '${cob != null ? ' · cobertura ${cob.toStringAsFixed(2)}×' : ''}'),
      if ((a['observacoes'] as String?)?.isNotEmpty ?? false) Text('Notas: ${a['observacoes']}'),
    ];
  }

  List<Widget> _pagamentos(BuildContext context, String estado, List<Linha> pagamentos) {
    final podePlano = CandidaturaService.planoPermitidoEm.contains(estado);
    if (!podePlano && pagamentos.isEmpty) return [];
    final hoje = DateTime.now();
    return [
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Row(children: [
          Expanded(child: Text('Pagamentos', style: Theme.of(context).textTheme.titleMedium)),
          if (pagamentos.isEmpty && podePlano)
            OutlinedButton(
              onPressed: () =>
                  executar(context, () => CandidaturaService.gerarPlanoPagamentos(_id)),
              child: const Text('Gerar plano'),
            ),
        ]),
      ),
      if (pagamentos.isEmpty)
        const Text('Plano simples (valor ÷ prazo, sem juros). Ajusta ao plano oficial da MZN.'),
      for (final p in pagamentos)
        Builder(builder: (_) {
          final pago = p['data_pagamento'] != null;
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
            title: Text(
                '${formatarMzn(p['valor_previsto'] as num)} · ${soData(p['data_prevista'])}'),
            subtitle: Text(pago
                ? 'Pago ${formatarMzn(p['valor_pago'] as num)} em ${soData(p['data_pagamento'])}'
                : (atrasado ? 'EM ATRASO' : 'Por pagar')),
            trailing: pago
                ? null
                : TextButton(onPressed: () => _registarPagamento(p), child: const Text('Registar')),
          );
        }),
    ];
  }
}
