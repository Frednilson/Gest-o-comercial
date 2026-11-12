import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/fornecedor.dart';
import '../../../providers/people_providers.dart';
import '../../stock/screens/movements_screen.dart';

class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SupplierProvider>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Fornecedores')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Novo fornecedor'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchField(hint: 'Pesquisar fornecedor', onChanged: p.setBusca),
          ),
          Expanded(
            child: p.fornecedores.isEmpty
                ? EmptyState(
                    icon: Icons.local_shipping_outlined,
                    message: p.busca.isEmpty ? 'Ainda não há fornecedores.' : 'Nenhum fornecedor encontrado.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    itemCount: p.fornecedores.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final f = p.fornecedores[i];
                      return AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => SupplierDetailScreen(fornecedor: f))),
                        child: Row(
                          children: [
                            Icon(Icons.local_shipping_outlined, color: cs.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    [if ((f.empresa ?? '').isNotEmpty) f.empresa!, if ((f.telefone ?? '').isNotEmpty) f.telefone!]
                                        .join(' · '),
                                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right),
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

class SupplierDetailScreen extends StatelessWidget {
  const SupplierDetailScreen({super.key, required this.fornecedor});

  final Fornecedor fornecedor;

  Future<void> _eliminar(BuildContext context) async {
    final ok = await confirmDialog(context,
        title: 'Eliminar fornecedor',
        message: 'Eliminar "${fornecedor.nome}"? O histórico de stock é mantido.',
        confirmLabel: 'Eliminar',
        destructive: true);
    if (!ok || !context.mounted) return;
    try {
      await context.read<SupplierProvider>().eliminar(fornecedor.id!);
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fornecedor'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.push(
                  context, MaterialPageRoute(builder: (_) => SupplierFormScreen(fornecedor: fornecedor)));
              if (context.mounted) Navigator.pop(context);
            },
          ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: () => _eliminar(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(fornecedor.nome, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                _info('Empresa', fornecedor.empresa),
                _info('Contacto', fornecedor.telefone),
                _info('Email', fornecedor.email),
                _info('Endereço', fornecedor.endereco),
                _info('Observações', fornecedor.observacoes),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MovementsScreen(
                    fornecedorId: fornecedor.id, titulo: 'Fornecimentos de ${fornecedor.nome}'),
              ),
            ),
            icon: const Icon(Icons.history),
            label: const Text('Histórico de fornecimento'),
          ),
        ],
      ),
    );
  }

  Widget _info(String a, String? b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(a),
            const SizedBox(width: 16),
            Flexible(
                child: Text((b ?? '').isEmpty ? '-' : b!,
                    textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class SupplierFormScreen extends StatefulWidget {
  const SupplierFormScreen({super.key, this.fornecedor});

  final Fornecedor? fornecedor;

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.fornecedor?.nome ?? '');
  late final _empresa = TextEditingController(text: widget.fornecedor?.empresa ?? '');
  late final _tel = TextEditingController(text: widget.fornecedor?.telefone ?? '');
  late final _email = TextEditingController(text: widget.fornecedor?.email ?? '');
  late final _end = TextEditingController(text: widget.fornecedor?.endereco ?? '');
  late final _obs = TextEditingController(text: widget.fornecedor?.observacoes ?? '');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_nome, _empresa, _tel, _email, _end, _obs]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _n(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _guardar() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<SupplierProvider>().salvar(Fornecedor(
            id: widget.fornecedor?.id,
            nome: _nome.text.trim(),
            empresa: _n(_empresa),
            telefone: _n(_tel),
            email: _n(_email),
            endereco: _n(_end),
            observacoes: _n(_obs),
            dataCadastro: widget.fornecedor?.dataCadastro ?? DateTime.now(),
          ));
      if (mounted) {
        showSnack(context, 'Fornecedor guardado.');
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
      appBar: AppBar(title: Text(widget.fornecedor == null ? 'Novo fornecedor' : 'Editar fornecedor')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            TextFormField(
              controller: _nome,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome do fornecedor *'),
              validator: (v) => Validators.required(v, 'Indique o nome do fornecedor'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _empresa,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome da empresa'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contacto'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: Validators.email,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _end,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Endereço'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _obs,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Observações'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _guardar,
              icon: const Icon(Icons.check),
              label: const Text('Guardar fornecedor'),
            ),
          ],
        ),
      ),
    );
  }
}
