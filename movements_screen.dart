import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_data.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/movimento_stock.dart';
import '../../../services/stock_service.dart';

/// Histórico de movimentações de stock, filtrável por tipo.
class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key, this.fornecedorId, this.titulo = 'Movimentações de stock'});

  final int? fornecedorId;
  final String titulo;

  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  String? _tipo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Todos'),
                    selected: _tipo == null,
                    onSelected: (_) => setState(() => _tipo = null),
                  ),
                ),
                for (final e in AppConstants.movementTypes.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _tipo == e.key,
                      onSelected: (_) => setState(() => _tipo = e.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncData<List<MovimentoStock>>(
              key: ValueKey(_tipo),
              loader: () => StockService().listarMovimentos(tipo: _tipo, fornecedorId: widget.fornecedorId, limite: 300),
              builder: (context, lista) {
                if (lista.isEmpty) {
                  return const EmptyState(icon: Icons.swap_vert, message: 'Sem movimentações.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final m = lista[i];
                    final entrada = m.quantidade >= 0;
                    return AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (entrada ? AppColors.success : AppColors.error).withAlpha(28),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(entrada ? Icons.south_west : Icons.north_east,
                                size: 18, color: entrada ? AppColors.success : AppColors.error),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.produtoNome ?? '-',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  '${AppConstants.movementLabel(m.tipo)} · ${Fmt.dateTime(m.data)}',
                                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                                ),
                                if ((m.motivo ?? '').isNotEmpty || m.fornecedorNome != null)
                                  Text(
                                    [if ((m.motivo ?? '').isNotEmpty) m.motivo!, if (m.fornecedorNome != null) m.fornecedorNome!]
                                        .join(' · '),
                                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                                  ),
                                if ((m.observacao ?? '').isNotEmpty)
                                  Text('Obs.: ${m.observacao}',
                                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(entrada ? '+${m.quantidade}' : '${m.quantidade}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: entrada ? AppColors.success : AppColors.error)),
                              if (m.stockApos != null)
                                Text('→ ${m.stockApos}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
