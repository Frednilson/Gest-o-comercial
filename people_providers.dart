import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../models/cliente.dart';
import '../models/despesa.dart';
import '../models/fornecedor.dart';
import '../services/pessoas_service.dart';
import 'app_data.dart';

/// Clientes.
class CustomerProvider extends ChangeNotifier {
  CustomerProvider(this._bus) {
    _bus.addListener(load);
  }

  final AppData _bus;
  final _service = ClienteService();

  List<Cliente> clientes = [];
  String busca = '';
  bool loading = false;
  int _loadId = 0;

  Future<void> load() async {
    final id = ++_loadId;
    loading = true;
    notifyListeners();
    try {
      final r = await _service.listar(busca: busca);
      if (id != _loadId) return;
      clientes = r;
    } finally {
      if (id == _loadId) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void setBusca(String v) {
    busca = v;
    load();
  }

  Future<int> salvar(Cliente c) async {
    final id = await _service.salvar(c);
    _bus.bump();
    return id;
  }

  Future<void> eliminar(int id) async {
    await _service.eliminar(id);
    _bus.bump();
  }

  @override
  void dispose() {
    _bus.removeListener(load);
    super.dispose();
  }
}

/// Fornecedores.
class SupplierProvider extends ChangeNotifier {
  SupplierProvider(this._bus) {
    _bus.addListener(load);
  }

  final AppData _bus;
  final _service = FornecedorService();

  List<Fornecedor> fornecedores = [];
  String busca = '';
  bool loading = false;
  int _loadId = 0;

  Future<void> load() async {
    final id = ++_loadId;
    loading = true;
    notifyListeners();
    try {
      final r = await _service.listar(busca: busca);
      if (id != _loadId) return;
      fornecedores = r;
    } finally {
      if (id == _loadId) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void setBusca(String v) {
    busca = v;
    load();
  }

  Future<int> salvar(Fornecedor f) async {
    final id = await _service.salvar(f);
    _bus.bump();
    return id;
  }

  Future<void> eliminar(int id) async {
    await _service.eliminar(id);
    _bus.bump();
  }

  @override
  void dispose() {
    _bus.removeListener(load);
    super.dispose();
  }
}

/// Despesas (com filtro por período; por omissão, o mês actual).
class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider(this._bus) {
    final hoje = DateTime.now();
    periodo = DateTimeRange(start: DateTime(hoje.year, hoje.month, 1), end: DateTime(hoje.year, hoje.month, hoje.day));
    _bus.addListener(load);
  }

  final AppData _bus;
  final _service = DespesaService();

  List<Despesa> despesas = [];
  late DateTimeRange periodo;
  bool loading = false;
  int _loadId = 0;

  double get total => despesas.fold(0.0, (s, d) => s + d.valor);

  String get periodoLabel => Fmt.periodLabel(periodo.start, periodo.end);

  Future<void> load() async {
    final id = ++_loadId;
    loading = true;
    notifyListeners();
    try {
      final r = await _service.listar(de: periodo.start, ate: periodo.end);
      if (id != _loadId) return;
      despesas = r;
    } finally {
      if (id == _loadId) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void setPeriodo(DateTimeRange p) {
    periodo = p;
    load();
  }

  Future<int> salvar(Despesa d) async {
    final id = await _service.salvar(d);
    _bus.bump();
    return id;
  }

  Future<void> eliminar(int id) async {
    await _service.eliminar(id);
    _bus.bump();
  }

  @override
  void dispose() {
    _bus.removeListener(load);
    super.dispose();
  }
}
