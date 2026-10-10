import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../services/candidatura_service.dart';
import '../../util/atualizacao.dart';
import '../../util/seletor_ficheiros.dart';
import '../../widgets/comum.dart';

class TabDocumentos extends StatefulWidget {
  final String candidaturaId;
  final VoidCallback aoAlterar;
  const TabDocumentos({super.key, required this.candidaturaId, required this.aoAlterar});

  @override
  State<TabDocumentos> createState() => _TabDocumentosState();
}

class _TabDocumentosState extends State<TabDocumentos> {
  late Future<List<Linha>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = CandidaturaService.documentos(widget.candidaturaId);
    Atualizacao.versao.addListener(_refrescar);
  }

  @override
  void dispose() {
    Atualizacao.versao.removeListener(_refrescar);
    super.dispose();
  }

  void _refrescar() {
    if (!mounted) return;
    setState(() => _futuro = CandidaturaService.documentos(widget.candidaturaId));
  }

  Future<void> _anexar(Linha d) async {
    final f = await escolherFicheiro();
    if (f == null || !mounted) return;
    final ok = await executar(
        context,
        () => CandidaturaService.anexarDocumento(widget.candidaturaId, d['id'] as String,
            origem: f.caminho, nomeOriginal: f.nome));
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Anexado: ${f.nome}')));
    }
  }

  Future<void> _abrir(Linha d) async {
    final caminho =
        await CandidaturaService.caminhoAbsoluto(d['ficheiro_path'] as String);
    final r = await OpenFilex.open(caminho);
    if (r.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não consegui abrir o ficheiro: ${r.message}')));
    }
  }

  Future<void> _remover(Linha d) async {
    final sim = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover anexo?'),
        content: Text(CandidaturaService.nomeAnexo(d['ficheiro_path'] as String)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
        ],
      ),
    );
    if (sim != true || !mounted) return;
    await executar(context,
        () => CandidaturaService.removerAnexo(widget.candidaturaId, d['id'] as String));
  }

  void _recarregar() {
    setState(() => _futuro = CandidaturaService.documentos(widget.candidaturaId));
    widget.aoAlterar();
  }

  Future<void> _alternar(Linha d, bool entregue) async {
    final ok = await executar(context, () => CandidaturaService.atualizarDocumento(
          widget.candidaturaId,
          d['id'] as String,
          entregue: entregue,
          validade: d['validade'] as String?,
          observacao: d['observacao'] as String?,
        ));
    if (ok) _recarregar();
  }

  Future<void> _editarNota(Linha d) async {
    final validade = TextEditingController(text: (d['validade'] as String?) ?? '');
    final obs = TextEditingController(text: (d['observacao'] as String?) ?? '');
    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(d['titulo'] as String),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: validade,
              decoration: const InputDecoration(
                  labelText: 'Validade (AAAA-MM-DD)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: obs,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Observação', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    final v = validade.text, o = obs.text;
    validade.dispose();
    obs.dispose();
    if (guardar != true || !mounted) return;
    final ok = await executar(context, () => CandidaturaService.atualizarDocumento(
          widget.candidaturaId,
          d['id'] as String,
          entregue: d['entregue'] == 1,
          validade: v,
          observacao: o,
        ));
    if (ok) _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Linha>>(
      future: _futuro,
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!;
        final obrig = docs.where((d) => d['obrigatorio'] == 1).toList();
        final ok = obrig.where((d) => d['entregue'] == 1).length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Obrigatórios entregues: $ok/${obrig.length}',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: obrig.isEmpty ? 0 : ok / obrig.length),
            const SizedBox(height: 12),
            for (final d in docs)
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      value: d['entregue'] == 1,
                      onChanged: (v) => _alternar(d, v ?? false),
                      title: Text(d['titulo'] as String),
                      subtitle: Text([
                        d['obrigatorio'] == 1 ? 'Obrigatório' : 'Quando aplicável',
                        if (d['ficheiro_path'] != null && d['entregue'] == 0)
                          'Anexo enviado — por validar',
                        if (d['validade'] != null) 'validade ${d['validade']}',
                        if (d['observacao'] != null) d['observacao'] as String,
                      ].join(' · ')),
                      secondary: IconButton(
                        tooltip: 'Validade e observação',
                        icon: const Icon(Icons.edit_note),
                        onPressed: () => _editarNota(d),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          if (d['ficheiro_path'] != null) ...[
                            const Icon(Icons.attach_file, size: 18),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(
                                CandidaturaService.nomeAnexo(d['ficheiro_path'] as String),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(onPressed: () => _abrir(d), child: const Text('Abrir')),
                            TextButton(
                                onPressed: () => _anexar(d), child: const Text('Substituir')),
                            TextButton(
                                onPressed: () => _remover(d), child: const Text('Remover')),
                          ] else
                            OutlinedButton.icon(
                              onPressed: () => _anexar(d),
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Anexar ficheiro (PDF, JPG, PNG)'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
