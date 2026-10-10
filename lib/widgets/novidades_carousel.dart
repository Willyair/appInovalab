import 'package:flutter/material.dart';

import '../models/novidade.dart';

class NovidadesCarousel extends StatefulWidget {
  final List<Novidade> novidades;

  const NovidadesCarousel({super.key, required this.novidades});

  @override
  State<NovidadesCarousel> createState() => _NovidadesCarouselState();
}

class _NovidadesCarouselState extends State<NovidadesCarousel> {
  final _controlador = PageController(viewportFraction: 0.88);
  int _pagina = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.novidades.isEmpty) {
      return const _SeccaoVazia(texto: 'Ainda não há novidades publicadas.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _controlador,
            itemCount: widget.novidades.length,
            onPageChanged: (p) => setState(() => _pagina = p),
            itemBuilder: (context, i) {
              final n = widget.novidades[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.titulo,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            n.texto ?? '',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              widget.novidades.length,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _pagina
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }
}

class _SeccaoVazia extends StatelessWidget {
  final String texto;
  const _SeccaoVazia({required this.texto});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(texto, style: Theme.of(context).textTheme.bodyMedium),
      );
}
