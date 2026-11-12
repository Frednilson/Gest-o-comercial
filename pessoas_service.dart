import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/utils/app_exception.dart';
import '../models/cliente.dart';
import '../models/despesa.dart';
import '../models/fornecedor.dart';

/// Clientes.
class ClienteService {
  final _helper = DatabaseHelper.instance;

  Future<List<Cliente>> listar({String? busca}) async {
    final db = await _helper.database;
    final q = (busca ?? '').trim();
    final rows = await db.query(
      'clientes',
      where: q.isEmpty ? null : 'nome LIKE ? OR telefone LIKE ?',
      whereArgs: q.isEmpty ? null : ['%$q%', '%$q%'],
      orderBy: 'nome COLLATE NOCASE',
    );
    return rows.map(Cliente.fromMap).toList();
  }

  Future<int> salvar(Cliente c) async {
    if (c.nome.trim().isEmpty) throw AppException('O nome do cliente é obrigatório.');
    final db = await _helper.database;
    final dados = c.toMap()..['nome'] = c.nome.trim();
    if (c.id == null) return db.insert('clientes', dados);
    dados.remove('data_cadastro');
    await db.update('clientes', dados, where: 'id = ?', whereArgs: [c.id]);
    return c.id!;
  }

  Future<void> eliminar(int id) async {
    final db = await _helper.database;
    final vendas = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM vendas WHERE cliente_id = ?', [id])) ??
        0;
    if (vendas > 0) {
      throw AppException('Este cliente tem vendas registadas e não pode ser eliminado.');
    }
    await db.delete('clientes', where: 'id = ?', whereArgs: [id]);
  }

  /// Total comprado e total em dívida (vendas pendentes).
  Future<({double comprado, double emFalta, int numVendas})> resumo(int id) async {
    final db = await _helper.database;
    final r = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) AS comprado, "
      "COALESCE(SUM(CASE WHEN estado = 'pendente' THEN total - valor_recebido ELSE 0 END), 0) AS falta, "
      'COUNT(*) AS n '
      "FROM vendas WHERE cliente_id = ? AND estado != 'cancelada'",
      [id],
    );
    final row = r.first;
    return (
      comprado: (row['comprado'] as num).toDouble(),
      emFalta: (row['falta'] as num).toDouble(),
      numVendas: (row['n'] as num).toInt(),
    );
  }
}

/// Fornecedores.
class FornecedorService {
  final _helper = DatabaseHelper.instance;

  Future<List<Fornecedor>> listar({String? busca}) async {
    final db = await _helper.database;
    final q = (busca ?? '').trim();
    final rows = await db.query(
      'fornecedores',
      where: q.isEmpty ? null : 'nome LIKE ? OR empresa LIKE ? OR telefone LIKE ?',
      whereArgs: q.isEmpty ? null : ['%$q%', '%$q%', '%$q%'],
      orderBy: 'nome COLLATE NOCASE',
    );
    return rows.map(Fornecedor.fromMap).toList();
  }

  Future<int> salvar(Fornecedor f) async {
    if (f.nome.trim().isEmpty) throw AppException('O nome do fornecedor é obrigatório.');
    final db = await _helper.database;
    final dados = f.toMap()..['nome'] = f.nome.trim();
    if (f.id == null) return db.insert('fornecedores', dados);
    dados.remove('data_cadastro');
    await db.update('fornecedores', dados, where: 'id = ?', whereArgs: [f.id]);
    return f.id!;
  }

  /// Os movimentos de stock ligados ao fornecedor mantêm-se (ficam sem fornecedor).
  Future<void> eliminar(int id) async {
    final db = await _helper.database;
    await db.delete('fornecedores', where: 'id = ?', whereArgs: [id]);
  }
}

/// Despesas.
class DespesaService {
  final _helper = DatabaseHelper.instance;

  static String _dia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<Despesa>> listar({DateTime? de, DateTime? ate}) async {
    final db = await _helper.database;
    final where = <String>[];
    final args = <Object?>[];
    if (de != null) {
      where.add('data >= ?');
      args.add(_dia(de));
    }
    if (ate != null) {
      where.add('data <= ?');
      args.add(_dia(ate));
    }
    final rows = await db.query('despesas',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'data DESC, id DESC');
    return rows.map(Despesa.fromMap).toList();
  }

  Future<int> salvar(Despesa d) async {
    if (d.valor <= 0) throw AppException('O valor da despesa deve ser superior a zero.');
    if (d.categoria.trim().isEmpty) throw AppException('Seleccione a categoria.');
    final db = await _helper.database;
    final dados = d.toMap();
    if (d.id == null) return db.insert('despesas', dados);
    await db.update('despesas', dados, where: 'id = ?', whereArgs: [d.id]);
    return d.id!;
  }

  Future<void> eliminar(int id) async {
    final db = await _helper.database;
    await db.delete('despesas', where: 'id = ?', whereArgs: [id]);
  }
}
