import 'package:flutter/material.dart';

import '../../services/candidatura_service.dart';
import '../../widgets/comum.dart';

class _Dados {
  final List<Linha> verificacoes, declaracoes, lideres, fichas;
  _Dados(this.verificacoes, this.declaracoes, this.lideres, this.fichas);
}

class TabVerificacao extends StatefulWidget {
  final String candidaturaId;
  final VoidCallback aoAlterar;
  const TabVerificacao({super.key, required this.candidaturaId, required this.aoAlterar});

  @override
  State<TabVerificacao> createState() => _TabVerificacaoState();
}

class _TabVerificacaoState extends State<TabVerificacao> {
  late Future<_Dados> _futuro;

  String get _id => widget.candidaturaId;

  @override
  void initState() {
    super.initState();
    _futuro = _carregar();
  }

  Future<_Dados> _carregar() async => _Dados(
        await CandidaturaService.verificacoes(_id),
        await CandidaturaService.declaracoesBairro(_id),
        await CandidaturaService.confirmacoesLideres(_id),
        await CandidaturaService.fichasVisita(_id),
      );

  void _recarregar() {
    setState(() => _futuro = _carregar());
    widget.aoAlterar();
  }

  Future<void> _identidade() async {
    final notas = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verificação de identidade'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Conferiste o documento e a consistência dos dados?'),
            const SizedBox(height: 12),
            TextField(
              controller: notas,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notas', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'inconsistente'),
              child: const Text('Inconsistente')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'conforme'), child: const Text('Conforme')),
        ],
      ),
    );
    final n = notas.text;
    notas.dispose();
    if (r == null || !mounted) return;
    final ok = await executar(context,
        () => CandidaturaService.registarVerificacao(_id, tipo: 'identidade', resultado: r, notas: n));
    if (ok) _recarregar();
  }

  Future<void> _declaracaoBairro() async {
    final por = TextEditingController();
    final data = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
    final validade = TextEditingController();
    final obs = TextEditingController();
    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Declaração do bairro'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _campo(por, 'Emitida por (secretário/estrutura do bairro) *'),
            _campo(data, 'Data de emissão (AAAA-MM-DD) *'),
            _campo(validade, 'Validade (AAAA-MM-DD)'),
            _campo(obs, 'Observação', linhas: 2),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    final v = (por.text, data.text, validade.text, obs.text);
    for (final c in [por, data, validade, obs]) {
      c.dispose();
    }
    if (guardar != true || !mounted) return;
    if (v.$1.trim().isEmpty || v.$2.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Preenche quem emitiu e a data.')));
      return;
    }
    final ok = await executar(
        context,
        () => CandidaturaService.registarDeclaracaoBairro(_id,
            emitidaPor: v.$1, dataEmissao: v.$2, validade: v.$3, observacao: v.$4));
    if (ok) _recarregar();
  }

  Future<void> _lider() async {
    final nome = TextEditingController();
    final mercado = TextEditingController();
    final contacto = TextEditingController();
    final notas = TextEditingController();
    var existencia = true, localizacao = true, atividade = true;
    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Confirmação do líder do mercado'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                'O líder só confirma factos que conhece. Esta confirmação '
                'não é garantia financeira.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              _campo(nome, 'Nome do líder *'),
              _campo(mercado, 'Mercado *'),
              _campo(contacto, 'Contacto'),
              CheckboxListTile(
                  dense: true,
                  value: existencia,
                  onChanged: (v) => setD(() => existencia = v ?? false),
                  title: const Text('Confirma que a empreendedora existe')),
              CheckboxListTile(
                  dense: true,
                  value: localizacao,
                  onChanged: (v) => setD(() => localizacao = v ?? false),
                  title: const Text('Confirma a localização aproximada')),
              CheckboxListTile(
                  dense: true,
                  value: atividade,
                  onChanged: (v) => setD(() => atividade = v ?? false),
                  title: const Text('Confirma a existência da atividade')),
              _campo(notas, 'Notas', linhas: 2),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    final v = (nome.text, mercado.text, contacto.text, notas.text);
    for (final c in [nome, mercado, contacto, notas]) {
      c.dispose();
    }
    if (guardar != true || !mounted) return;
    if (v.$1.trim().isEmpty || v.$2.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Preenche o nome do líder e o mercado.')));
      return;
    }
    final ok = await executar(
        context,
        () => CandidaturaService.registarConfirmacaoLider(
              _id,
              nomeLider: v.$1,
              mercado: v.$2,
              contacto: v.$3,
              factos: {
                'existencia': existencia,
                'localizacao': localizacao,
                'atividade': atividade,
              },
              notas: v.$4,
            ));
    if (ok) _recarregar();
  }

  Future<void> _visita() async {
    final stock = TextEditingController();
    final equip = TextEditingController();
    final volume = TextEditingController();
    final notas = TextEditingController();
    var local = true, atividade = true;
    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Ficha de visita ao negócio'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CheckboxListTile(
                  dense: true,
                  value: local,
                  onChanged: (v) => setD(() => local = v ?? false),
                  title: const Text('Local confirmado')),
              CheckboxListTile(
                  dense: true,
                  value: atividade,
                  onChanged: (v) => setD(() => atividade = v ?? false),
                  title: const Text('Atividade em funcionamento')),
              _campo(stock, 'Stock observado'),
              _campo(equip, 'Equipamentos'),
              _campo(volume, 'Volume aproximado de operações'),
              _campo(notas, 'Notas', linhas: 2),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    final v = (stock.text, equip.text, volume.text, notas.text);
    for (final c in [stock, equip, volume, notas]) {
      c.dispose();
    }
    if (guardar != true || !mounted) return;
    final ok = await executar(
        context,
        () => CandidaturaService.registarFichaVisita(_id,
            localConfirmado: local,
            atividadeConfirmada: atividade,
            stock: v.$1,
            equipamentos: v.$2,
            volume: v.$3,
            notas: v.$4));
    if (ok) _recarregar();
  }

  static Widget _campo(TextEditingController c, String rotulo, {int linhas = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          maxLines: linhas,
          decoration: InputDecoration(labelText: rotulo, border: const OutlineInputBorder()),
        ),
      );

  static const _factos = {
    'existencia': 'existência',
    'localizacao': 'localização',
    'atividade': 'atividade',
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Dados>(
      future: _futuro,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final d = snap.data!;
        final ident = d.verificacoes.where((v) => v['tipo'] == 'identidade').toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _seccao(context, '1. Identidade', 'Registar', _identidade),
            if (ident.isEmpty)
              const Text('Ainda não verificada.')
            else
              Text('Última: ${ident.first['resultado']} (${soData(ident.first['data'])})'
                  '${ident.first['notas'] != null && (ident.first['notas'] as String).isNotEmpty ? ' — ${ident.first['notas']}' : ''}'),
            _seccao(context, '2. Declaração do bairro', 'Registar', _declaracaoBairro),
            if (d.declaracoes.isEmpty) const Text('Ainda não registada.'),
            for (final b in d.declaracoes)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text('${b['emitida_por']}'),
                subtitle: Text('Emitida em ${b['data_emissao']}'
                    '${b['validade'] != null ? ' · válida até ${b['validade']}' : ''}'),
              ),
            _seccao(context, '3. Líderes dos mercados', 'Registar', _lider),
            if (d.lideres.isEmpty) const Text('Sem confirmações.'),
            for (final c in d.lideres)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  c['confirmado'] == 1 ? Icons.check_circle : Icons.cancel,
                  color: c['confirmado'] == 1 ? Colors.green : Colors.red,
                ),
                title: Text('${c['nome']} (${c['mercado']})'),
                subtitle: Text(
                    '${_factos[c['facto']] ?? c['facto']} · ${soData(c['data'])}'),
              ),
            _seccao(context, '4. Visita ao negócio', 'Nova ficha', _visita),
            if (d.fichas.isEmpty) const Text('Sem visitas registadas.'),
            for (final f in d.fichas)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  (f['local_confirmado'] == 1 && f['atividade_confirmada'] == 1)
                      ? Icons.check_circle
                      : Icons.warning_amber,
                  color: (f['local_confirmado'] == 1 && f['atividade_confirmada'] == 1)
                      ? Colors.green
                      : Colors.orange,
                ),
                title: Text('Visita de ${soData(f['data'])}'),
                subtitle: Text([
                  'local ${f['local_confirmado'] == 1 ? 'confirmado' : 'NÃO confirmado'}',
                  'atividade ${f['atividade_confirmada'] == 1 ? 'confirmada' : 'NÃO confirmada'}',
                  if (f['stock_observado'] != null) 'stock: ${f['stock_observado']}',
                ].join(' · ')),
              ),
          ],
        );
      },
    );
  }

  Widget _seccao(BuildContext context, String texto, String botao, VoidCallback aoClicar) =>
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Row(
          children: [
            Expanded(child: Text(texto, style: Theme.of(context).textTheme.titleMedium)),
            OutlinedButton(onPressed: aoClicar, child: Text(botao)),
          ],
        ),
      );
}
