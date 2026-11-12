import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/widgets/common_widgets.dart';
import '../providers/config_provider.dart';
import 'routes.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nome = context.watch<ConfigProvider>().config.nomeEstabelecimento;

    final itens = <(IconData, String, String, String)>[
      (Icons.people_alt_outlined, 'Clientes', 'Cadastro e histórico de compras', AppRoutes.customers),
      (Icons.local_shipping_outlined, 'Fornecedores', 'Contactos e histórico de fornecimento', AppRoutes.suppliers),
      (Icons.receipt_long_outlined, 'Despesas', 'Registo e controlo de despesas', AppRoutes.expenses),
      (Icons.bar_chart_rounded, 'Relatórios', 'Vendas, stock, lucro e mais (PDF)', AppRoutes.reports),
      (Icons.settings_outlined, 'Configurações', 'Estabelecimento, tema e cópias de segurança', AppRoutes.settings),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          AppCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.storefront_rounded, color: cs.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('${AppConstants.appName} v${AppConstants.appVersion}',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final i in itens)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onTap: () => Navigator.pushNamed(context, i.$4),
                child: Row(
                  children: [
                    Icon(i.$1, color: cs.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i.$2, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                          Text(i.$3, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
