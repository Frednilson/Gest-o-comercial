class Produto {
  const Produto({
    this.id,
    required this.nome,
    this.descricao,
    this.categoriaId,
    this.categoriaNome,
    this.precoCompra = 0,
    this.precoVenda = 0,
    this.quantidade = 0,
    this.stockMinimo = 0,
    this.codigoBarras,
    this.imagem,
    this.ativo = true,
    required this.dataCadastro,
  });

  final int? id;
  final String nome;
  final String? descricao;
  final int? categoriaId;
  final String? categoriaNome;
  final double precoCompra;
  final double precoVenda;
  final int quantidade;
  final int stockMinimo;
  final String? codigoBarras;
  final String? imagem;
  final bool ativo;
  final DateTime dataCadastro;

  bool get semStock => quantidade <= 0;
  bool get stockBaixo => quantidade <= stockMinimo;

  factory Produto.fromMap(Map<String, Object?> m) => Produto(
        id: m['id'] as int?,
        nome: m['nome'] as String,
        descricao: m['descricao'] as String?,
        categoriaId: m['categoria_id'] as int?,
        categoriaNome: m['categoria_nome'] as String?,
        precoCompra: (m['preco_compra'] as num).toDouble(),
        precoVenda: (m['preco_venda'] as num).toDouble(),
        quantidade: (m['quantidade'] as num).toInt(),
        stockMinimo: (m['stock_minimo'] as num).toInt(),
        codigoBarras: m['codigo_barras'] as String?,
        imagem: m['imagem'] as String?,
        ativo: (m['ativo'] as int? ?? 1) == 1,
        dataCadastro: DateTime.parse(m['data_cadastro'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'nome': nome,
        'descricao': descricao,
        'categoria_id': categoriaId,
        'preco_compra': precoCompra,
        'preco_venda': precoVenda,
        'quantidade': quantidade,
        'stock_minimo': stockMinimo,
        'codigo_barras': codigoBarras,
        'imagem': imagem,
        'ativo': ativo ? 1 : 0,
        'data_cadastro': dataCadastro.toIso8601String(),
      };

  Produto copyWith({int? quantidade}) => Produto(
        id: id,
        nome: nome,
        descricao: descricao,
        categoriaId: categoriaId,
        categoriaNome: categoriaNome,
        precoCompra: precoCompra,
        precoVenda: precoVenda,
        quantidade: quantidade ?? this.quantidade,
        stockMinimo: stockMinimo,
        codigoBarras: codigoBarras,
        imagem: imagem,
        ativo: ativo,
        dataCadastro: dataCadastro,
      );
}
