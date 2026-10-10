import 'package:flutter/material.dart';

import '../services/tema_service.dart';

/// Botão para escolher entre modo claro, escuro e automático.
class BotaoTema extends StatelessWidget {
  final Color? cor;
  const BotaoTema({super.key, this.cor});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: TemaService.modo,
      builder: (context, atual, _) {
        final icone = switch (atual) {
          ThemeMode.light => Icons.light_mode,
          ThemeMode.dark => Icons.dark_mode,
          ThemeMode.system => Icons.brightness_auto,
        };
        return PopupMenuButton<ThemeMode>(
          tooltip: 'Aparência',
          icon: Icon(icone, color: cor),
          initialValue: atual,
          onSelected: TemaService.definir,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: ThemeMode.light,
              child: ListTile(
                  dense: true,
                  leading: Icon(Icons.light_mode),
                  title: Text('Claro')),
            ),
            PopupMenuItem(
              value: ThemeMode.dark,
              child: ListTile(
                  dense: true,
                  leading: Icon(Icons.dark_mode),
                  title: Text('Escuro')),
            ),
            PopupMenuItem(
              value: ThemeMode.system,
              child: ListTile(
                  dense: true,
                  leading: Icon(Icons.brightness_auto),
                  title: Text('Automático (como o telemóvel)')),
            ),
          ],
        );
      },
    );
  }
}
