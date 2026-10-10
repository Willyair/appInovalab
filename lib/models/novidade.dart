class Novidade {
  final String id;
  final String titulo;
  final String? texto;
  final DateTime data;

  const Novidade({
    required this.id,
    required this.titulo,
    this.texto,
    required this.data,
  });

  factory Novidade.fromMap(Map<String, Object?> m) => Novidade(
        id: m['id'] as String,
        titulo: m['titulo'] as String,
        texto: m['texto'] as String?,
        data: DateTime.parse(m['data'] as String),
      );
}
