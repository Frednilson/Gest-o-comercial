class Despesa {
  const Despesa({
    this.id,
    required this.categoria,
    this.descricao,
    required this.valor,
    required this.data,
  });

  final int? id;
  final String categoria;
  final String? descricao;
  final double valor;
  final DateTime data;

  factory Despesa.fromMap(Map<String, Object?> m) => Despesa(
        id: m['id'] as int?,
        categoria: m['categoria'] as String,
        descricao: m['descricao'] as String?,
        valor: (m['valor'] as num).toDouble(),
        data: DateTime.parse(m['data'] as String),
      );

  /// A data é guardada como 'yyyy-MM-dd'.
  Map<String, Object?> toMap() {
    final d = '${data.year.toString().padLeft(4, '0')}-'
        '${data.month.toString().padLeft(2, '0')}-'
        '${data.day.toString().padLeft(2, '0')}';
    return {
      if (id != null) 'id': id,
      'categoria': categoria,
      'descricao': descricao,
      'valor': valor,
      'data': d,
    };
  }
}
