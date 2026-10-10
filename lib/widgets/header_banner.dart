import 'package:flutter/material.dart';

import '../models/perfil.dart';
import 'botao_tema.dart';
import 'logo_inovalab.dart';

/// Header do dashboard. O logo é o da Fundação InovaLab. A imagem de fundo
/// (proporção 6:4) é, por agora, um gradiente de cor — basta trocar o
/// `DecoratedBox` por uma Image quando houver a imagem real (ver LEIA-ME).
class HeaderBanner extends StatelessWidget implements PreferredSizeWidget {
  final Perfil perfil;
  final String slogan;
  final VoidCallback aoSair;

  const HeaderBanner({
    super.key,
    required this.perfil,
    required this.slogan,
    required this.aoSair,
  });

  @override
  Size get preferredSize => const Size.fromHeight(220);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: preferredSize.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Imagem 6:4 do banner (placeholder em gradiente por agora).
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primaryContainer,
                ],
              ),
            ),
          ),
          // Película escura suave, para o texto ficar legível.
          const DecoratedBox(
            decoration: BoxDecoration(color: Colors.black26),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // Logo da Fundação (branco: o cabeçalho tem sempre fundo escurecido).
                      const LogoInovalab(altura: 56, branco: true),
                      const Spacer(),
                      const BotaoTema(cor: Colors.white),
                      IconButton(
                        tooltip: 'Sair',
                        onPressed: aoSair,
                        icon: const Icon(Icons.logout, color: Colors.white),
                      ),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white,
                        child: Text(
                          perfil.nome.isNotEmpty ? perfil.nome[0] : '?',
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    slogan,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${perfil.nome} · ${perfil.papelRotulo}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
