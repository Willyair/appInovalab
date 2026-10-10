class Parceiro {
  final String id;
  final String nome;
  final String tipo; // 'parceiro' ou 'financeiro'

  const Parceiro({required this.id, required this.nome, required this.tipo});

  factory Parceiro.fromMap(Map<String, Object?> m) => Parceiro(
        id: m['id'] as String,
        nome: m['nome'] as String,
        tipo: m['tipo'] as String,
      );
}
