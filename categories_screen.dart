import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/categoria.dart';
import '../../../providers/product_provider.dart';
import '../../../services/produto_service.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<void> _editar(BuildContext context, {Categoria? categoria}) async {
    final ctrl = TextEditingController(text: categoria?.nome ?? '');
    final nome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(categoria == null ? 'Nova categoria' : 'Editar categoria'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Nome da categoria'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Guardar')),
        ],
      ),
    );
    ctrl.dispose();
    if (nome == null || nome.trim().isEmpty || !context.mounted) return;
    try {
      await context
          .read<ProductProvider>()
          .salvarCategoria(Categoria(id: categoria?.id, nome: nome, descricao: categoria?.descricao));
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _eliminar(BuildContext context, Categoria c) async {
    final usados = await ProdutoService().contarProdutosDaCategoria(c.id!);
    if (!context.mounted) return;
    final ok = await confirmDialog(
      context,
      title: 'Eliminar categoria',
      message: usados > 0
          ? 'A categoria "${c.nome}" tem $usados produto(s). Eles ficarão sem categoria. Continuar?'
          : 'Eliminar a categoria "${c.nome}"?',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await context.read<ProductProvider>().eliminarCategoria(c.id!);
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias = context.watch<ProductProvider>().categorias;
    return Scaffold(
      appBar: AppBar(title: const Text('Categorias')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova categoria'),
      ),
      body: categorias.isEmpty
          ? const EmptyState(icon: Icons.category_outlined, message: 'Ainda não há categorias.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
              itemCount: categorias.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = categorias[i];
                return AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.label_outline, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(child: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w600))),
                      IconButton(
                          tooltip: 'Editar',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editar(context, categoria: c)),
                      IconButton(
                          tooltip: 'Eliminar',
                          icon: const Icon(Icons.delete_outline, color: AppColors.error),
                          onPressed: () => _eliminar(context, c)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
