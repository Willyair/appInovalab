import 'package:flutter/material.dart';

import '../../services/candidatura_service.dart';
import '../../widgets/comum.dart';

class NovaCandidaturaScreen extends StatefulWidget {
  /// Se vier preenchido, o ecrã edita essa candidatura em vez de criar.
  final String? candidaturaId;
  const NovaCandidaturaScreen({super.key, this.candidaturaId});

  @override
  State<NovaCandidaturaScreen> createState() => _NovaCandidaturaScreenState();
}

class _NovaCandidaturaScreenState extends State<NovaCandidaturaScreen> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _doc = TextEditingController();
  final _tel = TextEditingController();
  final _bairro = TextEditingController();
  final _atividade = TextEditingController();
  final _local = TextEditingController();
  final _inicio = TextEditingController();
  final _finalidade = TextEditingController();
  final _valor = TextEditingController();
  final _prazo = TextEditingController(text: '6');
  bool _primeiro = true;
  bool _aGuardar = false;
  bool _aCarregar = false;

  bool get _editar => widget.candidaturaId != null;

  @override
  void initState() {
    super.initState();
    if (_editar) {
      _aCarregar = true;
      _preencher();
    }
  }

  Future<void> _preencher() async {
    final r = await CandidaturaService.resumo(widget.candidaturaId!);
    _nome.text = (r['nome'] as String?) ?? '';
    _doc.text = (r['documento_identificacao'] as String?) ?? '';
    _tel.text = (r['telefone'] as String?) ?? '';
    _bairro.text = (r['bairro'] as String?) ?? '';
    _atividade.text = (r['atividade'] as String?) ?? '';
    _local.text = (r['localizacao'] as String?) ?? '';
    _inicio.text = (r['inicio_atividade'] as String?) ?? '';
    _finalidade.text = (r['finalidade_financiamento'] as String?) ?? '';
    _valor.text = '${((r['valor_pedido'] as num?) ?? 0).round()}';
    _prazo.text = '${(r['prazo_meses'] as int?) ?? 6}';
    _primeiro = r['primeiro_credito'] == 1;
    if (mounted) setState(() => _aCarregar = false);
  }

  @override
  void dispose() {
    for (final c in [_nome, _doc, _tel, _bairro, _atividade, _local, _inicio, _finalidade, _valor, _prazo]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _obrig(String? v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null;

  Widget _campo(String rotulo, TextEditingController c,
          {bool obrigatorio = false, TextInputType? tipo, int linhas = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: tipo,
          maxLines: linhas,
          validator: obrigatorio ? _obrig : null,
          decoration: InputDecoration(
            labelText: obrigatorio ? '$rotulo *' : rotulo,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final valor = lerNumero(_valor.text);
    final prazo = int.tryParse(_prazo.text.trim());
    if (valor == null || valor <= 0 || prazo == null || prazo <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Valor e prazo têm de ser números positivos.')));
      return;
    }
    setState(() => _aGuardar = true);
    String? id;
    final ok = await executar(context, () async {
      if (_editar) {
        await CandidaturaService.atualizarDados(
          widget.candidaturaId!,
          nome: _nome.text,
          documentoIdentificacao: _doc.text,
          telefone: _tel.text,
          bairro: _bairro.text,
          atividade: _atividade.text,
          localizacao: _local.text,
          inicioAtividade: _inicio.text,
          finalidade: _finalidade.text,
          valor: valor,
          prazoMeses: prazo,
          primeiroCredito: _primeiro,
        );
        id = widget.candidaturaId;
        return;
      }
      id = await CandidaturaService.criar(
        nome: _nome.text,
        documentoIdentificacao: _doc.text,
        telefone: _tel.text,
        bairro: _bairro.text,
        atividade: _atividade.text,
        localizacao: _local.text,
        inicioAtividade: _inicio.text,
        finalidade: _finalidade.text,
        valor: valor,
        prazoMeses: prazo,
        primeiroCredito: _primeiro,
      );
    });
    if (!mounted) return;
    setState(() => _aGuardar = false);
    if (ok) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    if (_aCarregar) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar candidatura')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_editar ? 'Editar candidatura' : 'Nova candidatura')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Beneficiária', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _campo('Nome completo', _nome, obrigatorio: true),
            _campo('Nº do documento de identificação', _doc, obrigatorio: true),
            _campo('Telefone', _tel, tipo: TextInputType.phone),
            _campo('Bairro', _bairro),
            titulo(context, 'Negócio'),
            _campo('Atividade', _atividade, obrigatorio: true),
            _campo('Localização (mercado, banca…)', _local),
            _campo('Início da atividade (ano ou data)', _inicio),
            _campo('Finalidade do financiamento', _finalidade,
                obrigatorio: true, linhas: 2),
            titulo(context, 'Pedido'),
            _campo('Valor pedido (MZN)', _valor,
                obrigatorio: true, tipo: TextInputType.number),
            _campo('Prazo (meses)', _prazo, obrigatorio: true, tipo: TextInputType.number),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Primeiro crédito'),
              value: _primeiro,
              onChanged: (v) => setState(() => _primeiro = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _aGuardar ? null : _guardar,
              child: Text(_editar ? 'Guardar alterações' : 'Criar candidatura'),
            ),
          ],
        ),
      ),
    );
  }
}
