import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/produto.dart';
import '../../../core/widgets/async_data.dart';
import '../../../services/produto_service.dart';
import '../widgets/movement_sheet.dart';

/// Gestão de stock: consulta, alertas de reposição e movimentos.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String _busca = '';
  bool _apenasBaixo = false;

  @override
  Widget build(BuildContext context) {
    return AsyncData<List<Produto>>(
      loader: () => ProdutoService().listar(),
      builder: _conteudo,
    );
  }

  Widget _conteudo(BuildContext context, List<Produto> todos) {
    final cs = Theme.of(context).colorScheme;

    // Lista completa (independente dos filtros do ecrã Produtos); a pesquisa é local.
    final baixos = todos.where((p) => p.stockBaixo).toList();
    final lista = todos.where((p) {
      if (_apenasBaixo && !p.stockBaixo) return false;
      if (_busca.isEmpty) return true;
      final q = _busca.toLowerCase();
      return p.nome.toLowerCase().contains(q) || (p.codigoBarras ?? '').contains(q);
    }).toList();

    final unidades = todos.fold<int>(0, (s, p) => s + p.quantidade);
    final valor = todos.fold<double>(0, (s, p) => s + p.quantidade * p.precoCompra);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          IconButton(
            tooltip: 'Histórico de movimentações',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.movements),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                    icon: Icons.inventory_2_outlined,
                    label: 'Unidades em stock',
                    value: '$unidades',
                    color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Valor (custo)',
                    value: Fmt.money(valor),
                    color: AppColors.success),
              ),
            ],
          ),
          if (baixos.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              onTap: () => setState(() => _apenasBaixo = !_apenasBaixo),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${baixos.length} produto(s) precisam de reposição',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(_apenasBaixo ? 'Ver todos' : 'Ver',
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SearchField(hint: 'Pesquisar produto', onChanged: (v) => setState(() => _busca = v)),
          const SizedBox(height: 12),
          if (lista.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: EmptyState(icon: Icons.inventory_2_outlined, message: 'Nenhum produto encontrado.'),
            )
          else
            for (final p in lista) _StockTile(produto: p),
        ],
      ),
    );
  }
}

class _StockTile extends StatelessWidget {
  const _StockTile({required this.produto});

  final Produto produto;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cor = produto.semStock
        ? AppColors.error
        : produto.stockBaixo
            ? AppColors.warning
            : AppColors.success;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        onTap: () => showMovementSheet(context, produto),
        child: Row(
          children: [
            ProductImage(path: produto.imagem, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(produto.nome,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Mínimo: ${produto.stockMinimo}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${produto.quantidade}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cor)),
                if (produto.stockBaixo)
                  StatusBadge(produto.semStock ? 'Sem stock' : 'Repor', color: cor),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.swap_vert, color: cs.primary),
          ],
        ),
      ),
    );
  }
}
