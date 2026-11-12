import '../core/constants/app_constants.dart';

class ItemVenda {
  const ItemVenda({
    this.id,
    this.vendaId,
    this.produtoId,
    required this.nomeProduto,
    required this.quantidade,
    required this.precoUnitario,
    required this.custoUnitario,
    required this.subtotal,
  });

  final int? id;
  final int? vendaId;
  final int? produtoId;
  final String nomeProduto;
  final int quantidade;
  final double precoUnitario;
  final double custoUnitario;
  final double subtotal;

  factory ItemVenda.fromMap(Map<String, Object?> m) => ItemVenda(
        id: m['id'] as int?,
        vendaId: m['venda_id'] as int?,
        produtoId: m['produto_id'] as int?,
        nomeProduto: m['nome_produto'] as String,
        quantidade: (m['quantidade'] as num).toInt(),
        precoUnitario: (m['preco_unitario'] as num).toDouble(),
        custoUnitario: (m['custo_unitario'] as num).toDouble(),
        subtotal: (m['subtotal'] as num).toDouble(),
      );
}

class Pagamento {
  const Pagamento({
    this.id,
    this.vendaId,
    required this.metodo,
    required this.valor,
    required this.data,
  });

  final int? id;
  final int? vendaId;
  final String metodo;
  final double valor;
  final DateTime data;

  factory Pagamento.fromMap(Map<String, Object?> m) => Pagamento(
        id: m['id'] as int?,
        vendaId: m['venda_id'] as int?,
        metodo: m['metodo_pagamento'] as String,
        valor: (m['valor'] as num).toDouble(),
        data: DateTime.parse(m['data_pagamento'] as String),
      );
}

class Venda {
  const Venda({
    this.id,
    required this.numeroVenda,
    this.clienteId,
    this.clienteNome,
    required this.subtotal,
    required this.desconto,
    required this.total,
    required this.valorRecebido,
    required this.troco,
    required this.estado,
    required this.dataVenda,
    this.itens = const [],
    this.pagamentos = const [],
  });

  final int? id;
  final String numeroVenda;
  final int? clienteId;
  final String? clienteNome;
  final double subtotal;
  final double desconto;
  final double total;
  final double valorRecebido;
  final double troco;

  /// paga | pendente | cancelada
  final String estado;
  final DateTime dataVenda;
  final List<ItemVenda> itens;
  final List<Pagamento> pagamentos;

  double get valorEmFalta => (total - valorRecebido) > 0.004 ? total - valorRecebido : 0;
  bool get cancelada => estado == 'cancelada';

  String get estadoLabel {
    switch (estado) {
      case 'paga':
        return 'Paga';
      case 'pendente':
        return 'Pendente';
      case 'cancelada':
        return 'Cancelada';
      default:
        return estado;
    }
  }

  /// Ex.: "M-Pesa" ou "Misto (Dinheiro + M-Pesa)".
  String get metodoResumo {
    final metodos = pagamentos.map((p) => p.metodo).toSet().toList();
    if (metodos.isEmpty) return 'Sem pagamento';
    if (metodos.length == 1) return AppConstants.paymentLabel(metodos.first);
    return 'Misto (${metodos.map(AppConstants.paymentLabel).join(' + ')})';
  }

  Venda copyWith({List<ItemVenda>? itens, List<Pagamento>? pagamentos}) => Venda(
        id: id,
        numeroVenda: numeroVenda,
        clienteId: clienteId,
        clienteNome: clienteNome,
        subtotal: subtotal,
        desconto: desconto,
        total: total,
        valorRecebido: valorRecebido,
        troco: troco,
        estado: estado,
        dataVenda: dataVenda,
        itens: itens ?? this.itens,
        pagamentos: pagamentos ?? this.pagamentos,
      );

  factory Venda.fromMap(Map<String, Object?> m) => Venda(
        id: m['id'] as int?,
        numeroVenda: m['numero_venda'] as String,
        clienteId: m['cliente_id'] as int?,
        clienteNome: m['cliente_nome'] as String?,
        subtotal: (m['subtotal'] as num).toDouble(),
        desconto: (m['desconto'] as num).toDouble(),
        total: (m['total'] as num).toDouble(),
        valorRecebido: (m['valor_recebido'] as num).toDouble(),
        troco: (m['troco'] as num).toDouble(),
        estado: m['estado'] as String,
        dataVenda: DateTime.parse(m['data_venda'] as String),
      );
}
