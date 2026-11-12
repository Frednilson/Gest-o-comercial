import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/relatorio.dart';
import '../../../services/relatorio_service.dart';
import 'report_view_screen.dart';

/// Lista de relatórios disponíveis; cada um abre no ecrã de visualização/PDF.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = RelatorioService();
    DateTimeRange hoje() {
      final n = DateTime.now();
      final d = DateTime(n.year, n.month, n.day);
      return DateTimeRange(start: d, end: d);
    }

    DateTimeRange semana() {
      final n = DateTime.now();
      final d = DateTime(n.year, n.month, n.day);
      return DateTimeRange(start: d.subtract(const Duration(days: 6)), end: d);
    }

    DateTimeRange mes() {
      final n = DateTime.now();
      return DateTimeRange(start: DateTime(n.year, n.month, 1), end: DateTime(n.year, n.month, n.day));
    }

    final itens = <_Item>[
      _Item(Icons.today_outlined, 'Relatório diário de vendas', 'Vendas do dia',
          (p) => s.vendas(p.start, p.end, titulo: 'Relatório diário de vendas'), hoje),
      _Item(Icons.date_range_outlined, 'Relatório semanal', 'Vendas por dia',
          (p) => s.vendasPorDia(p.start, p.end, titulo: 'Relatório semanal de vendas'), semana),
      _Item(Icons.calendar_month_outlined, 'Relatório mensal', 'Vendas por dia do mês',
          (p) => s.vendasPorDia(p.start, p.end, titulo: 'Relatório mensal de vendas'), mes),
      _Item(Icons.emoji_events_outlined, 'Produtos mais vendidos', 'Ranking por quantidade',
          (p) => s.produtosMaisVendidos(p.start, p.end), mes),
      _Item(Icons.inventory_2_outlined, 'Stock', 'Quantidades e valor em stock', (_) => s.stock(), null),
      _Item(Icons.receipt_long_outlined, 'Despesas', 'Despesas por categoria', (p) => s.despesas(p.start, p.end), mes),
      _Item(Icons.savings_outlined, 'Lucro estimado', 'Vendas - custo - despesas', (p) => s.lucro(p.start, p.end), mes),
      _Item(Icons.account_balance_wallet_outlined, 'Histórico de pagamentos', 'Recebimentos por método',
          (p) => s.pagamentos(p.start, p.end), mes),
      _Item(Icons.swap_vert, 'Movimentações de stock', 'Entradas, saídas e ajustes',
          (p) => s.movimentos(p.start, p.end), mes),
    ];

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: itens.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final it = itens[i];
          return AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportViewScreen(
                  titulo: it.titulo,
                  gerar: it.gerar,
                  periodoInicial: it.periodo?.call(),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(it.icone, color: cs.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.titulo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(it.descricao, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Item {
  const _Item(this.icone, this.titulo, this.descricao, this.gerar, this.periodo);

  final IconData icone;
  final String titulo;
  final String descricao;
  final Future<ReportData> Function(DateTimeRange) gerar;

  /// Null para relatórios sem período (ex.: stock actual).
  final DateTimeRange Function()? periodo;
}
