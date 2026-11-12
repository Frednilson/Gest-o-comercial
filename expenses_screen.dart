import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/despesa.dart';
import '../../../providers/people_providers.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  IconData _icone(String c) {
    switch (c) {
      case 'Transporte':
        return Icons.local_shipping_outlined;
      case 'Energia':
        return Icons.bolt_outlined;
      case 'Água':
        return Icons.water_drop_outlined;
      case 'Renda':
        return Icons.home_work_outlined;
      case 'Salários':
        return Icons.badge_outlined;
      case 'Manutenção':
        return Icons.build_outlined;
      case 'Comunicação':
        return Icons.phone_android;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  Future<void> _eliminar(BuildContext context, Despesa d) async {
    final ok = await confirmDialog(context,
        title: 'Eliminar despesa',
        message: 'Eliminar a despesa de ${Fmt.money(d.valor)} (${d.categoria})?',
        confirmLabel: 'Eliminar',
        destructive: true);
    if (!ok || !context.mounted) return;
    try {
      await context.read<ExpenseProvider>().eliminar(d.id!);
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ExpenseProvider>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Despesas'),
        actions: [
          IconButton(
            tooltip: 'Filtrar por período',
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final r = await pickDateRange(context, p.periodo);
              if (r != null) p.setPeriodo(r);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Nova despesa'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: AppCard(
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total: ${p.periodoLabel}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                        Text(Fmt.money(p.total), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: p.despesas.isEmpty
                ? const EmptyState(icon: Icons.receipt_long_outlined, message: 'Sem despesas no período.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: p.despesas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final d = p.despesas[i];
                      return AppCard(
                        padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => ExpenseFormScreen(despesa: d))),
                        child: Row(
                          children: [
                            Icon(_icone(d.categoria), color: cs.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d.categoria, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    '${Fmt.date(d.data)}${(d.descricao ?? '').isNotEmpty ? ' · ${d.descricao}' : ''}',
                                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Text(Fmt.money(d.valor), style: const TextStyle(fontWeight: FontWeight.w800)),
                            IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(Icons.delete_outline, color: AppColors.error),
                              onPressed: () => _eliminar(context, d),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key, this.despesa});

  final Despesa? despesa;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _valor =
      TextEditingController(text: widget.despesa == null ? '' : widget.despesa!.valor.toStringAsFixed(2));
  late final _desc = TextEditingController(text: widget.despesa?.descricao ?? '');
  late String _categoria = widget.despesa?.categoria ?? AppConstants.expenseCategories.first;
  late DateTime _data = widget.despesa?.data ?? DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _valor.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'PT'),
    );
    if (d != null) setState(() => _data = d);
  }

  Future<void> _guardar() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<ExpenseProvider>().salvar(Despesa(
            id: widget.despesa?.id,
            categoria: _categoria,
            descricao: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
            valor: Fmt.parseMoney(_valor.text) ?? 0,
            data: _data,
          ));
      if (mounted) {
        showSnack(context, 'Despesa guardada.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.despesa == null ? 'Nova despesa' : 'Editar despesa')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            DropdownButtonFormField<String>(
              value: _categoria,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: [for (final c in AppConstants.expenseCategories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _categoria = v!),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _valor,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor *', suffixText: 'MZN'),
              validator: (v) => Validators.money(v, allowZero: false),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _escolherData,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Data', suffixIcon: Icon(Icons.calendar_today_outlined)),
                child: Text(Fmt.date(_data)),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _desc,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _guardar,
              icon: const Icon(Icons.check),
              label: const Text('Guardar despesa'),
            ),
          ],
        ),
      ),
    );
  }
}
