import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_data.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/relatorio.dart';
import '../../../providers/config_provider.dart';
import '../../../services/relatorio_service.dart';
import '../../sales/screens/sale_detail_screen.dart';

/// Painel principal com indicadores reais calculados a partir da base de dados.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onGoTo});

  /// Muda de separador na navegação inferior (0 Início, 1 Produtos, 2 Vendas, 3 Stock, 4 Mais).
  final ValueChanged<int> onGoTo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nome = context.watch<ConfigProvider>().config.nomeEstabelecimento;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(Fmt.date(DateTime.now()), style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
      body: AsyncData<DashboardData>(
        loader: RelatorioService().dashboard,
        builder: (context, d) {
          final lucroCor = d.lucroEstimado >= 0 ? AppColors.success : AppColors.error;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.55,
                children: [
                  StatCard(
                      icon: Icons.trending_up,
                      label: 'Vendas de hoje',
                      value: Fmt.money(d.vendasHoje),
                      color: cs.primary,
                      onTap: () => onGoTo(2)),
                  StatCard(
                      icon: Icons.receipt_long_outlined,
                      label: 'Nº de vendas',
                      value: '${d.numVendasHoje}',
                      color: cs.primary),
                  StatCard(
                      icon: Icons.inventory_2_outlined,
                      label: 'Produtos cadastrados',
                      value: '${d.totalProdutos}',
                      color: AppColors.success,
                      onTap: () => onGoTo(1)),
                  StatCard(
                      icon: Icons.warning_amber_rounded,
                      label: 'Stock baixo',
                      value: '${d.stockBaixo}',
                      color: d.stockBaixo > 0 ? AppColors.warning : AppColors.success,
                      onTap: () => onGoTo(3)),
                  StatCard(
                      icon: Icons.payments_outlined,
                      label: 'Despesas de hoje',
                      value: Fmt.money(d.despesasHoje),
                      color: AppColors.error),
                  StatCard(
                      icon: Icons.savings_outlined,
                      label: 'Lucro estimado (hoje)',
                      value: Fmt.money(d.lucroEstimado),
                      color: lucroCor),
                ],
              ),
              const SectionTitle('Vendas dos últimos 7 dias'),
              AppCard(
                padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
                child: SizedBox(height: 190, child: _GraficoVendas(dias: d.vendas7Dias)),
              ),
              const SectionTitle('Produtos mais vendidos'),
              if (d.maisVendidos.isEmpty)
                Text('Ainda sem vendas registadas.', style: TextStyle(color: cs.onSurfaceVariant))
              else
                AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < d.maisVendidos.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: cs.primaryContainer,
                                child: Text('${i + 1}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.primary)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(d.maisVendidos[i].nome,
                                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                              Text('${d.maisVendidos[i].quantidade} un.',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              SectionTitle('Últimas vendas',
                  trailing: TextButton(onPressed: () => onGoTo(2), child: const Text('Nova venda'))),
              if (d.ultimasVendas.isEmpty)
                Text('Ainda sem vendas registadas.', style: TextStyle(color: cs.onSurfaceVariant))
              else
                for (final v in d.ultimasVendas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      onTap: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => SaleDetailScreen(vendaId: v.id!))),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(v.numeroVenda, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(Fmt.dateTime(v.dataVenda),
                                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(Fmt.money(v.total),
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  decoration: v.cancelada ? TextDecoration.lineThrough : null)),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _GraficoVendas extends StatelessWidget {
  const _GraficoVendas({required this.dias});

  final List<DiaVenda> dias;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maximo = dias.fold<double>(0, (m, d) => d.total > m ? d.total : m);
    final topo = maximo <= 0 ? 100.0 : maximo * 1.2;

    return BarChart(
      BarChartData(
        maxY: topo,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: topo / 4,
          getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: topo / 4,
              getTitlesWidget: (v, meta) {
                if (v == meta.max) return const SizedBox.shrink();
                return Text(
                  v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
                  style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= dias.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(Fmt.shortWeekday(dias[i].dia),
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              Fmt.money(rod.toY),
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < dias.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: dias[i].total,
                  width: 18,
                  color: i == dias.length - 1 ? cs.primary : cs.primary.withAlpha(120),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
