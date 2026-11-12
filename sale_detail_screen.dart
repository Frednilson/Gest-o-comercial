import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/async_data.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/venda.dart';
import '../../../providers/app_data.dart';
import '../../../services/venda_service.dart';
import 'package:provider/provider.dart';
import 'receipt_screen.dart';

class SaleDetailScreen extends StatelessWidget {
  const SaleDetailScreen({super.key, required this.vendaId});

  final int vendaId;

  Future<void> _cancelar(BuildContext context, Venda v) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancelar venda',
      message: 'Cancelar a venda ${v.numeroVenda}? Os produtos serão devolvidos ao stock.',
      confirmLabel: 'Cancelar venda',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final bus = context.read<AppData>();
    try {
      await VendaService().cancelar(v.id!);
      bus.bump();
      if (context.mounted) showSnack(context, 'Venda cancelada e stock reposto.');
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _receber(BuildContext context, Venda v) async {
    final valor = TextEditingController(text: v.valorEmFalta.toStringAsFixed(2));
    String metodo = 'dinheiro';
    final bus = context.read<AppData>();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Receber pagamento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: valor,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor', suffixText: 'MZN'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: metodo,
                decoration: const InputDecoration(labelText: 'Método'),
                items: [
                  for (final e in AppConstants.paymentMethods.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (m) => setS(() => metodo = m!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Receber')),
          ],
        ),
      ),
    );
    final texto = valor.text;
    valor.dispose();
    if (confirmar != true || !context.mounted) return;
    try {
      await VendaService().receberPagamento(v.id!, metodo, Fmt.parseMoney(texto) ?? 0);
      bus.bump();
      if (context.mounted) showSnack(context, 'Pagamento registado.');
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AsyncData<Venda?>(
      loader: () => VendaService().porId(vendaId),
      builder: (context, v) {
        if (v == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.receipt_long_outlined, message: 'Venda não encontrada.'),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(v.numeroVenda)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              AppCard(
                child: Column(
                  children: [
                    _linha('Data', Fmt.dateTime(v.dataVenda)),
                    _linha('Cliente', v.clienteNome ?? 'Não identificado'),
                    _linha('Estado', v.estadoLabel),
                    _linha('Método', v.metodoResumo),
                  ],
                ),
              ),
              const SectionTitle('Produtos'),
              for (final i in v.itens)
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
                              Text(i.nomeProduto, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${i.quantidade} × ${Fmt.money(i.precoUnitario)}',
                                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                            ],
                          ),
                        ),
                        Text(Fmt.money(i.subtotal), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              const SectionTitle('Valores'),
              AppCard(
                child: Column(
                  children: [
                    _linha('Subtotal', Fmt.money(v.subtotal)),
                    _linha('Desconto', '- ${Fmt.money(v.desconto)}'),
                    _linha('Total', Fmt.money(v.total), forte: true),
                    _linha('Valor recebido', Fmt.money(v.valorRecebido)),
                    if (v.troco > 0) _linha('Troco', Fmt.money(v.troco)),
                    if (v.valorEmFalta > 0 && !v.cancelada)
                      _linha('Em falta', Fmt.money(v.valorEmFalta), cor: AppColors.error, forte: true),
                  ],
                ),
              ),
              if (v.pagamentos.isNotEmpty) ...[
                const SectionTitle('Pagamentos'),
                for (final p in v.pagamentos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: _linha('${AppConstants.paymentLabel(p.metodo)} · ${Fmt.dateTime(p.data)}',
                          Fmt.money(p.valor)),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => ReceiptScreen(vendaId: v.id!))),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Ver recibo (PDF)'),
              ),
              if (v.estado == 'pendente') ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _receber(context, v),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Receber pagamento'),
                ),
              ],
              if (!v.cancelada) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  onPressed: () => _cancelar(context, v),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar venda'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _linha(String a, String b, {Color? cor, bool forte = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(a)),
            const SizedBox(width: 8),
            Text(b, style: TextStyle(color: cor, fontWeight: forte ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      );
}
