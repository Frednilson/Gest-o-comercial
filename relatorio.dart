import 'venda.dart';

class DiaVenda {
  const DiaVenda(this.dia, this.total);
  final DateTime dia;
  final double total;
}

class ProdutoVendido {
  const ProdutoVendido({required this.nome, required this.quantidade, required this.total});
  final String nome;
  final int quantidade;
  final double total;
}

class DashboardData {
  const DashboardData({
    required this.vendasHoje,
    required this.numVendasHoje,
    required this.totalProdutos,
    required this.stockBaixo,
    required this.despesasHoje,
    required this.lucroEstimado,
    required this.vendas7Dias,
    required this.maisVendidos,
    required this.ultimasVendas,
  });

  final double vendasHoje;
  final int numVendasHoje;
  final int totalProdutos;
  final int stockBaixo;
  final double despesasHoje;
  final double lucroEstimado;
  final List<DiaVenda> vendas7Dias;
  final List<ProdutoVendido> maisVendidos;
  final List<Venda> ultimasVendas;
}

/// Estrutura genérica de relatório (ecrã + PDF).
class ReportData {
  const ReportData({
    required this.titulo,
    required this.periodo,
    required this.colunas,
    required this.linhas,
    this.resumo = const {},
    this.colunasNumericas = const {},
  });

  final String titulo;
  final String periodo;
  final List<String> colunas;
  final List<List<String>> linhas;

  /// Totais apresentados no topo (rótulo -> valor), por ordem.
  final Map<String, String> resumo;

  /// Índices das colunas alinhadas à direita.
  final Set<int> colunasNumericas;
}
