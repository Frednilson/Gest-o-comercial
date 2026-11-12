import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import '../core/utils/app_exception.dart';
import '../providers/config_provider.dart';
import '../providers/people_providers.dart';
import '../providers/product_provider.dart';
import 'routes.dart';

/// Abre a base de dados, carrega as configurações e os dados iniciais.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _erro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciar());
  }

  Future<void> _iniciar() async {
    setState(() => _erro = null);
    final config = context.read<ConfigProvider>();
    final produtos = context.read<ProductProvider>();
    final clientes = context.read<CustomerProvider>();
    final fornecedores = context.read<SupplierProvider>();
    final despesas = context.read<ExpenseProvider>();
    final navigator = Navigator.of(context);
    try {
      await DatabaseHelper.instance.database;
      await config.load();
      await Future.wait([
        produtos.load(),
        clientes.load(),
        fornecedores.load(),
        despesas.load(),
        Future<void>.delayed(const Duration(milliseconds: 900)),
      ]);
      if (!mounted) return;
      navigator.pushReplacementNamed(AppRoutes.home);
    } catch (e) {
      if (mounted) setState(() => _erro = errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(offset: Offset(0, 14 * (1 - value)), child: child),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Icon(Icons.storefront_rounded, size: 50, color: cs.onPrimary),
              ),
              const SizedBox(height: 22),
              const Text(AppConstants.appName,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Gestão simples para o seu negócio',
                  style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 32),
              if (_erro == null)
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(_erro!, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _iniciar, child: const Text('Tentar novamente')),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
