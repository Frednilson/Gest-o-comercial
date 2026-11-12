import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/venda.dart';
import '../../../services/venda_service.dart';
import 'receipt_screen.dart';

/// Venda concluída: resumo e acesso ao recibo.
class SaleConfirmationScreen extends StatelessWidget {
  const SaleConfirmationScreen({super.key, required this.vendaId});

  final int vendaId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Venda?>(
          future: VendaService().porId(vendaId),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final v = snap.data!;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.6, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    builder: (context, s, child) => Transform.scale(scale: s, child: child),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(color: AppColors.success.withAlpha(30), shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 60, color: AppColors.success),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(v.estado == 'pendente' ? 'Venda registada (pendente)' : 'Venda concluída!',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(v.numeroVenda, style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  AppCard(
                    child: Column(
                      children: [
                        _linha('Total', Fmt.money(v.total), forte: true),
                        _linha('Método', v.metodoResumo),
                        _linha('Valor recebido', Fmt.money(v.valorRecebido)),
                        if (v.troco > 0) _linha('Troco', Fmt.money(v.troco), cor: AppColors.success, forte: true),
                        if (v.valorEmFalta > 0)
                          _linha('Em falta', Fmt.money(v.valorEmFalta), cor: AppColors.error, forte: true),
                      ],
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => ReceiptScreen(vendaId: v.id!))),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Ver recibo'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Nova venda'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _linha(String a, String b, {Color? cor, bool forte = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(a),
            Flexible(
              child: Text(b,
                  textAlign: TextAlign.end,
                  style: TextStyle(color: cor, fontWeight: forte ? FontWeight.w800 : FontWeight.w600)),
            ),
          ],
        ),
      );
}
