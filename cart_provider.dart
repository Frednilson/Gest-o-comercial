import 'package:flutter/foundation.dart';

import '../core/utils/app_exception.dart';
import '../models/cliente.dart';
import '../models/produto.dart';
import '../models/venda.dart';
import '../services/venda_service.dart';
import 'app_data.dart';

class CartItem {
  CartItem(this.produto, this.quantidade);
  Produto produto;
  int quantidade;
  double get subtotal => produto.precoVenda * quantidade;
}

enum AddResult { ok, semStock, stockInsuficiente }

/// Carrinho de compras e confirmação da venda.
class CartProvider extends ChangeNotifier {
  CartProvider(this._bus);

  final AppData _bus;
  final _service = VendaService();

  final List<CartItem> _items = [];
  double _desconto = 0;
  Cliente? cliente;
  String _token = _novoToken();
  bool _saving = false;

  static String _novoToken() => 'v-${DateTime.now().microsecondsSinceEpoch}';

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  bool get saving => _saving;
  int get totalUnidades => _items.fold(0, (s, i) => s + i.quantidade);
  double get subtotal => _items.fold(0.0, (s, i) => s + i.subtotal);
  double get desconto => _desconto > subtotal ? subtotal : _desconto;
  double get total => subtotal - desconto;

  int quantidadeNoCarrinho(int produtoId) {
    for (final i in _items) {
      if (i.produto.id == produtoId) return i.quantidade;
    }
    return 0;
  }

  /// Adiciona um produto (ou aumenta a quantidade se já existir).
  AddResult add(Produto p, {int quantidade = 1}) {
    if (p.quantidade <= 0) return AddResult.semStock;
    final index = _items.indexWhere((i) => i.produto.id == p.id);
    final actual = index >= 0 ? _items[index].quantidade : 0;
    if (actual + quantidade > p.quantidade) return AddResult.stockInsuficiente;
    if (index >= 0) {
      _items[index].quantidade = actual + quantidade;
      _items[index].produto = p; // dados mais recentes (preço / stock)
    } else {
      _items.add(CartItem(p, quantidade));
    }
    notifyListeners();
    return AddResult.ok;
  }

  AddResult increase(CartItem item) => add(item.produto);

  void decrease(CartItem item) {
    if (item.quantidade > 1) {
      item.quantidade--;
    } else {
      _items.remove(item);
    }
    notifyListeners();
  }

  void remove(CartItem item) {
    _items.remove(item);
    notifyListeners();
  }

  void setDesconto(double value) {
    _desconto = value < 0 ? 0 : value;
    notifyListeners();
  }

  void setCliente(Cliente? c) {
    cliente = c;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _desconto = 0;
    cliente = null;
    _token = _novoToken();
    notifyListeners();
  }

  /// Confirma a venda. [pagamentos]: método -> valor entregue.
  /// Ignora toques repetidos enquanto a venda está a ser guardada.
  Future<Venda> confirmar(Map<String, double> pagamentos) async {
    if (_saving) throw AppException('A venda está a ser guardada. Aguarde.');
    if (_items.isEmpty) throw AppException('Adicione pelo menos um produto à venda.');
    _saving = true;
    notifyListeners();
    try {
      final venda = await _service.registarVenda(NovaVenda(
        itens: _items.map((i) => LinhaVenda(produtoId: i.produto.id!, quantidade: i.quantidade)).toList(),
        desconto: desconto,
        clienteId: cliente?.id,
        pagamentos: pagamentos,
        token: _token,
      ));
      clear();
      _bus.bump();
      return venda;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
