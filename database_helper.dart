import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'demo_data.dart';

/// Acesso único à base de dados SQLite (offline).
///
/// Todas as tabelas têm chaves primárias, chaves estrangeiras, índices e
/// restrições CHECK para garantir a integridade dos dados.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const String dbName = 'gestao_comercial.db';
  static const int dbVersion = 1;

  /// Apenas para testes: caminho alternativo (ex.: inMemoryDatabasePath).
  String? testPath;

  /// Carrega dados de demonstração na primeira execução.
  bool seedDemoOnCreate = true;

  Database? _db;
  Future<Database>? _opening;

  Future<String> get path async => testPath ?? join(await getDatabasesPath(), dbName);

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    return _opening ??= _open().then((db) {
      _db = db;
      return db;
    });
  }

  Future<Database> _open() async {
    final db = await openDatabase(
      await path,
      version: dbVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
    await _ensureInitialData(db);
    return db;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
    _opening = null;
  }

  Future<void> _onCreate(Database db, int version) async {
    const statements = <String>[
      '''CREATE TABLE categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL UNIQUE,
        descricao TEXT
      )''',
      '''CREATE TABLE produtos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        descricao TEXT,
        categoria_id INTEGER REFERENCES categorias(id) ON DELETE SET NULL,
        preco_compra REAL NOT NULL DEFAULT 0 CHECK (preco_compra >= 0),
        preco_venda REAL NOT NULL DEFAULT 0 CHECK (preco_venda >= 0),
        quantidade INTEGER NOT NULL DEFAULT 0 CHECK (quantidade >= 0),
        stock_minimo INTEGER NOT NULL DEFAULT 0 CHECK (stock_minimo >= 0),
        codigo_barras TEXT,
        imagem TEXT,
        ativo INTEGER NOT NULL DEFAULT 1,
        data_cadastro TEXT NOT NULL
      )''',
      'CREATE UNIQUE INDEX idx_produtos_codigo ON produtos(codigo_barras) WHERE codigo_barras IS NOT NULL',
      'CREATE INDEX idx_produtos_nome ON produtos(nome)',
      'CREATE INDEX idx_produtos_categoria ON produtos(categoria_id)',
      '''CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        telefone TEXT,
        endereco TEXT,
        observacoes TEXT,
        data_cadastro TEXT NOT NULL
      )''',
      '''CREATE TABLE fornecedores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        empresa TEXT,
        telefone TEXT,
        email TEXT,
        endereco TEXT,
        observacoes TEXT,
        data_cadastro TEXT NOT NULL
      )''',
      '''CREATE TABLE despesas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        categoria TEXT NOT NULL,
        descricao TEXT,
        valor REAL NOT NULL CHECK (valor > 0),
        data TEXT NOT NULL
      )''',
      'CREATE INDEX idx_despesas_data ON despesas(data)',
      '''CREATE TABLE vendas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero_venda TEXT NOT NULL UNIQUE,
        token TEXT UNIQUE,
        cliente_id INTEGER REFERENCES clientes(id) ON DELETE RESTRICT,
        subtotal REAL NOT NULL CHECK (subtotal >= 0),
        desconto REAL NOT NULL DEFAULT 0 CHECK (desconto >= 0),
        total REAL NOT NULL CHECK (total >= 0),
        valor_recebido REAL NOT NULL DEFAULT 0 CHECK (valor_recebido >= 0),
        troco REAL NOT NULL DEFAULT 0 CHECK (troco >= 0),
        estado TEXT NOT NULL DEFAULT 'paga' CHECK (estado IN ('paga','pendente','cancelada')),
        data_venda TEXT NOT NULL
      )''',
      'CREATE INDEX idx_vendas_data ON vendas(data_venda)',
      'CREATE INDEX idx_vendas_cliente ON vendas(cliente_id)',
      '''CREATE TABLE itens_venda (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venda_id INTEGER NOT NULL REFERENCES vendas(id) ON DELETE CASCADE,
        produto_id INTEGER REFERENCES produtos(id) ON DELETE RESTRICT,
        nome_produto TEXT NOT NULL,
        quantidade INTEGER NOT NULL CHECK (quantidade > 0),
        preco_unitario REAL NOT NULL CHECK (preco_unitario >= 0),
        custo_unitario REAL NOT NULL DEFAULT 0 CHECK (custo_unitario >= 0),
        subtotal REAL NOT NULL CHECK (subtotal >= 0)
      )''',
      'CREATE INDEX idx_itens_venda ON itens_venda(venda_id)',
      'CREATE INDEX idx_itens_produto ON itens_venda(produto_id)',
      '''CREATE TABLE movimentacoes_stock (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        produto_id INTEGER NOT NULL REFERENCES produtos(id) ON DELETE CASCADE,
        tipo TEXT NOT NULL CHECK (tipo IN ('entrada','saida','venda','devolucao','ajuste')),
        quantidade INTEGER NOT NULL,
        stock_apos INTEGER,
        motivo TEXT,
        observacao TEXT,
        fornecedor_id INTEGER REFERENCES fornecedores(id) ON DELETE SET NULL,
        venda_id INTEGER,
        data TEXT NOT NULL
      )''',
      'CREATE INDEX idx_mov_produto ON movimentacoes_stock(produto_id)',
      'CREATE INDEX idx_mov_data ON movimentacoes_stock(data)',
      '''CREATE TABLE pagamentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venda_id INTEGER NOT NULL REFERENCES vendas(id) ON DELETE CASCADE,
        metodo_pagamento TEXT NOT NULL,
        valor REAL NOT NULL CHECK (valor > 0),
        data_pagamento TEXT NOT NULL
      )''',
      'CREATE INDEX idx_pagamentos_venda ON pagamentos(venda_id)',
      '''CREATE TABLE configuracoes (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        nome_estabelecimento TEXT NOT NULL,
        logotipo TEXT,
        endereco TEXT,
        telefone TEXT,
        moeda TEXT NOT NULL DEFAULT 'MZN',
        tema TEXT NOT NULL DEFAULT 'system',
        rodape_recibo TEXT
      )''',
    ];
    for (final sql in statements) {
      await db.execute(sql);
    }
  }

  /// Na primeira execução cria a configuração e, opcionalmente, os dados de demonstração.
  Future<void> _ensureInitialData(Database db) async {
    final cfg = await db.query('configuracoes', where: 'id = 1', limit: 1);
    if (cfg.isNotEmpty) return;
    if (seedDemoOnCreate) {
      await DemoData.seed(db);
    } else {
      await db.insert('configuracoes', {
        'id': 1,
        'nome_estabelecimento': 'O Meu Estabelecimento',
        'moeda': 'MZN',
        'tema': 'system',
        'rodape_recibo': 'Obrigado pela preferência!',
      });
    }
  }

  /// Apaga todos os dados (mantém a configuração).
  Future<void> limparTudo() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final t in [
        'pagamentos',
        'itens_venda',
        'movimentacoes_stock',
        'vendas',
        'produtos',
        'categorias',
        'clientes',
        'fornecedores',
        'despesas',
      ]) {
        await txn.delete(t);
      }
      await txn.delete('sqlite_sequence');
    });
  }

  /// Apaga tudo e volta a carregar os dados de demonstração.
  Future<void> recarregarDemonstracao() async {
    await limparTudo();
    final db = await database;
    await DemoData.seed(db, onlyData: true);
  }
}
