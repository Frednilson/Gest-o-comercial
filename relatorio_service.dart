import 'package:sqflite/sqflite.dart';

import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../core/utils/formatters.dart';
import '../models/relatorio.dart';
import '../models/venda.dart';

/// Dashboard e relatórios — tudo calculado a partir das operações registadas.
///
/// Lucro estimado = vendas (não canceladas) - custo dos produtos vendidos
/// (custo guardado no momento da venda) - despesas do período.
class RelatorioService {
  final _helper = DatabaseHelper.instance;

  static double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

  Future<double> _vendas(DatabaseExecutor db, String de, String ate) async {
    final r = await db.rawQuery(
      "SELECT COALESCE(SUM(total), 0) AS t FROM vendas "
      "WHERE estado != 'cancelada' AND substr(data_venda, 1, 10) BETWEEN ? AND ?",
      [de, ate],
    );
    return _num(r.first['t']);
  }

  Future<double> _custo(DatabaseExecutor db, String de, String ate) async {
    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(i.quantidade * i.custo_unitario), 0) AS c FROM itens_venda i '
      'JOIN vendas v ON v.id = i.venda_id '
      "WHERE v.estado != 'cancelada' AND substr(v.data_venda, 1, 10) BETWEEN ? AND ?",
      [de, ate],
    );
    return _num(r.first['c']);
  }

  Future<double> _despesas(DatabaseExecutor db, String de, String ate) async {
    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(valor), 0) AS d FROM despesas WHERE data BETWEEN ? AND ?',
      [de, ate],
    );
    return _num(r.first['d']);
  }

  // ---------------------------------------------------------------- Dashboard

  Future<DashboardData> dashboard() async {
    final db = await _helper.database;
    final hoje = DateTime.now();
    final h = Fmt.isoDate(hoje);

    final vendasHoje = await _vendas(db, h, h);
    final custoHoje = await _custo(db, h, h);
    final despesasHoje = await _despesas(db, h, h);
    final numVendas = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM vendas WHERE estado != 'cancelada' AND substr(data_venda, 1, 10) = ?",
            [h])) ??
        0;
    final totalProdutos =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM produtos WHERE ativo = 1')) ?? 0;
    final stockBaixo = Sqflite.firstIntValue(await db
            .rawQuery('SELECT COUNT(*) FROM produtos WHERE ativo = 1 AND quantidade <= stock_minimo')) ??
        0;

    // Últimos 7 dias (inclui hoje)
    final inicio = DateTime(hoje.year, hoje.month, hoje.day).subtract(const Duration(days: 6));
    final rows = await db.rawQuery(
      "SELECT substr(data_venda, 1, 10) AS dia, SUM(total) AS t FROM vendas "
      "WHERE estado != 'cancelada' AND substr(data_venda, 1, 10) BETWEEN ? AND ? GROUP BY dia",
      [Fmt.isoDate(inicio), h],
    );
    final porDia = {for (final r in rows) r['dia'] as String: _num(r['t'])};
    final dias = <DiaVenda>[];
    for (var i = 0; i < 7; i++) {
      final d = inicio.add(Duration(days: i));
      dias.add(DiaVenda(d, porDia[Fmt.isoDate(d)] ?? 0));
    }

    final inicio30 = Fmt.isoDate(hoje.subtract(const Duration(days: 29)));
    final top = await _maisVendidos(db, inicio30, h, 5);

    final ult = await db.rawQuery(
      'SELECT v.*, c.nome AS cliente_nome FROM vendas v LEFT JOIN clientes c ON c.id = v.cliente_id '
      'ORDER BY v.data_venda DESC, v.id DESC LIMIT 5',
    );

    return DashboardData(
      vendasHoje: vendasHoje,
      numVendasHoje: numVendas,
      totalProdutos: totalProdutos,
      stockBaixo: stockBaixo,
      despesasHoje: despesasHoje,
      lucroEstimado: vendasHoje - custoHoje - despesasHoje,
      vendas7Dias: dias,
      maisVendidos: top,
      ultimasVendas: ult.map(Venda.fromMap).toList(),
    );
  }

  Future<List<ProdutoVendido>> _maisVendidos(
      DatabaseExecutor db, String de, String ate, int limite) async {
    final rows = await db.rawQuery(
      'SELECT i.nome_produto AS nome, SUM(i.quantidade) AS qtd, SUM(i.subtotal) AS total '
      'FROM itens_venda i JOIN vendas v ON v.id = i.venda_id '
      "WHERE v.estado != 'cancelada' AND substr(v.data_venda, 1, 10) BETWEEN ? AND ? "
      'GROUP BY i.nome_produto ORDER BY qtd DESC, total DESC LIMIT $limite',
      [de, ate],
    );
    return rows
        .map((r) => ProdutoVendido(
            nome: r['nome'] as String,
            quantidade: (r['qtd'] as num).toInt(),
            total: _num(r['total'])))
        .toList();
  }

  // ---------------------------------------------------------------- Relatórios

  /// Lista de vendas do período (uma linha por venda).
  Future<ReportData> vendas(DateTime de, DateTime ate, {String titulo = 'Relatório de vendas'}) async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      'SELECT v.*, c.nome AS cliente_nome FROM vendas v LEFT JOIN clientes c ON c.id = v.cliente_id '
      'WHERE substr(v.data_venda, 1, 10) BETWEEN ? AND ? ORDER BY v.data_venda DESC',
      [Fmt.isoDate(de), Fmt.isoDate(ate)],
    );
    final vendas = rows.map(Venda.fromMap).toList();
    final validas = vendas.where((v) => !v.cancelada);
    return ReportData(
      titulo: titulo,
      periodo: Fmt.periodLabel(de, ate),
      colunas: ['Nº', 'Data', 'Cliente', 'Estado', 'Total'],
      colunasNumericas: {4},
      linhas: vendas
          .map((v) => [
                v.numeroVenda,
                Fmt.dateTime(v.dataVenda),
                v.clienteNome ?? '-',
                v.estadoLabel,
                Fmt.number(v.total),
              ])
          .toList(),
      resumo: {
        'Vendas': '${validas.length}',
        'Total vendido': Fmt.money(validas.fold<double>(0, (s, v) => s + v.total)),
        'Descontos': Fmt.money(validas.fold<double>(0, (s, v) => s + v.desconto)),
      },
    );
  }

  /// Vendas agrupadas por dia (usado nos relatórios semanal e mensal).
  Future<ReportData> vendasPorDia(DateTime de, DateTime ate, {required String titulo}) async {
    final db = await _helper.database;
    final d0 = Fmt.isoDate(de), d1 = Fmt.isoDate(ate);
    final vendas = await db.rawQuery(
      "SELECT substr(data_venda, 1, 10) AS dia, COUNT(*) AS n, SUM(total) AS t FROM vendas "
      "WHERE estado != 'cancelada' AND substr(data_venda, 1, 10) BETWEEN ? AND ? GROUP BY dia",
      [d0, d1],
    );
    final custos = await db.rawQuery(
      'SELECT substr(v.data_venda, 1, 10) AS dia, SUM(i.quantidade * i.custo_unitario) AS c '
      'FROM itens_venda i JOIN vendas v ON v.id = i.venda_id '
      "WHERE v.estado != 'cancelada' AND substr(v.data_venda, 1, 10) BETWEEN ? AND ? GROUP BY dia",
      [d0, d1],
    );
    final mv = {for (final r in vendas) r['dia'] as String: r};
    final mc = {for (final r in custos) r['dia'] as String: _num(r['c'])};

    final linhas = <List<String>>[];
    var totalV = 0.0, totalL = 0.0;
    var totalN = 0;
    var dia = DateTime(de.year, de.month, de.day);
    final fim = DateTime(ate.year, ate.month, ate.day);
    while (!dia.isAfter(fim)) {
      final k = Fmt.isoDate(dia);
      final r = mv[k];
      final t = _num(r?['t']);
      final n = (r?['n'] as num?)?.toInt() ?? 0;
      final lucro = t - (mc[k] ?? 0);
      totalV += t;
      totalL += lucro;
      totalN += n;
      linhas.add([
        '${Fmt.shortWeekday(dia)} ${Fmt.date(dia)}',
        '$n',
        Fmt.number(t),
        Fmt.number(lucro),
      ]);
      dia = dia.add(const Duration(days: 1));
    }
    return ReportData(
      titulo: titulo,
      periodo: Fmt.periodLabel(de, ate),
      colunas: ['Dia', 'Vendas', 'Total', 'Lucro bruto'],
      colunasNumericas: {1, 2, 3},
      linhas: linhas,
      resumo: {
        'Nº de vendas': '$totalN',
        'Total vendido': Fmt.money(totalV),
        'Lucro bruto': Fmt.money(totalL),
      },
    );
  }

  Future<ReportData> produtosMaisVendidos(DateTime de, DateTime ate) async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      'SELECT i.nome_produto AS nome, SUM(i.quantidade) AS qtd, SUM(i.subtotal) AS total, '
      'SUM(i.quantidade * i.custo_unitario) AS custo '
      'FROM itens_venda i JOIN vendas v ON v.id = i.venda_id '
      "WHERE v.estado != 'cancelada' AND substr(v.data_venda, 1, 10) BETWEEN ? AND ? "
      'GROUP BY i.nome_produto ORDER BY qtd DESC, total DESC',
      [Fmt.isoDate(de), Fmt.isoDate(ate)],
    );
    var totalQtd = 0;
    var totalVal = 0.0;
    final linhas = <List<String>>[];
    var pos = 1;
    for (final r in rows) {
      final qtd = (r['qtd'] as num).toInt();
      final total = _num(r['total']);
      totalQtd += qtd;
      totalVal += total;
      linhas.add(['${pos++}', r['nome'] as String, '$qtd', Fmt.number(total), Fmt.number(total - _num(r['custo']))]);
    }
    return ReportData(
      titulo: 'Produtos mais vendidos',
      periodo: Fmt.periodLabel(de, ate),
      colunas: ['#', 'Produto', 'Qtd.', 'Total', 'Lucro'],
      colunasNumericas: {0, 2, 3, 4},
      linhas: linhas,
      resumo: {'Unidades vendidas': '$totalQtd', 'Total vendido': Fmt.money(totalVal)},
    );
  }

  Future<ReportData> stock() async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      'SELECT p.*, c.nome AS categoria_nome FROM produtos p LEFT JOIN categorias c ON c.id = p.categoria_id '
      'WHERE p.ativo = 1 ORDER BY p.nome COLLATE NOCASE',
    );
    var unidades = 0, baixos = 0;
    var valorCusto = 0.0, valorVenda = 0.0;
    final linhas = <List<String>>[];
    for (final r in rows) {
      final qtd = (r['quantidade'] as num).toInt();
      final min = (r['stock_minimo'] as num).toInt();
      final compra = _num(r['preco_compra']);
      final venda = _num(r['preco_venda']);
      unidades += qtd;
      valorCusto += qtd * compra;
      valorVenda += qtd * venda;
      final baixo = qtd <= min;
      if (baixo) baixos++;
      linhas.add([
        r['nome'] as String,
        (r['categoria_nome'] as String?) ?? '-',
        '$qtd${baixo ? ' (!)' : ''}',
        '$min',
        Fmt.number(qtd * compra),
      ]);
    }
    return ReportData(
      titulo: 'Relatório de stock',
      periodo: 'Em ${Fmt.date(DateTime.now())}',
      colunas: ['Produto', 'Categoria', 'Qtd.', 'Mín.', 'Valor (custo)'],
      colunasNumericas: {2, 3, 4},
      linhas: linhas,
      resumo: {
        'Produtos': '${rows.length}',
        'Unidades em stock': '$unidades',
        'Com stock baixo (!)': '$baixos',
        'Valor a preço de custo': Fmt.money(valorCusto),
        'Valor a preço de venda': Fmt.money(valorVenda),
      },
    );
  }

  Future<ReportData> despesas(DateTime de, DateTime ate) async {
    final db = await _helper.database;
    final rows = await db.query('despesas',
        where: 'data BETWEEN ? AND ?',
        whereArgs: [Fmt.isoDate(de), Fmt.isoDate(ate)],
        orderBy: 'data DESC, id DESC');
    var total = 0.0;
    final porCategoria = <String, double>{};
    final linhas = <List<String>>[];
    for (final r in rows) {
      final v = _num(r['valor']);
      total += v;
      porCategoria[r['categoria'] as String] = (porCategoria[r['categoria']] ?? 0) + v;
      linhas.add([
        Fmt.date(DateTime.parse(r['data'] as String)),
        r['categoria'] as String,
        (r['descricao'] as String?) ?? '-',
        Fmt.number(v),
      ]);
    }
    return ReportData(
      titulo: 'Relatório de despesas',
      periodo: Fmt.periodLabel(de, ate),
      colunas: ['Data', 'Categoria', 'Descrição', 'Valor'],
      colunasNumericas: {3},
      linhas: linhas,
      resumo: {
        'Total de despesas': Fmt.money(total),
        for (final e in porCategoria.entries) e.key: Fmt.money(e.value),
      },
    );
  }

  Future<ReportData> lucro(DateTime de, DateTime ate) async {
    final db = await _helper.database;
    final d0 = Fmt.isoDate(de), d1 = Fmt.isoDate(ate);
    final vendas = await db.rawQuery(
      "SELECT substr(data_venda, 1, 10) AS dia, SUM(total) AS t FROM vendas "
      "WHERE estado != 'cancelada' AND substr(data_venda, 1, 10) BETWEEN ? AND ? GROUP BY dia",
      [d0, d1],
    );
    final custos = await db.rawQuery(
      'SELECT substr(v.data_venda, 1, 10) AS dia, SUM(i.quantidade * i.custo_unitario) AS c '
      'FROM itens_venda i JOIN vendas v ON v.id = i.venda_id '
      "WHERE v.estado != 'cancelada' AND substr(v.data_venda, 1, 10) BETWEEN ? AND ? GROUP BY dia",
      [d0, d1],
    );
    final desp = await db.rawQuery(
      'SELECT data AS dia, SUM(valor) AS d FROM despesas WHERE data BETWEEN ? AND ? GROUP BY data',
      [d0, d1],
    );
    final mv = {for (final r in vendas) r['dia'] as String: _num(r['t'])};
    final mc = {for (final r in custos) r['dia'] as String: _num(r['c'])};
    final md = {for (final r in desp) r['dia'] as String: _num(r['d'])};

    var tv = 0.0, tc = 0.0, td = 0.0;
    final linhas = <List<String>>[];
    var dia = DateTime(de.year, de.month, de.day);
    final fim = DateTime(ate.year, ate.month, ate.day);
    while (!dia.isAfter(fim)) {
      final k = Fmt.isoDate(dia);
      final v = mv[k] ?? 0, c = mc[k] ?? 0, d = md[k] ?? 0;
      tv += v;
      tc += c;
      td += d;
      linhas.add([Fmt.date(dia), Fmt.number(v), Fmt.number(c), Fmt.number(d), Fmt.number(v - c - d)]);
      dia = dia.add(const Duration(days: 1));
    }
    return ReportData(
      titulo: 'Lucro estimado',
      periodo: Fmt.periodLabel(de, ate),
      colunas: ['Dia', 'Vendas', 'Custo', 'Despesas', 'Lucro'],
      colunasNumericas: {1, 2, 3, 4},
      linhas: linhas,
      resumo: {
        'Vendas': Fmt.money(tv),
        'Custo dos produtos': Fmt.money(tc),
        'Lucro bruto': Fmt.money(tv - tc),
        'Despesas': Fmt.money(td),
        'Lucro estimado': Fmt.money(tv - tc - td),
      },
    );
  }

  Future<ReportData> pagamentos(DateTime de, DateTime ate) async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      'SELECT p.*, v.numero_venda FROM pagamentos p JOIN vendas v ON v.id = p.venda_id '
      "WHERE v.estado != 'cancelada' AND substr(p.data_pagamento, 1, 10) BETWEEN ? AND ? "
      'ORDER BY p.data_pagamento DESC, p.id DESC',
      [Fmt.isoDate(de), Fmt.isoDate(ate)],
    );
    final porMetodo = <String, double>{};
    var total = 0.0;
    final linhas = <List<String>>[];
    for (final r in rows) {
      final v = _num(r['valor']);
      final m = r['metodo_pagamento'] as String;
      total += v;
      porMetodo[m] = (porMetodo[m] ?? 0) + v;
      linhas.add([
        Fmt.dateTime(DateTime.parse(r['data_pagamento'] as String)),
        r['numero_venda'] as String,
        AppConstants.paymentLabel(m),
        Fmt.number(v),
      ]);
    }
    return ReportData(
      titulo: 'Histórico de pagamentos',
      periodo: Fmt.periodLabel(de, ate),
      colunas: ['Data', 'Venda', 'Método', 'Valor'],
      colunasNumericas: {3},
      linhas: linhas,
      resumo: {
        'Total recebido': Fmt.money(total),
        for (final e in porMetodo.entries) AppConstants.paymentLabel(e.key): Fmt.money(e.value),
      },
    );
  }

  Future<ReportData> movimentos(DateTime de, DateTime ate) async {
    final db = await _helper.database;
    final rows = await db.rawQuery(
      'SELECT m.*, p.nome AS produto_nome FROM movimentacoes_stock m JOIN produtos p ON p.id = m.produto_id '
      'WHERE substr(m.data, 1, 10) BETWEEN ? AND ? ORDER BY m.data DESC, m.id DESC',
      [Fmt.isoDate(de), Fmt.isoDate(ate)],
    );
    var entradas = 0, saidas = 0;
    final linhas = <List<String>>[];
    for (final r in rows) {
      final q = (r['quantidade'] as num).toInt();
      if (q >= 0) {
        entradas += q;
      } else {
        saidas += -q;
      }
      linhas.add([
        Fmt.dateTime(DateTime.parse(r['data'] as String)),
        r['produto_nome'] as String,
        AppConstants.movementLabel(r['tipo'] as String),
        q > 0 ? '+$q' : '$q',
        (r['motivo'] as String?) ?? '-',
      ]);
    }
    return ReportData(
      titulo: 'Movimentações de stock',
      periodo: Fmt.periodLabel(de, ate),
      colunas: ['Data', 'Produto', 'Tipo', 'Qtd.', 'Motivo'],
      colunasNumericas: {3},
      linhas: linhas,
      resumo: {'Unidades entradas': '$entradas', 'Unidades saídas': '$saidas'},
    );
  }
}
