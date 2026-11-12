import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/produto.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/produto_service.dart';
import '../../barcode_scanner/screens/barcode_scanner_screen.dart';
import 'checkout_screen.dart';
import 'sales_history_screen.dart';

/// Nova venda: pesquisa manual, leitura por câmara e carrinho.
class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final _service = ProdutoService();
  final _busca = TextEditingController();
  List<Produto> _resultados = [];
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    _pesquisar('');
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _pesquisar(String q) async {
    final id = ++_loadId;
    final r = await _service.listar(busca: q);
    if (mounted && id == _loadId) setState(() => _resultados = r);
  }

  Future<void> _scan() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen(mode: ScannerMode.sale)),
    );
    if (mounted) _pesquisar(_busca.text); // actualiza o stock mostrado
  }

  void _adicionar(Produto p) {
    final r = context.read<CartProvider>().add(p);
    switch (r) {
      case AddResult.ok:
        break;
      case AddResult.semStock:
        showSnack(context, '"${p.nome}" está sem stock.', error: true);
      case AddResult.stockInsuficiente:
        showSnack(context, 'Stock insuficiente: só há ${p.quantidade} unidade(s) de "${p.nome}".', error: true);
    }
  }

  Future<void> _verificarEPagar() async {
    final cart = context.read<CartProvider>();
    if (cart.isEmpty) {
      showSnack(context, 'Adicione pelo menos um produto à venda.', error: true);
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
    if (mounted) _pesquisar(_busca.text);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova venda'),
        actions: [
          IconButton(
            tooltip: 'Histórico de vendas',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SalesHistoryScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SearchField(
                    controller: _busca,
                    hint: 'Pesquisar por nome ou código',
                    onChanged: _pesquisar,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Ler código'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (!cart.isEmpty) ...[
                  const SectionTitle('Carrinho'),
                  for (final item in cart.items) _CartTile(item: item),
                  _DescontoCampo(cart: cart),
                ],
                SectionTitle(_busca.text.isEmpty ? 'Produtos' : 'Resultados'),
                if (_resultados.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('Nenhum produto encontrado.', style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                  )
                else
                  for (final p in _resultados)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.all(10),
                        onTap: () => _adicionar(p),
                        child: Row(
                          children: [
                            ProductImage(path: p.imagem, size: 46),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.nome,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('${Fmt.money(p.precoVenda)} · ${p.quantidade} em stock',
                                      style: TextStyle(
                                          color: p.semStock ? AppColors.error : cs.onSurfaceVariant,
                                          fontSize: 12.5)),
                                ],
                              ),
                            ),
                            Icon(Icons.add_circle, color: p.semStock ? cs.outline : cs.primary),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
          if (!cart.isEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(top: BorderSide(color: cs.outlineVariant)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${cart.totalUnidades} unidade(s)', style: TextStyle(color: cs.onSurfaceVariant)),
                          Text(Fmt.money(cart.total),
                              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Limpar carrinho',
                      onPressed: () async {
                        final ok = await confirmDialog(context,
                            title: 'Limpar carrinho',
                            message: 'Remover todos os produtos da venda?',
                            confirmLabel: 'Limpar',
                            destructive: true);
                        if (ok && context.mounted) context.read<CartProvider>().clear();
                      },
                      icon: const Icon(Icons.delete_sweep_outlined),
                    ),
                    FilledButton.icon(
                      onPressed: _verificarEPagar,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Finalizar'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CartTile extends StatelessWidget {
  const _CartTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.produto.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${Fmt.money(item.produto.precoVenda)} × ${item.quantidade}',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                  Text(Fmt.money(item.subtotal),
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Reduzir',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove),
              onPressed: () => cart.decrease(item),
            ),
            SizedBox(
              width: 30,
              child: Text('${item.quantidade}',
                  textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            IconButton.filledTonal(
              tooltip: 'Aumentar',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add),
              onPressed: () {
                if (cart.increase(item) != AddResult.ok) {
                  showSnack(context, 'Stock insuficiente: só há ${item.produto.quantidade} unidade(s).',
                      error: true);
                }
              },
            ),
            IconButton(
              tooltip: 'Remover',
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () => cart.remove(item),
            ),
          ],
        ),
      ),
    );
  }
}

class _DescontoCampo extends StatefulWidget {
  const _DescontoCampo({required this.cart});

  final CartProvider cart;

  @override
  State<_DescontoCampo> createState() => _DescontoCampoState();
}

class _DescontoCampoState extends State<_DescontoCampo> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.cart.desconto > 0 ? widget.cart.desconto.toStringAsFixed(2) : '',
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal'),
              Text(Fmt.money(cart.subtotal), style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(child: Text('Desconto')),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(isDense: true, suffixText: 'MZN', hintText: '0,00'),
                  onChanged: (v) => cart.setDesconto(Fmt.parseMoney(v) ?? 0),
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(Fmt.money(cart.total),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: cs.primary)),
            ],
          ),
        ],
      ),
    );
  }
}
