import 'package:flutter/material.dart';

import 'logo_dados.dart';

/// Logo da Fundação InovaLab. Se [branco] não for indicado, escolhe sozinho:
/// preto no tema claro, branco no tema escuro.
class LogoInovalab extends StatelessWidget {
  final double altura;
  final bool? branco;
  const LogoInovalab({super.key, this.altura = 96, this.branco});

  @override
  Widget build(BuildContext context) {
    final usarBranco = branco ?? (Theme.of(context).brightness == Brightness.dark);
    return Semantics(
      label: 'Fundação InovaLab',
      image: true,
      child: Image.memory(
        usarBranco ? logoBrancoPng : logoPretoPng,
        height: altura,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
