import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_comercial/core/database/database_helper.dart';
import 'package:gestao_comercial/core/utils/app_exception.dart';
import 'package:gestao_comercial/models/produto.dart';
import 'package:gestao_comercial/models/cliente.dart';
import 'package:gestao_comercial/services/pessoas_service.dart';
import 'package:gestao_comercial/services/produto_service.dart';
import 'package:gestao_comercial/services/relatorio_service.dart';
import 'package:gestao_comercial/services/stock_service.dart';
import 'package:gestao_comercial/services/venda_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Produto _produto(String nome,
        {double compra = 50, double venda = 100, int qtd = 10, String? codigo, int minimo = 2}) =>
    Produto(
      nome: nome,
      precoCompra: compra,
      precoVenda: venda,
      quantidade: qtd,
      stockMinimo: minimo,
      codigoBarras: codigo,
      dataCadastro: DateTime.now(),
    );

Future<AppException> _falha(Future<void> Function() f) async {
  try {
    await f();
  } on AppException catch (e) {
    return e;
  }
  fail('Era esperado um AppException.');
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final produtos = ProdutoService();
  final vendas = VendaService();
  final stock = StockService();
  var contador = 0;
  String token() => 't${contador++}';

  setUp(() async {
    final helper = DatabaseHelper.instance;
    await helper.close();
    helper.testPath = inMemoryDatabasePath;
    helper.seedDemoOnCreate = false;
  });

  tearDown(() => DatabaseHelper.instance.close());

  group('Produtos', () {
    test('cadastra produto e regista a movimentação inicial de stock', () async {
      final id = await produtos.salvar(_produto('Arroz', qtd: 20, codigo: '111'));
      final p = await produtos.porId(id);
      expect(p!.quantidade, 20);
      final mov = await stock.listarMovimentos(produtoId: id);
      expect(mov, hasLength(1));
      expect(mov.first.tipo, 'entrada');
      expect(mov.first.quantidade, 20);
    });

    test('não permite preços ou stock negativos', () async {
      await _falha(() => produtos.salvar(_produto('X', venda: -1)));
      await _falha(() => produtos.salvar(_produto('X', compra: -5)));
      await _falha(() => produtos.salvar(_produto('X', qtd: -1)));
    });

    test('não permite códigos de barras duplicados', () async {
      await produtos.salvar(_produto('A', codigo: '999'));
      final e = await _falha(() => produtos.salvar(_produto('B', codigo: '999')));
      expect(e.message, contains('código de barras'));
    });

    test('permite vários produtos sem código de barras', () async {
      await produtos.salvar(_produto('A'));
      await produtos.salvar(_produto('B'));
      expect(await produtos.listar(), hasLength(2));
    });

    test('pesquisa por nome e por código', () async {
      await produtos.salvar(_produto('Óleo', codigo: '5551'));
      await produtos.salvar(_produto('Sal', codigo: '7771'));
      expect((await produtos.listar(busca: 'leo')).single.nome, 'Óleo');
      expect((await produtos.listar(busca: '7771')).single.nome, 'Sal');
      expect((await produtos.porCodigo('5551'))!.nome, 'Óleo');
      expect(await produtos.porCodigo('0000'), isNull);
    });
  });

  group('Vendas', () {
    test('venda actualiza stock, regista itens, pagamento e movimentação', () async {
      final id = await produtos.salvar(_produto('Arroz', compra: 120, venda: 150, qtd: 10));
      final v = await vendas.registarVenda(NovaVenda(
        itens: [LinhaVenda(produtoId: id, quantidade: 3)],
        desconto: 0,
        pagamentos: {'dinheiro': 500},
        token: token(),
      ));
      expect(v.total, 450);
      expect(v.troco, 50);
      expect(v.estado, 'paga');
      expect(v.itens.single.custoUnitario, 120);
      expect(v.pagamentos.single.valor, 450); // só o que ficou na caixa
      expect((await produtos.porId(id))!.quantidade, 7);
      final mov = await stock.listarMovimentos(produtoId: id, tipo: 'venda');
      expect(mov.single.quantidade, -3);
      expect(mov.single.stockApos, 7);
    });

    test('rejeita venda sem produtos', () async {
      await _falha(() => vendas.registarVenda(
          NovaVenda(itens: [], desconto: 0, pagamentos: {'dinheiro': 10}, token: token())));
    });

    test('rejeita quantidade superior ao stock e não altera nada', () async {
      final id = await produtos.salvar(_produto('Sumo', qtd: 2));
      final e = await _falha(() => vendas.registarVenda(NovaVenda(
            itens: [LinhaVenda(produtoId: id, quantidade: 3)],
            desconto: 0,
            pagamentos: {'dinheiro': 1000},
            token: token(),
          )));
      expect(e.message, contains('Stock insuficiente'));
      expect((await produtos.porId(id))!.quantidade, 2);
      expect(await vendas.listar(), isEmpty);
    });

    test('é atómica: se um item falha, nenhum stock é descontado', () async {
      final a = await produtos.salvar(_produto('A', qtd: 5));
      final b = await produtos.salvar(_produto('B', qtd: 1));
      await _falha(() => vendas.registarVenda(NovaVenda(
            itens: [LinhaVenda(produtoId: a, quantidade: 2), LinhaVenda(produtoId: b, quantidade: 4)],
            desconto: 0,
            pagamentos: {'dinheiro': 5000},
            token: token(),
          )));
      expect((await produtos.porId(a))!.quantidade, 5);
      expect((await produtos.porId(b))!.quantidade, 1);
    });

    test('o mesmo token não regista a venda duas vezes', () async {
      final id = await produtos.salvar(_produto('A', qtd: 10));
      const t = 'duplicado';
      final venda = NovaVenda(
          itens: [LinhaVenda(produtoId: id, quantidade: 2)],
          desconto: 0,
          pagamentos: {'dinheiro': 200},
          token: t);
      final v1 = await vendas.registarVenda(venda);
      final v2 = await vendas.registarVenda(venda);
      expect(v2.id, v1.id);
      expect(await vendas.listar(), hasLength(1));
      expect((await produtos.porId(id))!.quantidade, 8);
    });

    test('desconto reduz o total; desconto acima do subtotal é rejeitado', () async {
      final id = await produtos.salvar(_produto('A', venda: 100, qtd: 10));
      final v = await vendas.registarVenda(NovaVenda(
          itens: [LinhaVenda(produtoId: id, quantidade: 2)],
          desconto: 20,
          pagamentos: {'dinheiro': 180},
          token: token()));
      expect(v.subtotal, 200);
      expect(v.total, 180);
      await _falha(() => vendas.registarVenda(NovaVenda(
          itens: [LinhaVenda(produtoId: id, quantidade: 1)],
          desconto: 500,
          pagamentos: {'dinheiro': 100},
          token: token())));
    });

    test('pagamento misto regista cada método', () async {
      final id = await produtos.salvar(_produto('A', venda: 100, qtd: 10));
      final v = await vendas.registarVenda(NovaVenda(
          itens: [LinhaVenda(produtoId: id, quantidade: 5)],
          desconto: 0,
          pagamentos: {'dinheiro': 200, 'mpesa': 300},
          token: token()));
      expect(v.pagamentos, hasLength(2));
      expect(v.valorRecebido, 500);
      expect(v.metodoResumo, startsWith('Misto'));
    });

    test('valor inferior ao total exige cliente e fica pendente; depois pode ser liquidado', () async {
      final id = await produtos.salvar(_produto('A', venda: 100, qtd: 10));
      await _falha(() => vendas.registarVenda(NovaVenda(
          itens: [LinhaVenda(produtoId: id, quantidade: 2)],
          desconto: 0,
          pagamentos: {'dinheiro': 50},
          token: token())));

      final cid = await ClienteService().salvar(Cliente(nome: 'Maria', dataCadastro: DateTime.now()));
      final v = await vendas.registarVenda(NovaVenda(
          itens: [LinhaVenda(produtoId: id, quantidade: 2)],
          desconto: 0,
          clienteId: cid,
          pagamentos: {'dinheiro': 50},
          token: token()));
      expect(v.estado, 'pendente');
      expect(v.valorEmFalta, 150);

      await vendas.receberPagamento(v.id!, 'mpesa', 150);
      final paga = (await vendas.porId(v.id!))!;
      expect(paga.estado, 'paga');
      expect(paga.pagamentos, hasLength(2));
    });

    test('troco só pode sair de pagamento em dinheiro', () async {
      final id = await produtos.salvar(_produto('A', venda: 100, qtd: 10));
      await _falha(() => vendas.registarVenda(NovaVenda(
          itens: [LinhaVenda(produtoId: id, quantidade: 1)],
          desconto: 0,
          pagamentos: {'mpesa': 150},
          token: token())));
    });

    test('cancelar devolve o stock e regista a devolução', () async {
      final id = await produtos.salvar(_produto('A', qtd: 10));
      final v = await vendas.registarVenda(NovaVenda(
          itens: [LinhaVenda(produtoId: id, quantidade: 4)],
          desconto: 0,
          pagamentos: {'dinheiro': 400},
          token: token()));
      expect((await produtos.porId(id))!.quantidade, 6);
      await vendas.cancelar(v.id!);
      expect((await produtos.porId(id))!.quantidade, 10);
      expect((await vendas.porId(v.id!))!.estado, 'cancelada');
      expect((await stock.listarMovimentos(produtoId: id, tipo: 'devolucao')).single.quantidade, 4);
      await _falha(() => vendas.cancelar(v.id!));
    });

    test('produto com vendas é desactivado (histórico preservado) em vez de apagado', () async {
      final id = await produtos.salvar(_produto('A', qtd: 10, codigo: '123'));
      final v = await vendas.registarVenda(NovaVenda(
          itens: [LinhaVenda(produtoId: id, quantidade: 1)],
          desconto: 0,
          pagamentos: {'dinheiro': 100},
          token: token()));
      expect(await produtos.eliminar(id), isFalse);
      expect(await produtos.listar(), isEmpty);
      final guardada = (await vendas.porId(v.id!))!;
      expect(guardada.itens.single.nomeProduto, 'A');
    });

    test('produto sem vendas é eliminado definitivamente', () async {
      final id = await produtos.salvar(_produto('A'));
      expect(await produtos.eliminar(id), isTrue);
      expect(await produtos.porId(id), isNull);
    });

    test('preço e custo históricos são preservados após alterar o produto', () async {
      final id = await produtos.salvar(_produto('A', compra: 50, venda: 100, qtd: 10));
      final v = await vendas.registarVenda(NovaVenda(
          itens: [LinhaVenda(produtoId: id, quantidade: 1)],
          desconto: 0,
          pagamentos: {'dinheiro': 100},
          token: token()));
      final p = (await produtos.porId(id))!;
      await produtos.salvar(Produto(
          id: id,
          nome: p.nome,
          precoCompra: 80,
          precoVenda: 200,
          quantidade: p.quantidade,
          stockMinimo: p.stockMinimo,
          dataCadastro: p.dataCadastro));
      final item = (await vendas.porId(v.id!))!.itens.single;
      expect(item.precoUnitario, 100);
      expect(item.custoUnitario, 50);
    });
  });

  group('Stock', () {
    test('entrada, saída e ajuste actualizam a quantidade', () async {
      final id = await produtos.salvar(_produto('A', qtd: 10));
      await stock.registarMovimento(produtoId: id, tipo: 'entrada', quantidade: 5);
      expect((await produtos.porId(id))!.quantidade, 15);
      await stock.registarMovimento(produtoId: id, tipo: 'saida', quantidade: 3, motivo: 'Dano');
      expect((await produtos.porId(id))!.quantidade, 12);
      await stock.registarMovimento(produtoId: id, tipo: 'ajuste', quantidade: 20);
      expect((await produtos.porId(id))!.quantidade, 20);
    });

    test('não permite stock negativo', () async {
      final id = await produtos.salvar(_produto('A', qtd: 2));
      final e = await _falha(() => stock.registarMovimento(produtoId: id, tipo: 'saida', quantidade: 3));
      expect(e.message, contains('Stock insuficiente'));
      expect((await produtos.porId(id))!.quantidade, 2);
    });

    test('a base de dados rejeita stock negativo mesmo por SQL directo', () async {
      final id = await produtos.salvar(_produto('A', qtd: 1));
      final db = await DatabaseHelper.instance.database;
      expect(() => db.rawUpdate('UPDATE produtos SET quantidade = -1 WHERE id = ?', [id]),
          throwsA(isA<DatabaseException>()));
    });
  });

  group('Clientes', () {
    test('não elimina cliente com vendas', () async {
      final pid = await produtos.salvar(_produto('A', qtd: 5));
      final cid = await ClienteService().salvar(Cliente(nome: 'João', dataCadastro: DateTime.now()));
      await vendas.registarVenda(NovaVenda(
          itens: [LinhaVenda(produtoId: pid, quantidade: 1)],
          desconto: 0,
          clienteId: cid,
          pagamentos: {'dinheiro': 100},
          token: token()));
      await _falha(() => ClienteService().eliminar(cid));
      final r = await ClienteService().resumo(cid);
      expect(r.numVendas, 1);
      expect(r.comprado, 100);
    });
  });

  group('Dashboard e demonstração', () {
    test('dados de demonstração carregam e o dashboard reflecte valores reais', () async {
      DatabaseHelper.instance.seedDemoOnCreate = true;
      final d = await RelatorioService().dashboard();
      expect(d.totalProdutos, 12);
      expect(d.stockBaixo, greaterThanOrEqualTo(2));
      expect(d.vendas7Dias, hasLength(7));
      expect(d.vendas7Dias.last.total, d.vendasHoje);
      expect(d.maisVendidos, isNotEmpty);
      expect(d.ultimasVendas, isNotEmpty);
    });

    test('lucro = vendas - custo - despesas', () async {
      final id = await produtos.salvar(_produto('A', compra: 60, venda: 100, qtd: 10));
      await vendas.registarVenda(NovaVenda(
          itens: [LinhaVenda(produtoId: id, quantidade: 2)],
          desconto: 0,
          pagamentos: {'dinheiro': 200},
          token: token()));
      final db = await DatabaseHelper.instance.database;
      final hoje = DateTime.now();
      await db.insert('despesas', {
        'categoria': 'Outras',
        'valor': 30.0,
        'data':
            '${hoje.year.toString().padLeft(4, '0')}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}',
      });
      final d = await RelatorioService().dashboard();
      expect(d.vendasHoje, 200);
      expect(d.despesasHoje, 30);
      expect(d.lucroEstimado, 200 - 120 - 30);
    });
  });
}
