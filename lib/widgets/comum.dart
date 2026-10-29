import 'package:flutter/material.dart';

String formatarMzn(num v) {
  final neg = v < 0;
  final s = v.abs().round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '${neg ? '-' : ''}$b MZN';
}

String soData(Object? iso) {
  final s = (iso as String?) ?? '';
  return s.length >= 10 ? s.substring(0, 10) : s;
}

/// Lê um número escrito à mão. Aceita "15000", "15 000", "15.000",
/// "15.000,50", "15,000.50" e "1500,5". Devolve null se não for um número.
///
/// Atenção: "15.000" lê-se como quinze mil (ponto como separador de milhares,
/// como é costume em português); antes lia-se como 15 — um erro silencioso.
double? lerNumero(String t) {
  var s = t.trim().replaceAll(RegExp(r'[\s ]'), '');
  if (s.isEmpty) return null;
  final temPonto = s.contains('.');
  final temVirgula = s.contains(',');
  if (temPonto && temVirgula) {
    // O último separador é o decimal; o outro é de milhares.
    if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (temVirgula) {
    // "1,500,000" (grupos de 3) = milhares; "1500,5" = decimal.
    s = RegExp(r'^\d{1,3}(,\d{3}){2,}$').hasMatch(s)
        ? s.replaceAll(',', '')
        : s.replaceAll(',', '.');
  } else if (temPonto) {
    // "15.000" ou "1.500.000" = milhares; "15000.5" = decimal.
    if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) s = s.replaceAll('.', '');
  }
  final v = double.tryParse(s);
  if (v == null || v.isNaN || v.isInfinite) return null; // "NaN" e "Infinity" passavam
  return v;
}

String rotuloEstado(String e) => switch (e) {
      'recebida' => 'Recebida',
      'identidade_verificada' => 'Identidade verificada',
      'confirmacao_comunitaria' => 'Confirmação comunitária',
      'negocio_verificado' => 'Negócio verificado',
      'analise_financeira' => 'Análise financeira',
      'risco_classificado' => 'Risco classificado',
      'medidas_definidas' => 'Medidas definidas',
      'encaminhada' => 'Encaminhada à MZN',
      'decidida' => 'Decidida',
      'recusada' => 'Recusada',
      'formalizada' => 'Formalizada',
      'desembolsada' => 'Desembolsada',
      'em_monitoria' => 'Em acompanhamento',
      _ => e,
    };

Color corNivel(String? nivel, [Brightness brilho = Brightness.light]) {
  final escuro = brilho == Brightness.dark;
  return switch (nivel) {
    'baixo' => escuro ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32),
    'moderado' => escuro ? const Color(0xFFFFA726) : const Color(0xFFEF6C00),
    'elevado' => escuro ? const Color(0xFFEF5350) : const Color(0xFFC62828),
    _ => Colors.grey,
  };
}

String rotuloNivelTexto(String? nivel) => switch (nivel) {
      'baixo' => 'Risco baixo',
      'moderado' => 'Risco moderado',
      'elevado' => 'Risco elevado',
      _ => 'Sem classificação',
    };

class EtiquetaRisco extends StatelessWidget {
  final String? nivel;
  const EtiquetaRisco(this.nivel, {super.key});

  @override
  Widget build(BuildContext context) {
    final cor = corNivel(nivel, Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        border: Border.all(color: cor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(rotuloNivelTexto(nivel),
          style: TextStyle(color: cor, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

/// Corre uma ação e mostra o erro numa barra, em vez de rebentar.
Future<bool> executar(BuildContext context, Future<void> Function() acao) async {
  try {
    await acao();
    return true;
  } catch (e) {
    if (context.mounted) {
      final msg = e is StateError ? e.message : e.toString();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
    }
    return false;
  }
}

Widget titulo(BuildContext context, String texto) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
    );

/// Texto simples, para a Mamana, sobre em que ponto está o pedido.
String rotuloEstadoMamana(String e) => switch (e) {
      'recebida' => 'Pedido recebido. A equipa vai verificar os teus documentos.',
      'identidade_verificada' ||
      'confirmacao_comunitaria' ||
      'negocio_verificado' ||
      'analise_financeira' =>
        'O teu pedido está a ser analisado pela InovaLab.',
      'risco_classificado' ||
      'medidas_definidas' =>
        'Análise concluída. A InovaLab está a preparar o envio à MZN.',
      'encaminhada' => 'Enviado à MZN. Estamos a aguardar a decisão.',
      'decidida' => 'Aprovado! A MZN está a preparar o contrato.',
      'formalizada' => 'Contrato assinado. A aguardar a entrega do valor.',
      'desembolsada' => 'Crédito entregue. O acompanhamento vai começar.',
      'em_monitoria' => 'Em acompanhamento. Continua a pagar e a registar as tuas vendas.',
      'recusada' => 'O pedido não foi aprovado desta vez.',
      _ => e,
    };
