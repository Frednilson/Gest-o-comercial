class Categoria {
  const Categoria({this.id, required this.nome, this.descricao});

  final int? id;
  final String nome;
  final String? descricao;

  factory Categoria.fromMap(Map<String, Object?> m) => Categoria(
        id: m['id'] as int?,
        nome: m['nome'] as String,
        descricao: m['descricao'] as String?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'nome': nome,
        'descricao': descricao,
      };
}
