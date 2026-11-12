import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/fornecedor.dart';
import '../../../models/produto.dart';
import '../../../providers/product_provider.dart';
import '../../../services/pessoas_service.dart';

/// Folha para registar entradas, saídas, devoluções e ajustes de stock.
Future<void> showMovementSheet(BuildContext context, Produto produto, {String tipoInicial = 'entrada'}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _MovementForm(produto: produto, tipoInicial: tipoInicial),
    ),
  );
}

class _MovementForm extends StatefulWidget {
  const _MovementForm({required this.produto, required this.tipoInicial});

  final Produto produto;
  final String tipoInicial;

  @override
  State<_MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends State<_MovementForm> {
  final _form = GlobalKey<FormState>();
  final _qtd = TextEditingController();
  final _motivo = TextEditingController();
  final _obs = TextEditingController();
  late String _tipo = widget.tipoInicial;
  int? _fornecedorId;
  List<Fornecedor> _fornecedores = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    FornecedorService().listar().then((f) {
      if (mounted) setState(() => _fornecedores = f);
    });
  }

  @override
  void dispose() {
    _qtd.dispose();
    _motivo.dispose();
    _obs.dispose();
    super.dispose();
  }

  String get _rotuloQtd => _tipo == 'ajuste' ? 'Nova quantidade em stock' : 'Quantidade';

  Future<void> _guardar() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<ProductProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await provider.registarMovimento(
        produtoId: widget.produto.id!,
        tipo: _tipo,
        quantidade: int.parse(_qtd.text.trim()),
        motivo: _motivo.text,
        observacao: _obs.text,
        fornecedorId: _fornecedorId,
      );
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Movimento registado.')));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.produto.nome, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('Stock actual: ${widget.produto.quantidade} un.', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [
                for (final t in AppConstants.manualMovementTypes)
                  ChoiceChip(
                    label: Text(AppConstants.movementLabel(t)),
                    selected: _tipo == t,
                    onSelected: (_) => setState(() => _tipo = t),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _qtd,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(labelText: _rotuloQtd),
              validator: (v) => Validators.integer(v, min: _tipo == 'ajuste' ? 0 : 1),
            ),
            if (_tipo == 'entrada' && _fornecedores.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _fornecedorId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Fornecedor (opcional)'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Sem fornecedor')),
                  for (final f in _fornecedores)
                    DropdownMenuItem<int?>(
                        value: f.id, child: Text(f.empresa?.isNotEmpty == true ? '${f.nome} (${f.empresa})' : f.nome)),
                ],
                onChanged: (v) => setState(() => _fornecedorId = v),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _motivo,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Motivo (ex.: Reposição, Dano, Contagem)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _obs,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Observação'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _guardar,
                child: const Text('Registar movimento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
