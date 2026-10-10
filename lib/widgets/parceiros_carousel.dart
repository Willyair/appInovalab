import 'package:flutter/material.dart';

import '../models/parceiro.dart';

class ParceirosCarousel extends StatelessWidget {
  final List<Parceiro> parceiros;

  const ParceirosCarousel({super.key, required this.parceiros});

  @override
  Widget build(BuildContext context) {
    if (parceiros.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Ainda não há parceiros nem financeiros registados.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: parceiros.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final p = parceiros[i];
          return Container(
            width: 120,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  p.tipo == 'financeiro' ? Icons.account_balance : Icons.handshake,
                  size: 22,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 6),
                Text(
                  p.nome,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
