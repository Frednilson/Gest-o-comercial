import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/utils/app_exception.dart';
import '../models/venda.dart';

class LinhaVenda {
  const LinhaVenda({required this.produtoId, required this.quantidade});
  final int produtoId;
  final int quantidade;
}

/// Dados necessários para registar uma venda.
class NovaVenda {
  const NovaVenda({
    required this.itens,
    required this.desconto,
    required this.pagamentos,
    required this.token,
    this.clienteId,
  });

  final List<LinhaVenda> itens;
  final double desconto;
  final int? clienteId;

  /// método (dinheiro | mpesa | emola | transferencia) -> valor entregue
  final Map<String, double> pagamentos;

  /// Identificador único da tentativa de venda: impede registos duplicados.
  final String token;
}

class VendaService {
  final _helper = DatabaseHelper.instance;

  static double _r2(double v) => (v * 100).roundToDouble() / 100;

  /// Regista a venda, os itens, os pagamentos, actualiza o stock e as
  /// movimentações — tudo dentro da transacção recebida.
  static Future<int> inserirVendaTxn(DatabaseExecutor txn, NovaVenda v, DateTime agora) async {
    if (v.itens.isEmpty) {
      throw AppException('Adicione pelo menos um produto à venda.');
    }

    // Venda já registada com o mesmo token (duplo toque / reenvio): devolve a existente.
    final existente = await txn.query('vendas',
        columns: ['id'], where: 'token = ?', whereArgs: [v.token], limit: 1);
    if (existente.isNotEmpty) return existente.first['id'] as int;

    // Agrupa linhas do mesmo produto.
    final quantidades = <int, int>{};
    for (final l in v.itens) {
      if (l.quantidade <= 0) throw AppException('Quantidade inválida.');
      quantidades[l.produtoId] = (quantidades[l.produtoId] ?? 0) + l.quantidade;
    }

    // Valida stock e calcula o subtotal com os preços actuais da base de dados.
    final produtos = <int, Map<String, Object?>>{};
    var subtotal = 0.0;
    for (final e in quantidades.entries) {
      final rows = await txn.query('produtos',
          where: 'id = ? AND ativo = 1', whereArgs: [e.key], limit: 1);
      if (rows.isEmpty) throw AppException('Um dos produtos já não está disponível.');
      final p = rows.first;
      final disponivel = (p['quantidade'] as num).toInt();
      if (disponivel < e.value) {
        throw AppException('Stock insuficiente para "${p['nome']}" (disponível: $disponivel).');
      }
      produtos[e.key] = p;
      subtotal += (p['preco_venda'] as num).toDouble() * e.value;
    }
    subtotal = _r2(subtotal);

    if (v.desconto < 0 || v.desconto > subtotal + 0.001) {
      throw AppException('Desconto inválido. Deve estar entre 0 e o subtotal.');
    }
    final desconto = _r2(v.desconto);
    final total = _r2(subtotal - desconto);

    var recebido = 0.0;
    for (final valor in v.pagamentos.values) {
      if (valor < 0) throw AppException('Valor de pagamento inválido.');
      recebido += valor;
    }
    recebido = _r2(recebido);
    final troco = recebido > total ? _r2(recebido - total) : 0.0;
    final dinheiro = v.pagamentos['dinheiro'] ?? 0.0;
    if (troco > dinheiro + 0.004) {
      throw AppException(
          'O valor recebido é superior ao total. O troco só pode ser devolvido em dinheiro.');
    }

    final paga = recebido >= total - 0.004;
    if (!paga && v.clienteId == null) {
      throw AppException(
          'Valor recebido inferior ao total. Seleccione um cliente para registar a venda com valor em falta.');
    }

    final proximo = await txn.rawQuery('SELECT COALESCE(MAX(id), 0) + 1 AS n FROM vendas');
    final n = (proximo.first['n'] as num).toInt();
    final numero = 'V${n.toString().padLeft(6, '0')}';
    final iso = agora.toIso8601String();

    final vendaId = await txn.insert('vendas', {
      'numero_venda': numero,
      'token': v.token,
      'cliente_id': v.clienteId,
      'subtotal': subtotal,
      'desconto': desconto,
      'total': total,
      'valor_recebido': recebido,
      'troco': troco,
      'estado': paga ? 'paga' : 'pendente',
      'data_venda': iso,
    });

    for (final e in quantidades.entries) {
      final p = produtos[e.key]!;
      final qtd = e.value;
      final preco = (p['preco_venda'] as num).toDouble();
      final custo = (p['preco_compra'] as num).toDouble();

      await txn.insert('itens_venda', {
        'venda_id': vendaId,
        'produto_id': e.key,
        'nome_produto': p['nome'],
        'quantidade': qtd,
        'preco_unitario': preco,
        'custo_unitario': custo,
        'subtotal': _r2(preco * qtd),
      });

      final actualizado = await txn.rawUpdate(
        'UPDATE produtos SET quantidade = quantidade - ? WHERE id = ? AND quantidade >= ?',
        [qtd, e.key, qtd],
      );
      if (actualizado != 1) {
        throw AppException('Stock insuficiente para "${p['nome']}".');
      }
      await txn.insert('movimentacoes_stock', {
        'produto_id': e.key,
        'tipo': 'venda',
        'quantidade': -qtd,
        'stock_apos': (p['quantidade'] as num).toInt() - qtd,
        'motivo': 'Venda $numero',
        'venda_id': vendaId,
        'data': iso,
      });
    }

    for (final e in v.pagamentos.entries) {
      var valor = e.value;
      if (e.key == 'dinheiro') valor -= troco; // regista apenas o que ficou na caixa
      valor = _r2(valor);
      if (valor > 0.004) {
        await txn.insert('pagamentos', {
          'venda_id': vendaId,
          'metodo_pagamento': e.key,
          'valor': valor,
          'data_pagamento': iso,
        });
      }
    }

    return vendaId;
  }

  Future<Venda> registarVenda(NovaVenda venda) async {
    final db = await _helper.database;
    final id = await db.transaction((txn) => inserirVendaTxn(txn, venda, DateTime.now()));
    return (await porId(id))!;
  }

  Future<List<Venda>> listar({
    DateTime? de,
    DateTime? ate,
    int? clienteId,
    String? busca,
    int? limite,
  }) async {
    final db = await _helper.database;
    final where = <String>[];
    final args = <Object?>[];
    if (de != null) {
      where.add('substr(v.data_venda, 1, 10) >= ?');
      args.add(_dia(de));
    }
    if (ate != null) {
      where.add('substr(v.data_venda, 1, 10) <= ?');
      args.add(_dia(ate));
    }
    if (clienteId != null) {
      where.add('v.cliente_id = ?');
      args.add(clienteId);
    }
    if (busca != null && busca.trim().isNotEmpty) {
      where.add('(v.numero_venda LIKE ? OR c.nome LIKE ?)');
      args..add('%${busca.trim()}%')..add('%${busca.trim()}%');
    }
    final rows = await db.rawQuery(
      'SELECT v.*, c.nome AS cliente_nome FROM vendas v '
      'LEFT JOIN clientes c ON c.id = v.cliente_id '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY v.data_venda DESC, v.id DESC '
      '${limite != null ? 'LIMIT $limite' : ''}',
      args,
    );
    return rows.map(Venda.fromMap).toList();
  }

  /// Venda completa (itens e pagamentos).
  Future<Venda?> porId(int id) async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      'SELECT v.*, c.nome AS cliente_nome FROM vendas v '
      'LEFT JOIN clientes c ON c.id = v.cliente_id WHERE v.id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    final itens = await db.query('itens_venda', where: 'venda_id = ?', whereArgs: [id], orderBy: 'id');
    final pags =
        await db.query('pagamentos', where: 'venda_id = ?', whereArgs: [id], orderBy: 'id');
    return Venda.fromMap(rows.first).copyWith(
      itens: itens.map(ItemVenda.fromMap).toList(),
      pagamentos: pags.map(Pagamento.fromMap).toList(),
    );
  }

  /// Cancela a venda e devolve os produtos ao stock (com movimentação).
  Future<void> cancelar(int vendaId) async {
    final db = await _helper.database;
    await db.transaction((txn) async {
      final rows = await txn.query('vendas', where: 'id = ?', whereArgs: [vendaId], limit: 1);
      if (rows.isEmpty) throw AppException('Venda não encontrada.');
      if (rows.first['estado'] == 'cancelada') throw AppException('Esta venda já foi cancelada.');
      final numero = rows.first['numero_venda'];
      final iso = DateTime.now().toIso8601String();
      final itens = await txn.query('itens_venda', where: 'venda_id = ?', whereArgs: [vendaId]);
      for (final it in itens) {
        final pid = it['produto_id'] as int?;
        if (pid == null) continue;
        final qtd = (it['quantidade'] as num).toInt();
        await txn.rawUpdate('UPDATE produtos SET quantidade = quantidade + ? WHERE id = ?', [qtd, pid]);
        final p = await txn.query('produtos', columns: ['quantidade'], where: 'id = ?', whereArgs: [pid]);
        await txn.insert('movimentacoes_stock', {
          'produto_id': pid,
          'tipo': 'devolucao',
          'quantidade': qtd,
          'stock_apos': (p.first['quantidade'] as num).toInt(),
          'motivo': 'Cancelamento da venda $numero',
          'venda_id': vendaId,
          'data': iso,
        });
      }
      await txn.update('vendas', {'estado': 'cancelada'}, where: 'id = ?', whereArgs: [vendaId]);
    });
  }

  /// Regista o pagamento (total ou parcial) de uma venda pendente.
  Future<void> receberPagamento(int vendaId, String metodo, double valor) async {
    if (valor <= 0) throw AppException('Indique um valor superior a zero.');
    final db = await _helper.database;
    await db.transaction((txn) async {
      final rows = await txn.query('vendas', where: 'id = ?', whereArgs: [vendaId], limit: 1);
      if (rows.isEmpty) throw AppException('Venda não encontrada.');
      final venda = rows.first;
      if (venda['estado'] != 'pendente') {
        throw AppException('Só é possível receber pagamentos de vendas pendentes.');
      }
      final total = (venda['total'] as num).toDouble();
      final recebido = (venda['valor_recebido'] as num).toDouble();
      final emFalta = _r2(total - recebido);
      if (valor > emFalta + 0.004) {
        throw AppException('O valor excede o que falta pagar (${emFalta.toStringAsFixed(2)} MZN).');
      }
      final novo = _r2(recebido + valor);
      await txn.insert('pagamentos', {
        'venda_id': vendaId,
        'metodo_pagamento': metodo,
        'valor': _r2(valor),
        'data_pagamento': DateTime.now().toIso8601String(),
      });
      await txn.update(
        'vendas',
        {'valor_recebido': novo, 'estado': novo >= total - 0.004 ? 'paga' : 'pendente'},
        where: 'id = ?',
        whereArgs: [vendaId],
      );
    });
  }

  static String _dia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
