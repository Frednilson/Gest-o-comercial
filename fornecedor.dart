class Fornecedor {
  const Fornecedor({
    this.id,
    required this.nome,
    this.empresa,
    this.telefone,
    this.email,
    this.endereco,
    this.observacoes,
    required this.dataCadastro,
  });

  final int? id;
  final String nome;
  final String? empresa;
  final String? telefone;
  final String? email;
  final String? endereco;
  final String? observacoes;
  final DateTime dataCadastro;

  factory Fornecedor.fromMap(Map<String, Object?> m) => Fornecedor(
        id: m['id'] as int?,
        nome: m['nome'] as String,
        empresa: m['empresa'] as String?,
        telefone: m['telefone'] as String?,
        email: m['email'] as String?,
        endereco: m['endereco'] as String?,
        observacoes: m['observacoes'] as String?,
        dataCadastro: DateTime.parse(m['data_cadastro'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'nome': nome,
        'empresa': empresa,
        'telefone': telefone,
        'email': email,
        'endereco': endereco,
        'observacoes': observacoes,
        'data_cadastro': dataCadastro.toIso8601String(),
      };
}
