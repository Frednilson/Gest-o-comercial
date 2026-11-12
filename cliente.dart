class Cliente {
  const Cliente({
    this.id,
    required this.nome,
    this.telefone,
    this.endereco,
    this.observacoes,
    required this.dataCadastro,
  });

  final int? id;
  final String nome;
  final String? telefone;
  final String? endereco;
  final String? observacoes;
  final DateTime dataCadastro;

  factory Cliente.fromMap(Map<String, Object?> m) => Cliente(
        id: m['id'] as int?,
        nome: m['nome'] as String,
        telefone: m['telefone'] as String?,
        endereco: m['endereco'] as String?,
        observacoes: m['observacoes'] as String?,
        dataCadastro: DateTime.parse(m['data_cadastro'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'nome': nome,
        'telefone': telefone,
        'endereco': endereco,
        'observacoes': observacoes,
        'data_cadastro': dataCadastro.toIso8601String(),
      };
}
