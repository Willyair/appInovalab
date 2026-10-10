import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/candidatura_service.dart';
import '../../util/atualizacao.dart';
import '../../widgets/comum.dart';
import 'nova_candidatura_screen.dart';
import 'tab_acompanhamento.dart';
import 'tab_documentos.dart';
import 'tab_financeira.dart';
import 'tab_risco.dart';
import 'tab_verificacao.dart';

class CandidaturaDetalheScreen extends StatefulWidget {
  final String candidaturaId;
  const CandidaturaDetalheScreen({super.key, required this.candidaturaId});

  @override
  State<CandidaturaDetalheScreen> createState() => _CandidaturaDetalheScreenState();
}

class _CandidaturaDetalheScreenState extends State<CandidaturaDetalheScreen> {
  late Future<Linha> _resumo;

  @override
  void initState() {
    super.initState();
    _resumo = CandidaturaService.resumo(widget.candidaturaId);
    Atualizacao.versao.addListener(_recarregar);
  }

  @override
  void dispose() {
    Atualizacao.versao.removeListener(_recarregar);
    super.dispose();
  }

  void _recarregar() {
    if (!mounted) return;
    setState(() => _resumo = CandidaturaService.resumo(widget.candidaturaId));
  }

  Future<void> _acesso(Linha r) async {
    final nome = r['nome'] as String;
    final tel = (r['telefone'] as String?) ?? '';
    final sim = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Acesso da Mamana'),
        content: Text(
          'Criar (ou repor) o acesso de $nome à aplicação?\n\n'
          'O identificador será o telefone ${tel.isEmpty ? '(falta registar o telefone)' : tel}. '
          'Vai ser gerado um PIN que só aparece uma vez: entrega-o a ela pessoalmente. '
          'Só crias o acesso com o consentimento dela.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Gerar acesso')),
        ],
      ),
    );
    if (sim != true || !mounted) return;
    ({String login, String pin, bool novo})? acesso;
    final ok = await executar(context, () async {
      acesso = await AuthService.criarAcessoBeneficiaria(r['beneficiaria_id'] as String);
    });
    if (!ok || acesso == null || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(acesso!.novo ? 'Acesso criado' : 'PIN reposto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Identificador:'),
            SelectableText(acesso!.login, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text('PIN (só aparece agora):'),
            SelectableText(acesso!.pin, style: Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height: 12),
            const Text('Pede-lhe para mudar o PIN no primeiro acesso (menu do ecrã "O meu pedido").',
                style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Já anotei'))],
      ),
    );
  }

  Future<void> _editar() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NovaCandidaturaScreen(candidaturaId: widget.candidaturaId),
    ));
    _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Linha>(
      future: _resumo,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: snap.hasError
                  ? Text('Erro: ${snap.error}')
                  : const CircularProgressIndicator(),
            ),
          );
        }
        final r = snap.data!;
        return DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              title: Text(r['nome'] as String),
              actions: [
                IconButton(
                  tooltip: 'Acesso da Mamana',
                  icon: const Icon(Icons.key),
                  onPressed: () => _acesso(r),
                ),
                IconButton(
                  tooltip: 'Editar dados',
                  icon: const Icon(Icons.edit),
                  onPressed: _editar,
                ),
                if (kDebugMode)
                  PopupMenuButton<String>(
                    tooltip: 'Definir estado (só desenvolvimento)',
                    icon: const Icon(Icons.bug_report_outlined),
                    onSelected: (e) => executar(
                        context, () => CandidaturaService.definirEstadoDev(widget.candidaturaId, e)),
                    itemBuilder: (_) => [
                      for (final e in CandidaturaService.ordemEstados)
                        PopupMenuItem(value: e, child: Text('Estado: ${rotuloEstado(e)}')),
                    ],
                  ),
              ],
              bottom: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Documentos'),
                  Tab(text: 'Verificação'),
                  Tab(text: 'Financeira'),
                  Tab(text: 'Risco'),
                  Tab(text: 'Acompanhamento'),
                ],
              ),
            ),
            body: Column(
              children: [
                _Cabecalho(r),
                Expanded(
                  child: TabBarView(
                    children: [
                      TabDocumentos(candidaturaId: widget.candidaturaId, aoAlterar: _recarregar),
                      TabVerificacao(candidaturaId: widget.candidaturaId, aoAlterar: _recarregar),
                      TabFinanceira(
                        candidaturaId: widget.candidaturaId,
                        valorPedido: (r['valor_pedido'] as num?)?.toDouble() ?? 0,
                        prazoMeses: (r['prazo_meses'] as int?) ?? 0,
                        aoAlterar: _recarregar,
                      ),
                      TabRisco(candidaturaId: widget.candidaturaId, aoAlterar: _recarregar),
                      TabAcompanhamento(candidaturaId: widget.candidaturaId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Cabecalho extends StatelessWidget {
  final Linha r;
  const _Cabecalho(this.r);

  @override
  Widget build(BuildContext context) {
    final linhas = <String>[
      if (r['atividade'] != null) r['atividade'] as String,
      if (r['localizacao'] != null && (r['localizacao'] as String).isNotEmpty)
        r['localizacao'] as String,
      '${formatarMzn((r['valor_pedido'] as num?) ?? 0)} em ${r['prazo_meses'] ?? '?'} meses',
    ];
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(linhas.join(' · ')),
                const SizedBox(height: 2),
                Text('Estado: ${rotuloEstado(r['estado'] as String)}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          EtiquetaRisco(r['classificacao'] as String?),
        ],
      ),
    );
  }
}
