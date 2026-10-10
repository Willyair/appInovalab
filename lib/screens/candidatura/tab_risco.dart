import 'package:flutter/material.dart';

import '../../services/candidatura_service.dart';
import '../../services/risco_service.dart';
import '../../util/atualizacao.dart';
import '../../widgets/comum.dart';

class TabRisco extends StatefulWidget {
  final String candidaturaId;
  final VoidCallback aoAlterar;
  const TabRisco({super.key, required this.candidaturaId, required this.aoAlterar});

  @override
  State<TabRisco> createState() => _TabRiscoState();
}

class _TabRiscoState extends State<TabRisco> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _justificacao = TextEditingController();
  Pontuacao _p = const Pontuacao();
  Sugestoes? _sug;
  List<Linha> _tiposSinal = [];
  Set<String> _sinaisAtivos = {};
  ResultadoClassificacao? _resultado;
  String? _nivelGuardado;
  List<String> _bloqueios = [];
  Linha? _decisao;
  bool _aCarregar = true;

  String get _id => widget.candidaturaId;

  @override
  void initState() {
    super.initState();
    _carregar();
    Atualizacao.versao.addListener(_refrescar);
  }

  @override
  void dispose() {
    Atualizacao.versao.removeListener(_refrescar);
    _justificacao.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final av = await CandidaturaService.avaliacao(_id);
    final sug = await CandidaturaService.sugestoes(_id);
    final tipos = await CandidaturaService.tiposSinal();
    final sinais = await CandidaturaService.sinais(_id);
    if (!mounted) return;
    setState(() {
      if (av.pontuacao != null) _p = av.pontuacao!;
      _justificacao.text = av.justificacao ?? _justificacao.text;
      _resultado = av.resultado;
      _sug = sug;
      _tiposSinal = tipos;
      _sinaisAtivos = sinais.map((s) => s['tipo'] as String).toSet();
      _aCarregar = false;
    });
    await _refrescar();
  }

  /// Quando algo muda noutro separador: atualiza sugestões, sinais e o
  /// resultado, sem mexer nos valores que o técnico está a editar.
  Future<void> _refrescar() async {
    if (_aCarregar) return;
    final av = await CandidaturaService.avaliacao(_id);
    final sug = await CandidaturaService.sugestoes(_id);
    final sinais = await CandidaturaService.sinais(_id);
    final res = await CandidaturaService.resumo(_id);
    final bloqueios = await CandidaturaService.motivosBloqueioEncaminhar(_id);
    final decisoes = await CandidaturaService.decisoes(_id);
    if (!mounted) return;
    setState(() {
      _resultado = av.resultado;
      _sug = sug;
      _sinaisAtivos = sinais.map((s) => s['tipo'] as String).toSet();
      _nivelGuardado = res['classificacao'] as String?;
      _bloqueios = bloqueios;
      _decisao = decisoes.isEmpty ? null : decisoes.first;
    });
  }

  Future<void> _encaminhar() async {
    if (_resultado?.nivel == NivelRisco.elevado) {
      final sim = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Risco elevado'),
          content: const Text(
            'O documento diz que o risco elevado exige revisão antes de qualquer '
            'decisão. Confirmas que a revisão interna foi feita e queres encaminhar '
            'à MZN com este risco?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Encaminhar')),
          ],
        ),
      );
      if (sim != true || !mounted) return;
    }
    final ok = await executar(context, () => CandidaturaService.encaminharParaMzn(_id));
    if (ok && mounted) {
      widget.aoAlterar();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Candidatura encaminhada à MZN.')));
    }
  }

  void _usarSugestoes() {
    final s = _sug!;
    setState(() {
      _p = _p
          .com('documentacao', s.documentacao)
          .com('comunitaria', s.comunitaria)
          .com('capacidade', s.capacidade);
    });
  }

  Future<void> _alternarSinal(String codigo, bool ativo) async {
    await executar(context, () => CandidaturaService.alternarSinal(_id, codigo, ativo));
  }

  Future<void> _classificar() async {
    ResultadoClassificacao? res;
    final ok = await executar(context, () async {
      final av = await CandidaturaService.guardarPontuacaoEClassificar(
        _id,
        pontuacao: _p,
        justificacao: _justificacao.text,
      );
      res = av.resultado;
    });
    if (ok && mounted) {
      setState(() {
        _resultado = res;
        _nivelGuardado = res?.nivel.name;
      });
      widget.aoAlterar();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_aCarregar) return const Center(child: CircularProgressIndicator());
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Pontuação: ${_p.total}/100', style: tema.textTheme.titleLarge),
            ),
            OutlinedButton.icon(
              onPressed: _usarSugestoes,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Usar sugestões'),
            ),
          ],
        ),
        const Text(
          'As sugestões vêm dos documentos, da confirmação comunitária e da '
          'análise financeira. Ajusta com o teu critério e justifica.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        for (final e in Pontuacao.maximos.entries) _slider(e.key, e.value),
        const SizedBox(height: 8),
        TextField(
          controller: _justificacao,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Justificação da pontuação *',
            border: OutlineInputBorder(),
          ),
        ),
        titulo(context, 'Sinais de alerta'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final t in _tiposSinal)
              FilterChip(
                label: Text(t['titulo'] as String),
                avatar: t['grave_por_defeito'] == 1
                    ? const Icon(Icons.priority_high, size: 16)
                    : null,
                selected: _sinaisAtivos.contains(t['codigo']),
                onSelected: (v) => _alternarSinal(t['codigo'] as String, v),
              ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('Sinais com ! são graves e levam a risco elevado.',
              style: TextStyle(fontSize: 12)),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _classificar, child: const Text('Guardar e classificar')),
        if (_resultado != null && _nivelGuardado != _resultado!.nivel.name)
          Card(
            margin: const EdgeInsets.only(top: 16),
            color: tema.colorScheme.tertiaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Os documentos ou sinais mudaram desde a última classificação '
                'guardada. Carrega em "Guardar e classificar" para atualizar.',
              ),
            ),
          ),
        if (_resultado != null) _cartaoResultado(context, _resultado!),
        titulo(context, 'Encaminhar à MZN'),
        if (_decisao != null) _cartaoDecisao(context, _decisao!),
        if (_bloqueios.isNotEmpty) ...[
          const Text('Antes de encaminhar:'),
          for (final b in _bloqueios)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [const Text('• '), Expanded(child: Text(b))],
              ),
            ),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _bloqueios.isEmpty ? _encaminhar : null,
          icon: const Icon(Icons.send),
          label: const Text('Encaminhar à MZN'),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Depois de encaminhada, a análise fica bloqueada. Se a MZN pedir mais '
            'informação, volta a abrir.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _slider(String chave, int maximo) {
    final v = _p.valor(chave);
    final sug = switch (chave) {
      'documentacao' => _sug?.documentacao,
      'comunitaria' => _sug?.comunitaria,
      'capacidade' => _sug?.capacidade,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '${Pontuacao.rotulos[chave]}: $v/$maximo'
            '${sug != null ? '  (sugestão: $sug)' : ''}',
          ),
        ),
        Slider(
          value: v.toDouble(),
          min: 0,
          max: maximo.toDouble(),
          divisions: maximo,
          label: '$v',
          onChanged: (x) => setState(() => _p = _p.com(chave, x.round())),
        ),
      ],
    );
  }

  Widget _cartaoDecisao(BuildContext context, Linha d) {
    final r = d['resultado'] as String;
    final texto = switch (r) {
      'aprovado' => 'Aprovada pela MZN',
      'recusado' => 'Recusada pela MZN',
      _ => 'A MZN pediu mais informação',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$texto · ${soData(d['data'])}',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(d['fundamentacao'] as String),
          ],
        ),
      ),
    );
  }

  Widget _cartaoResultado(BuildContext context, ResultadoClassificacao r) {
    final cor = corNivel(r.nivel.name, Theme.of(context).brightness);
    return Card(
      margin: const EdgeInsets.only(top: 20),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rotuloNivel(r.nivel),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: cor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Fatores:'),
            for (final f in r.fatores)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [const Text('• '), Expanded(child: Text(f))],
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'A classificação apoia a decisão; não é garantia nem aprovação. '
              'A decisão de crédito é da MZN.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
