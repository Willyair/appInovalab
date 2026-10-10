enum Papel { mzn, inovalab, mamana }

class Perfil {
  final String id;
  final String nome;
  final Papel papel;
  final bool ativo;

  const Perfil({
    required this.id,
    required this.nome,
    required this.papel,
    required this.ativo,
  });

  factory Perfil.fromMap(Map<String, Object?> m) => Perfil(
        id: m['id'] as String,
        nome: m['nome'] as String,
        papel: Papel.values.firstWhere((p) => p.name == m['papel']),
        ativo: (m['ativo'] as int) == 1,
      );

  String get papelRotulo => switch (papel) {
        Papel.mzn => 'MZN Microcrédito',
        Papel.inovalab => 'Fundação InovaLab',
        Papel.mamana => 'Mamana Empreendedora',
      };
}
