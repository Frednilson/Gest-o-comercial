import 'package:flutter/material.dart';

import '../features/customers/screens/customers_screen.dart';
import '../features/expenses/screens/expenses_screen.dart';
import '../features/products/screens/categories_screen.dart';
import '../features/reports/screens/reports_screen.dart';
import '../features/sales/screens/sales_history_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/stock/screens/movements_screen.dart';
import '../features/suppliers/screens/suppliers_screen.dart';
import 'home_shell.dart';
import 'splash_screen.dart';

/// Rotas nomeadas dos ecrãs sem parâmetros.
/// Ecrãs com parâmetros (detalhes, formulários) são abertos com MaterialPageRoute.
class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const home = '/home';
  static const customers = '/clientes';
  static const suppliers = '/fornecedores';
  static const expenses = '/despesas';
  static const reports = '/relatorios';
  static const settings = '/configuracoes';
  static const salesHistory = '/vendas/historico';
  static const movements = '/stock/movimentacoes';
  static const categories = '/produtos/categorias';

  static final Map<String, WidgetBuilder> routes = {
    splash: (_) => const SplashScreen(),
    home: (_) => const HomeShell(),
    customers: (_) => const CustomersScreen(),
    suppliers: (_) => const SuppliersScreen(),
    expenses: (_) => const ExpensesScreen(),
    reports: (_) => const ReportsScreen(),
    settings: (_) => const SettingsScreen(),
    salesHistory: (_) => const SalesHistoryScreen(),
    movements: (_) => const MovementsScreen(),
    categories: (_) => const CategoriesScreen(),
  };
}
