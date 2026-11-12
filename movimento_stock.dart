class MovimentoStock {
  const MovimentoStock({
    this.id,
    required this.produtoId,
    this.produtoNome,
    required this.tipo,
    required this.quantidade,
    this.stockApos,
    this.motivo,
    this.observacao,
    this.fornecedorId,
    this.fornecedorNome,
    this.vendaId,
    required this.data,
  });

  final int? id;
  final int produtoId;
  final String? produtoNome;

  /// entrada | saida | venda | devolucao | ajuste
  final String tipo;

  /// Variação com sinal (+ entra, - sai).
  final int quantidade;
  final int? stockApos;
  final String? motivo;
  final String? observacao;
  final int? fornecedorId;
  final String? fornecedorNome;
  final int? vendaId;
  final DateTime data;

  factory MovimentoStock.fromMap(Map<String, Object?> m) => MovimentoStock(
        id: m['id'] as int?,
        produtoId: m['produto_id'] as int,
        produtoNome: m['produto_nome'] as String?,
        tipo: m['tipo'] as String,
        quantidade: (m['quantidade'] as num).toInt(),
        stockApos: (m['stock_apos'] as num?)?.toInt(),
        motivo: m['motivo'] as String?,
        observacao: m['observacao'] as String?,
        fornecedorId: m['fornecedor_id'] as int?,
        fornecedorNome: m['fornecedor_nome'] as String?,
        vendaId: m['venda_id'] as int?,
        data: DateTime.parse(m['data'] as String),
      );
}
