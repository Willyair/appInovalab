import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../services/candidatura_service.dart';

/// Abre um anexo guardado (caminho relativo) com a app do sistema.
Future<void> abrirAnexo(BuildContext context, String relativo) async {
  final caminho = await CandidaturaService.caminhoAbsoluto(relativo);
  final r = await OpenFilex.open(caminho);
  if (r.type != ResultType.done && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não consegui abrir o ficheiro: ${r.message}')));
  }
}
