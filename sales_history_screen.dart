import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_data.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/venda.dart';
import '../../../services/venda_service.dart';
import 'sale_detail_screen.dart';

/// Histórico de vendas com pesquisa e filtro por período.
class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key, this.clienteId, this.titulo = 'Histórico de vendas'});

  final int? clienteId;
  final String titulo;

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  String _busca = '';
  DateTimeRange? _periodo;

  Future<List<Venda>> _load() => VendaService().listar(
        busca: _busca,
        de: _periodo?.start,
        ate: _periodo?.end,
        clienteId: widget.clienteId,
      );

  Color _cor(Venda v) {
    switch (v.estado) {
      case 'paga':
        return AppColors.success;
      case 'pendente':
        return AppColors.warning;
      default:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        actions: [
          IconButton(
            tooltip: 'Filtrar por período',
            icon: Icon(Icons.date_range, color: _periodo != null ? cs.primary : null),
            onPressed: () async {
              final r = await pickDateRange(context, _periodo);
              if (r != null) setState(() => _periodo = r);
            },
          ),
          if (_periodo != null)
            IconButton(
              tooltip: 'Limpar filtro',
              icon: const Icon(Icons.filter_alt_off_outlined),
              onPressed: () => setState(() => _periodo = null),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchField(
              hint: 'Pesquisar por nº da venda ou cliente',
              onChanged: (v) => setState(() => _busca = v),
            ),
          ),
          if (_periodo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('Período: ${Fmt.periodLabel(_periodo!.start, _periodo!.end)}',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          Expanded(
            child: AsyncData<List<Venda>>(
              key: ValueKey('$_busca|$_periodo'),
              loader: _load,
              builder: (context, vendas) {
                if (vendas.isEmpty) {
                  return const EmptyState(icon: Icons.receipt_long_outlined, message: 'Nenhuma venda encontrada.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: vendas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final v = vendas[i];
                    return AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => SaleDetailScreen(vendaId: v.id!))),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(v.numeroVenda, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  '${Fmt.dateTime(v.dataVenda)}${v.clienteNome != null ? ' · ${v.clienteNome}' : ''}',
                                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(Fmt.money(v.total),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    decoration: v.cancelada ? TextDecoration.lineThrough : null,
                                  )),
                              const SizedBox(height: 4),
                              StatusBadge(v.estadoLabel, color: _cor(v)),
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
