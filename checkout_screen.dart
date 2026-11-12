import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/cliente.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/people_providers.dart';
import 'sale_confirmation_screen.dart';

/// Finalização da venda: cliente, métodos de pagamento, valor recebido e troco.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  /// 'dinheiro' | 'mpesa' | 'emola' | 'transferencia' | 'misto'
  String _modo = 'dinheiro';
  final _recebido = TextEditingController();
  final Map<String, TextEditingController> _misto = {
    for (final k in AppConstants.paymentMethods.keys) k: TextEditingController(),
  };

  @override
  void dispose() {
    _recebido.dispose();
    for (final c in _misto.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _valor(TextEditingController c) => Fmt.parseMoney(c.text) ?? 0;

  /// método -> valor entregue, conforme o modo escolhido.
  Map<String, double> _pagamentos(double total) {
    if (_modo == 'misto') {
      return {
        for (final e in _misto.entries)
          if (_valor(e.value) > 0) e.key: _valor(e.value),
      };
    }
    final v = _recebido.text.trim().isEmpty && _modo != 'dinheiro' ? total : _valor(_recebido);
    return v > 0 ? {_modo: v} : {};
  }

  Future<void> _escolherCliente() async {
    final cart = context.read<CartProvider>();
    final escolhido = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _SeletorCliente(),
    );
    if (escolhido is Cliente) cart.setCliente(escolhido);
    if (escolhido == 'nenhum') cart.setCliente(null);
  }

  Future<void> _confirmar() async {
    final cart = context.read<CartProvider>();
    final pagamentos = _pagamentos(cart.total);
    final recebido = pagamentos.values.fold(0.0, (s, v) => s + v);
    final navigator = Navigator.of(context);

    if (cart.total > 0 && recebido < cart.total - 0.004 && cart.cliente == null) {
      showSnack(context, 'Valor recebido inferior ao total. Seleccione um cliente para vender com valor em falta.',
          error: true);
      return;
    }
    if (recebido < cart.total - 0.004) {
      final ok = await confirmDialog(
        context,
        title: 'Venda com valor em falta',
        message: 'Faltam ${Fmt.money(cart.total - recebido)}. A venda ficará pendente em nome de '
            '${cart.cliente!.nome}. Continuar?',
      );
      if (!ok) return;
    }
    try {
      final venda = await cart.confirmar(pagamentos);
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => SaleConfirmationScreen(vendaId: venda.id!)),
      );
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final cs = Theme.of(context).colorScheme;
    final total = cart.total;
    final pagamentos = _pagamentos(total);
    final recebido = pagamentos.values.fold(0.0, (s, v) => s + v);
    final emFalta = recebido < total - 0.004 ? total - recebido : 0.0;
    final troco = recebido > total ? recebido - total : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar venda')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          AppCard(
            child: Column(
              children: [
                _linha('Produtos', '${cart.totalUnidades} unidade(s)'),
                _linha('Subtotal', Fmt.money(cart.subtotal)),
                _linha('Desconto', '- ${Fmt.money(cart.desconto)}'),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Valor total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(Fmt.money(total),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: cs.primary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            onTap: _escolherCliente,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.person_outline, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cliente', style: TextStyle(fontSize: 12.5)),
                      Text(cart.cliente?.nome ?? 'Cliente não identificado',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SectionTitle('Método de pagamento'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in AppConstants.paymentMethods.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: _modo == e.key,
                  onSelected: (_) => setState(() {
                    _modo = e.key;
                    _recebido.clear();
                  }),
                ),
              ChoiceChip(
                label: const Text('Pagamento misto'),
                selected: _modo == 'misto',
                onSelected: (_) => setState(() => _modo = 'misto'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_modo == 'misto') ...[
            for (final e in AppConstants.paymentMethods.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _misto[e.key],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: e.value, suffixText: 'MZN'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
          ] else ...[
            TextField(
              controller: _recebido,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Valor recebido',
                suffixText: 'MZN',
                helperText: _modo == 'dinheiro' ? null : 'Deixe vazio para o valor total.',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Valor exacto'),
                  onPressed: () => setState(() => _recebido.text = total.toStringAsFixed(2)),
                ),
                for (final v in [100, 200, 500, 1000])
                  if (v >= total)
                    ActionChip(
                      label: Text('$v'),
                      onPressed: () => setState(() => _recebido.text = v.toStringAsFixed(2)),
                    ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                _linha('Valor recebido', Fmt.money(recebido)),
                _linha('Valor em falta', Fmt.money(emFalta),
                    cor: emFalta > 0 ? AppColors.error : null),
                _linha('Troco', Fmt.money(troco), cor: troco > 0 ? AppColors.success : null, forte: true),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: cart.saving ? null : _confirmar,
            icon: cart.saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_circle_outline),
            label: const Text('Confirmar Venda'),
          ),
        ],
      ),
    );
  }

  Widget _linha(String a, String b, {Color? cor, bool forte = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(a),
            Text(b,
                style: TextStyle(
                    color: cor, fontWeight: forte ? FontWeight.w800 : FontWeight.w600, fontSize: forte ? 16 : null)),
          ],
        ),
      );
}

class _SeletorCliente extends StatefulWidget {
  const _SeletorCliente();

  @override
  State<_SeletorCliente> createState() => _SeletorClienteState();
}

class _SeletorClienteState extends State<_SeletorCliente> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SearchField(hint: 'Pesquisar cliente', onChanged: provider.setBusca),
            ),
            ListTile(
              leading: const Icon(Icons.person_off_outlined),
              title: const Text('Cliente não identificado'),
              onTap: () => Navigator.pop(context, 'nenhum'),
            ),
            const Divider(),
            Expanded(
              child: provider.clientes.isEmpty
                  ? const EmptyState(icon: Icons.people_outline, message: 'Nenhum cliente encontrado.')
                  : ListView.builder(
                      itemCount: provider.clientes.length,
                      itemBuilder: (context, i) {
                        final c = provider.clientes[i];
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(c.nome),
                          subtitle: c.telefone != null ? Text(c.telefone!) : null,
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
