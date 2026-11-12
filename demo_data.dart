import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../services/venda_service.dart';
import '../utils/app_exception.dart';

/// Dados de demonstração (valores em Meticais) para os primeiros testes.
class DemoData {
  DemoData._();

  /// Calcula o dígito de controlo EAN-13 a partir dos 12 primeiros dígitos.
  static String ean13(String first12) {
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += int.parse(first12[i]) * (i.isEven ? 1 : 3);
    }
    return '$first12${(10 - sum % 10) % 10}';
  }

  /// [onlyData] = true não recria a configuração.
  static Future<void> seed(Database db, {bool onlyData = false}) async {
    await db.transaction((txn) async {
      final now = DateTime.now();

      if (!onlyData) {
        await txn.insert('configuracoes', {
          'id': 1,
          'nome_estabelecimento': 'Loja Demonstração',
          'endereco': 'Av. 25 de Setembro, Maputo',
          'telefone': '+258 84 000 0000',
          'moeda': 'MZN',
          'tema': 'system',
          'rodape_recibo': 'Obrigado pela preferência!',
        });
      }

      // Categorias
      final catIds = <String, int>{};
      for (final c in ['Alimentação', 'Bebidas', 'Higiene', 'Limpeza', 'Outros']) {
        catIds[c] = await txn.insert('categorias', {'nome': c});
      }

      // Fornecedores
      final fornecedores = [
        ['Carlos Macamo', 'Distribuidora Maputo, Lda', '+258 84 111 2233', 'vendas@distmaputo.co.mz', 'Av. Eduardo Mondlane, Maputo'],
        ['Fátima Nhaca', 'Grossista Matola', '+258 82 444 5566', 'geral@grossistamatola.co.mz', 'Estrada Nacional 4, Matola'],
      ];
      final fornIds = <int>[];
      for (final f in fornecedores) {
        fornIds.add(await txn.insert('fornecedores', {
          'nome': f[0],
          'empresa': f[1],
          'telefone': f[2],
          'email': f[3],
          'endereco': f[4],
          'data_cadastro': now.toIso8601String(),
        }));
      }

      // Clientes
      final clientes = [
        ['Maria Fernanda Cossa', '+258 84 321 0001', 'Bairro Central, Maputo'],
        ['João Manuel Tembe', '+258 82 321 0002', 'Matola Rio'],
        ['Ana Paula Mondlane', '+258 86 321 0003', 'Bairro da Polana'],
      ];
      final clienteIds = <int>[];
      for (final c in clientes) {
        clienteIds.add(await txn.insert('clientes', {
          'nome': c[0],
          'telefone': c[1],
          'endereco': c[2],
          'data_cadastro': now.toIso8601String(),
        }));
      }

      // Produtos: nome, categoria, compra, venda, quantidade, mínimo, base EAN
      final produtos = <List<Object>>[
        ['Arroz Tio Lucas 2kg', 'Alimentação', 120.0, 150.0, 60, 10, '600100000001'],
        ['Óleo Alimentar 1L', 'Alimentação', 140.0, 175.0, 45, 8, '600100000002'],
        ['Açúcar 1kg', 'Alimentação', 65.0, 85.0, 50, 10, '600100000003'],
        ['Farinha de Milho 2kg', 'Alimentação', 70.0, 95.0, 45, 10, '600100000004'],
        ['Sal Fino 1kg', 'Alimentação', 15.0, 25.0, 70, 15, '600100000005'],
        ['Coca-Cola 500ml', 'Bebidas', 30.0, 45.0, 90, 20, '600100000006'],
        ['Água Mineral 1.5L', 'Bebidas', 25.0, 40.0, 70, 15, '600100000007'],
        ['Sumo Compal 1L', 'Bebidas', 70.0, 95.0, 6, 10, '600100000008'],
        ['Sabonete Protex', 'Higiene', 35.0, 55.0, 50, 10, '600100000009'],
        ['Pasta Dentífrica Colgate', 'Higiene', 60.0, 90.0, 8, 10, '600100000010'],
        ['Detergente Omo 1kg', 'Limpeza', 110.0, 150.0, 25, 5, '600100000011'],
        ['Lixívia 1L', 'Limpeza', 40.0, 60.0, 30, 8, '600100000012'],
      ];

      final stamp = now.subtract(const Duration(days: 8)).toIso8601String();
      final prodIds = <int>[];
      for (final p in produtos) {
        final qtd = p[4] as int;
        final id = await txn.insert('produtos', {
          'nome': p[0],
          'categoria_id': catIds[p[1]],
          'preco_compra': p[2],
          'preco_venda': p[3],
          'quantidade': qtd,
          'stock_minimo': p[5],
          'codigo_barras': ean13(p[6] as String),
          'ativo': 1,
          'data_cadastro': stamp,
        });
        prodIds.add(id);
        await txn.insert('movimentacoes_stock', {
          'produto_id': id,
          'tipo': 'entrada',
          'quantidade': qtd,
          'stock_apos': qtd,
          'motivo': 'Stock inicial',
          'fornecedor_id': fornIds[id % fornIds.length],
          'data': stamp,
        });
      }

      // Despesas dos últimos dias
      final despesas = [
        ['Transporte', 'Transporte de mercadoria', 350.0, 6],
        ['Energia', 'Recarga de electricidade', 1200.0, 5],
        ['Água', 'Factura de água', 450.0, 4],
        ['Comunicação', 'Saldo de telemóvel', 200.0, 3],
        ['Manutenção', 'Reparação de prateleira', 600.0, 1],
        ['Outras', 'Material de limpeza da loja', 150.0, 0],
      ];
      for (final d in despesas) {
        final dia = now.subtract(Duration(days: d[3] as int));
        await txn.insert('despesas', {
          'categoria': d[0],
          'descricao': d[1],
          'valor': d[2],
          'data': '${dia.year.toString().padLeft(4, '0')}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}',
        });
      }

      // Vendas dos últimos 7 dias (não usa os produtos com stock baixo: índices 7 e 9)
      final rnd = Random(42);
      const vendaveis = [0, 1, 2, 3, 4, 5, 6, 8, 10, 11];
      const metodos = ['dinheiro', 'mpesa', 'emola', 'dinheiro'];
      var seq = 0;
      for (var d = 6; d >= 0; d--) {
        final numVendas = d == 0 ? 3 : 2 + rnd.nextInt(2);
        for (var k = 0; k < numVendas; k++) {
          final nLinhas = 1 + rnd.nextInt(3);
          final escolhidos = <int>{};
          while (escolhidos.length < nLinhas) {
            escolhidos.add(vendaveis[rnd.nextInt(vendaveis.length)]);
          }
          final linhas = escolhidos
              .map((i) => LinhaVenda(produtoId: prodIds[i], quantidade: 1 + rnd.nextInt(3)))
              .toList();

          var total = 0.0;
          for (final l in linhas) {
            final idx = prodIds.indexOf(l.produtoId);
            total += (produtos[idx][3] as double) * l.quantidade;
          }
          final metodo = metodos[seq % metodos.length];
          final recebido = metodo == 'dinheiro' ? (total / 50).ceil() * 50.0 : total;

          final DateTime data;
          if (d == 0) {
            data = now.subtract(Duration(minutes: 25 * (k + 1)));
          } else {
            final base = DateTime(now.year, now.month, now.day, 8 + rnd.nextInt(10), rnd.nextInt(60));
            data = base.subtract(Duration(days: d));
          }

          try {
            await VendaService.inserirVendaTxn(
              txn,
              NovaVenda(
                itens: linhas,
                desconto: 0,
                clienteId: seq % 3 == 0 ? clienteIds[seq % clienteIds.length] : null,
                pagamentos: {metodo: recebido},
                token: 'demo-$d-$k',
              ),
              data,
            );
          } on AppException {
            // Stock de demonstração esgotado: ignora esta venda (a validação ocorre antes de qualquer escrita).
          }
          seq++;
        }
      }
    });
  }
}
