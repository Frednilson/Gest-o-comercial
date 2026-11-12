import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/cliente.dart';
import '../../../providers/people_providers.dart';
import '../../../services/pessoas_service.dart';
import '../../sales/screens/sales_history_screen.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CustomerProvider>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerFormScreen())),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Novo cliente'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchField(hint: 'Pesquisar por nome ou telefone', onChanged: p.setBusca),
          ),
          Expanded(
            child: p.clientes.isEmpty
                ? EmptyState(
                    icon: Icons.people_outline,
                    message: p.busca.isEmpty ? 'Ainda não há clientes cadastrados.' : 'Nenhum cliente encontrado.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    itemCount: p.clientes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final c = p.clientes[i];
                      return AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => CustomerDetailScreen(cliente: c))),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: cs.primaryContainer,
                              child: Text(c.nome.isEmpty ? '?' : c.nome[0].toUpperCase(),
                                  style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(c.telefone ?? 'Sem telefone',
                                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
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

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key, required this.cliente});

  final Cliente cliente;

  Future<void> _eliminar(BuildContext context) async {
    final ok = await confirmDialog(context,
        title: 'Eliminar cliente',
        message: 'Eliminar "${cliente.nome}"? Só é possível se não houver vendas associadas.',
        confirmLabel: 'Eliminar',
        destructive: true);
    if (!ok || !context.mounted) return;
    try {
      await context.read<CustomerProvider>().eliminar(cliente.id!);
      if (context.mounted) {
        Navigator.pop(context);
        showSnack(context, 'Cliente eliminado.');
      }
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cliente'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.push(
                  context, MaterialPageRoute(builder: (_) => CustomerFormScreen(cliente: cliente)));
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
      body: FutureBuilder(
        future: ClienteService().resumo(cliente.id!),
        builder: (context, snap) {
          final r = snap.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: cs.primaryContainer,
                  child: Text(cliente.nome[0].toUpperCase(),
                      style: TextStyle(fontSize: 30, color: cs.primary, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 12),
              Text(cliente.nome,
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              if (r != null)
                Row(
                  children: [
                    Expanded(
                        child: StatCard(
                            icon: Icons.shopping_bag_outlined,
                            label: '${r.numVendas} compra(s)',
                            value: Fmt.money(r.comprado),
                            color: cs.primary)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: StatCard(
                            icon: Icons.hourglass_bottom,
                            label: 'Em dívida',
                            value: Fmt.money(r.emFalta),
                            color: r.emFalta > 0 ? AppColors.error : AppColors.success)),
                  ],
                ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(
                  children: [
                    _info('Telefone', cliente.telefone ?? '-'),
                    _info('Endereço', cliente.endereco ?? '-'),
                    _info('Observações', cliente.observacoes ?? '-'),
                    _info('Cadastrado em', Fmt.date(cliente.dataCadastro)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SalesHistoryScreen(clienteId: cliente.id, titulo: 'Compras de ${cliente.nome}'),
                  ),
                ),
                icon: const Icon(Icons.history),
                label: const Text('Histórico de compras'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _info(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(a),
            const SizedBox(width: 16),
            Flexible(child: Text(b, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, this.cliente});

  final Cliente? cliente;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.cliente?.nome ?? '');
  late final _tel = TextEditingController(text: widget.cliente?.telefone ?? '');
  late final _end = TextEditingController(text: widget.cliente?.endereco ?? '');
  late final _obs = TextEditingController(text: widget.cliente?.observacoes ?? '');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_nome, _tel, _end, _obs]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _n(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _guardar() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<CustomerProvider>().salvar(Cliente(
            id: widget.cliente?.id,
            nome: _nome.text.trim(),
            telefone: _n(_tel),
            endereco: _n(_end),
            observacoes: _n(_obs),
            dataCadastro: widget.cliente?.dataCadastro ?? DateTime.now(),
          ));
      if (mounted) {
        showSnack(context, 'Cliente guardado.');
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
      appBar: AppBar(title: Text(widget.cliente == null ? 'Novo cliente' : 'Editar cliente')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            TextFormField(
              controller: _nome,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome completo *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Indique o nome do cliente' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Número de telefone'),
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
              label: const Text('Guardar cliente'),
            ),
          ],
        ),
      ),
    );
  }
}
