import 'package:flutter/foundation.dart';

import '../models/categoria.dart';
import '../models/produto.dart';
import '../services/produto_service.dart';
import '../services/stock_service.dart';
import 'app_data.dart';

/// Produtos, categorias e movimentos de stock.
class ProductProvider extends ChangeNotifier {
  ProductProvider(this._bus) {
    _bus.addListener(load);
  }

  final AppData _bus;
  final _produtos = ProdutoService();
  final _stock = StockService();

  List<Produto> produtos = [];
  List<Categoria> categorias = [];
  String busca = '';
  int? categoriaId;
  bool loading = false;
  int _loadId = 0;

  Future<void> load() async {
    final id = ++_loadId;
    loading = true;
    notifyListeners();
    try {
      final p = await _produtos.listar(busca: busca, categoriaId: categoriaId);
      final c = await _produtos.listarCategorias();
      if (id != _loadId) return; // chegou uma pesquisa mais recente
      produtos = p;
      categorias = c;
    } finally {
      if (id == _loadId) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void setBusca(String value) {
    busca = value;
    load();
  }

  void setCategoria(int? id) {
    categoriaId = id;
    load();
  }

  Future<int> salvar(Produto p) async {
    final id = await _produtos.salvar(p);
    _bus.bump();
    return id;
  }

  /// Devolve true se foi eliminado; false se apenas desactivado (tem vendas).
  Future<bool> eliminar(int id) async {
    final eliminado = await _produtos.eliminar(id);
    _bus.bump();
    return eliminado;
  }

  Future<int> salvarCategoria(Categoria c) async {
    final id = await _produtos.salvarCategoria(c);
    _bus.bump();
    return id;
  }

  Future<void> eliminarCategoria(int id) async {
    await _produtos.eliminarCategoria(id);
    if (categoriaId == id) categoriaId = null;
    _bus.bump();
  }

  Future<void> registarMovimento({
    required int produtoId,
    required String tipo,
    required int quantidade,
    String? motivo,
    String? observacao,
    int? fornecedorId,
  }) async {
    await _stock.registarMovimento(
      produtoId: produtoId,
      tipo: tipo,
      quantidade: quantidade,
      motivo: motivo,
      observacao: observacao,
      fornecedorId: fornecedorId,
    );
    _bus.bump();
  }

  @override
  void dispose() {
    _bus.removeListener(load);
    super.dispose();
  }
}
