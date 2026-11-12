import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../core/utils/app_exception.dart';
import '../models/movimento_stock.dart';

class StockService {
  final _helper = DatabaseHelper.instance;

  /// Regista um movimento manual.
  ///
  /// Para entrada, saída e devolução, [quantidade] é a quantidade movimentada.
  /// Para ajuste, [quantidade] é o NOVO valor de stock do produto.
  Future<void> registarMovimento({
    required int produtoId,
    required String tipo,
    required int quantidade,
    String? motivo,
    String? observacao,
    int? fornecedorId,
  }) async {
    if (!AppConstants.manualMovementTypes.contains(tipo)) {
      throw AppException('Tipo de movimento inválido.');
    }
    if (quantidade < 0 || (tipo != 'ajuste' && quantidade == 0)) {
      throw AppException('Indique uma quantidade válida.');
    }
    final db = await _helper.database;
    await db.transaction((txn) async {
      final rows = await txn.query('produtos',
          columns: ['quantidade'], where: 'id = ?', whereArgs: [produtoId], limit: 1);
      if (rows.isEmpty) throw AppException('Produto não encontrado.');
      final actual = (rows.first['quantidade'] as num).toInt();

      final int delta;
      if (tipo == 'ajuste') {
        delta = quantidade - actual;
        if (delta == 0) throw AppException('A quantidade indicada é igual ao stock actual.');
      } else if (tipo == 'saida') {
        delta = -quantidade;
      } else {
        delta = quantidade;
      }
      final novo = actual + delta;
      if (novo < 0) throw AppException('Stock insuficiente. Disponível: $actual.');

      await txn.update('produtos', {'quantidade': novo}, where: 'id = ?', whereArgs: [produtoId]);
      await txn.insert('movimentacoes_stock', {
        'produto_id': produtoId,
        'tipo': tipo,
        'quantidade': delta,
        'stock_apos': novo,
        'motivo': (motivo ?? '').trim().isEmpty ? AppConstants.movementLabel(tipo) : motivo!.trim(),
        'observacao': (observacao ?? '').trim().isEmpty ? null : observacao!.trim(),
        'fornecedor_id': tipo == 'entrada' ? fornecedorId : null,
        'data': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<List<MovimentoStock>> listarMovimentos({
    String? tipo,
    int? produtoId,
    int? fornecedorId,
    DateTime? de,
    DateTime? ate,
    int? limite,
  }) async {
    final db = await _helper.database;
    final where = <String>[];
    final args = <Object?>[];
    if (tipo != null) {
      where.add('m.tipo = ?');
      args.add(tipo);
    }
    if (produtoId != null) {
      where.add('m.produto_id = ?');
      args.add(produtoId);
    }
    if (fornecedorId != null) {
      where.add('m.fornecedor_id = ?');
      args.add(fornecedorId);
    }
    if (de != null) {
      where.add('substr(m.data, 1, 10) >= ?');
      args.add(_dia(de));
    }
    if (ate != null) {
      where.add('substr(m.data, 1, 10) <= ?');
      args.add(_dia(ate));
    }
    final rows = await db.rawQuery(
      'SELECT m.*, p.nome AS produto_nome, f.nome AS fornecedor_nome '
      'FROM movimentacoes_stock m '
      'JOIN produtos p ON p.id = m.produto_id '
      'LEFT JOIN fornecedores f ON f.id = m.fornecedor_id '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY m.data DESC, m.id DESC '
      '${limite != null ? 'LIMIT $limite' : ''}',
      args,
    );
    return rows.map(MovimentoStock.fromMap).toList();
  }

  static String _dia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
