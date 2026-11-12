import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/utils/app_exception.dart';
import '../models/categoria.dart';
import '../models/produto.dart';

class ProdutoService {
  final _helper = DatabaseHelper.instance;

  static const _select =
      'SELECT p.*, c.nome AS categoria_nome FROM produtos p LEFT JOIN categorias c ON c.id = p.categoria_id';

  Future<List<Produto>> listar({String? busca, int? categoriaId, bool apenasAtivos = true}) async {
    final db = await _helper.database;
    final where = <String>[];
    final args = <Object?>[];
    if (apenasAtivos) where.add('p.ativo = 1');
    if (busca != null && busca.trim().isNotEmpty) {
      where.add('(p.nome LIKE ? OR p.codigo_barras LIKE ?)');
      final q = '%${busca.trim()}%';
      args..add(q)..add(q);
    }
    if (categoriaId != null) {
      where.add('p.categoria_id = ?');
      args.add(categoriaId);
    }
    final rows = await db.rawQuery(
      '$_select ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} ORDER BY p.nome COLLATE NOCASE',
      args,
    );
    return rows.map(Produto.fromMap).toList();
  }

  Future<Produto?> porId(int id) async {
    final db = await _helper.database;
    final rows = await db.rawQuery('$_select WHERE p.id = ?', [id]);
    return rows.isEmpty ? null : Produto.fromMap(rows.first);
  }

  /// Procura um produto activo pelo código de barras exacto.
  Future<Produto?> porCodigo(String codigo) async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      '$_select WHERE p.codigo_barras = ? AND p.ativo = 1 LIMIT 1',
      [codigo.trim()],
    );
    return rows.isEmpty ? null : Produto.fromMap(rows.first);
  }

  /// Cria ou actualiza o produto. Devolve o id.
  Future<int> salvar(Produto p) async {
    if (p.nome.trim().isEmpty) throw AppException('O nome do produto é obrigatório.');
    if (p.precoCompra < 0 || p.precoVenda < 0) {
      throw AppException('Os preços não podem ser negativos.');
    }
    if (p.quantidade < 0 || p.stockMinimo < 0) {
      throw AppException('As quantidades não podem ser negativas.');
    }
    final codigo = (p.codigoBarras ?? '').trim();
    final db = await _helper.database;

    try {
      return await db.transaction((txn) async {
        if (codigo.isNotEmpty) {
          final dup = await txn.query('produtos',
              columns: ['id'],
              where: 'codigo_barras = ? AND id != ?',
              whereArgs: [codigo, p.id ?? -1],
              limit: 1);
          if (dup.isNotEmpty) {
            throw AppException('Já existe um produto com este código de barras.');
          }
        }

        final dados = Map<String, Object?>.from(p.toMap())
          ..['nome'] = p.nome.trim()
          ..['codigo_barras'] = codigo.isEmpty ? null : codigo;

        if (p.id == null) {
          final id = await txn.insert('produtos', dados);
          if (p.quantidade > 0) {
            await txn.insert('movimentacoes_stock', {
              'produto_id': id,
              'tipo': 'entrada',
              'quantidade': p.quantidade,
              'stock_apos': p.quantidade,
              'motivo': 'Stock inicial',
              'data': DateTime.now().toIso8601String(),
            });
          }
          return id;
        }

        final antes = await txn.query('produtos',
            columns: ['quantidade'], where: 'id = ?', whereArgs: [p.id], limit: 1);
        if (antes.isEmpty) throw AppException('Produto não encontrado.');
        final qtdAntiga = (antes.first['quantidade'] as num).toInt();
        dados.remove('id');
        dados.remove('data_cadastro');
        await txn.update('produtos', dados, where: 'id = ?', whereArgs: [p.id]);
        if (qtdAntiga != p.quantidade) {
          await txn.insert('movimentacoes_stock', {
            'produto_id': p.id,
            'tipo': 'ajuste',
            'quantidade': p.quantidade - qtdAntiga,
            'stock_apos': p.quantidade,
            'motivo': 'Ajuste na edição do produto',
            'data': DateTime.now().toIso8601String(),
          });
        }
        return p.id!;
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw AppException('Já existe um produto com este código de barras.');
      }
      rethrow;
    }
  }

  /// Elimina o produto. Se já tiver vendas, apenas o desactiva para preservar
  /// o histórico. Devolve true se foi eliminado definitivamente.
  Future<bool> eliminar(int id) async {
    final db = await _helper.database;
    final usado = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM itens_venda WHERE produto_id = ?', [id])) ??
        0;
    if (usado > 0) {
      await db.update('produtos', {'ativo': 0, 'codigo_barras': null},
          where: 'id = ?', whereArgs: [id]);
      return false;
    }
    await db.delete('produtos', where: 'id = ?', whereArgs: [id]);
    return true;
  }

  // ----- Categorias -----

  Future<List<Categoria>> listarCategorias() async {
    final db = await _helper.database;
    final rows = await db.query('categorias', orderBy: 'nome COLLATE NOCASE');
    return rows.map(Categoria.fromMap).toList();
  }

  Future<int> salvarCategoria(Categoria c) async {
    if (c.nome.trim().isEmpty) throw AppException('O nome da categoria é obrigatório.');
    final db = await _helper.database;
    try {
      final dados = c.toMap()..['nome'] = c.nome.trim();
      if (c.id == null) return await db.insert('categorias', dados);
      await db.update('categorias', dados, where: 'id = ?', whereArgs: [c.id]);
      return c.id!;
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) throw AppException('Já existe uma categoria com este nome.');
      rethrow;
    }
  }

  Future<void> eliminarCategoria(int id) async {
    final db = await _helper.database;
    await db.delete('categorias', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> contarProdutosDaCategoria(int id) async {
    final db = await _helper.database;
    return Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM produtos WHERE categoria_id = ? AND ativo = 1', [id])) ??
        0;
  }
}
