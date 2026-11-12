import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/produto.dart';
import '../../../providers/product_provider.dart';
import '../../../services/produto_service.dart';
import '../../barcode_scanner/screens/barcode_scanner_screen.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  Future<void> _procurarPorScan(BuildContext context) async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen(mode: ScannerMode.single)),
    );
    if (codigo == null || !context.mounted) return;
    final produto = await ProdutoService().porCodigo(codigo);
    if (!context.mounted) return;
    if (produto != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(produtoId: produto.id!)));
    } else {
      final cadastrar = await confirmDialog(
        context,
        title: 'Produto não cadastrado',
        message: 'Produto não cadastrado. Deseja cadastrar este produto?\n\nCódigo: $codigo',
        confirmLabel: 'Cadastrar',
      );
      if (cadastrar && context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormScreen(codigoInicial: codigo)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos'),
        actions: [
          IconButton(
            tooltip: 'Procurar por código de barras',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _procurarPorScan(context),
          ),
          IconButton(
            tooltip: 'Categorias',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.categories),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Novo produto'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchField(hint: 'Pesquisar por nome ou código', onChanged: provider.setBusca),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Todas'),
                    selected: provider.categoriaId == null,
                    onSelected: (_) => provider.setCategoria(null),
                  ),
                ),
                for (final c in provider.categorias)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c.nome),
                      selected: provider.categoriaId == c.id,
                      onSelected: (_) => provider.setCategoria(c.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: provider.produtos.isEmpty
                ? (provider.loading
                    ? const Center(child: CircularProgressIndicator())
                    : EmptyState(
                        icon: Icons.inventory_2_outlined,
                        message: provider.busca.isEmpty && provider.categoriaId == null
                            ? 'Ainda não há produtos cadastrados.'
                            : 'Nenhum produto encontrado.',
                        actionLabel: provider.busca.isEmpty && provider.categoriaId == null ? 'Cadastrar produto' : null,
                        onAction: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const ProductFormScreen())),
                      ))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    itemCount: provider.produtos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _ProductTile(produto: provider.produtos[i], cs: cs),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.produto, required this.cs});

  final Produto produto;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final baixo = produto.stockBaixo;
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailScreen(produtoId: produto.id!)),
      ),
      child: Row(
        children: [
          ProductImage(path: produto.imagem, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(produto.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  produto.categoriaNome ?? 'Sem categoria',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                Text(Fmt.money(produto.precoVenda),
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${produto.quantidade} un.', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              if (produto.semStock)
                const StatusBadge('Sem stock', color: AppColors.error)
              else if (baixo)
                const StatusBadge('Stock baixo', color: AppColors.warning)
              else
                const StatusBadge('Em stock', color: AppColors.success),
            ],
          ),
        ],
      ),
    );
  }
}
