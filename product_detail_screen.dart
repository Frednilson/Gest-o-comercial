import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_data.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/movimento_stock.dart';
import '../../../models/produto.dart';
import '../../../providers/product_provider.dart';
import '../../../services/produto_service.dart';
import '../../../services/stock_service.dart';
import '../../stock/widgets/movement_sheet.dart';
import 'product_form_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.produtoId});

  final int produtoId;

  Future<({Produto? produto, List<MovimentoStock> movimentos})> _load() async {
    final p = await ProdutoService().porId(produtoId);
    final m = await StockService().listarMovimentos(produtoId: produtoId, limite: 10);
    return (produto: p, movimentos: m);
  }

  Future<void> _eliminar(BuildContext context, Produto p) async {
    final ok = await confirmDialog(
      context,
      title: 'Eliminar produto',
      message: 'Deseja eliminar "${p.nome}"? Se o produto já tiver vendas, será apenas desactivado '
          'e o histórico de vendas será preservado.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      final eliminado = await context.read<ProductProvider>().eliminar(p.id!);
      if (!context.mounted) return;
      Navigator.pop(context);
      showSnack(context, eliminado ? 'Produto eliminado.' : 'Produto desactivado (tem histórico de vendas).');
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AsyncData<({Produto? produto, List<MovimentoStock> movimentos})>(
      loader: _load,
      builder: (context, data) {
        final p = data.produto;
        if (p == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.inventory_2_outlined, message: 'Produto não encontrado.'),
          );
        }
        final margem = p.precoVenda - p.precoCompra;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalhes do produto'),
            actions: [
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => ProductFormScreen(produto: p))),
              ),
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: () => _eliminar(context, p),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Center(child: ProductImage(path: p.imagem, size: 140, radius: 24)),
              const SizedBox(height: 16),
              Text(p.nome,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              if (p.descricao != null && p.descricao!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(p.descricao!,
                      textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                        icon: Icons.sell_outlined,
                        label: 'Preço de venda',
                        value: Fmt.money(p.precoVenda),
                        color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      icon: Icons.inventory_outlined,
                      label: 'Em stock (mín. ${p.stockMinimo})',
                      value: '${p.quantidade} un.',
                      color: p.semStock
                          ? AppColors.error
                          : p.stockBaixo
                              ? AppColors.warning
                              : AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  children: [
                    _info('Categoria', p.categoriaNome ?? 'Sem categoria'),
                    _info('Preço de compra', Fmt.money(p.precoCompra)),
                    _info('Margem por unidade', Fmt.money(margem)),
                    _info('Código de barras', p.codigoBarras ?? '-'),
                    _info('Cadastrado em', Fmt.date(p.dataCadastro)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => showMovementSheet(context, p),
                icon: const Icon(Icons.swap_vert),
                label: const Text('Movimentar stock'),
              ),
              const SectionTitle('Últimas movimentações'),
              if (data.movimentos.isEmpty)
                Text('Sem movimentações.', style: TextStyle(color: cs.onSurfaceVariant))
              else
                for (final m in data.movimentos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(AppConstants.movementLabel(m.tipo),
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('${Fmt.dateTime(m.data)}${m.motivo != null ? ' · ${m.motivo}' : ''}',
                                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(
                            m.quantidade > 0 ? '+${m.quantidade}' : '${m.quantidade}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: m.quantidade >= 0 ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
