import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/products/screens/product_list_screen.dart';
import '../features/sales/screens/new_sale_screen.dart';
import '../features/stock/screens/stock_screen.dart';
import '../providers/cart_provider.dart';
import 'more_screen.dart';

/// Navegação inferior: Início, Produtos, Vendas, Stock e Mais.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(onGoTo: _go),
      const ProductListScreen(),
      const NewSaleScreen(),
      const StockScreen(),
      const MoreScreen(),
    ];
    final cartCount = context.select<CartProvider, int>((c) => c.totalUnidades);

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: IndexedStack(index: _index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Início',
            ),
            const NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Produtos',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: cartCount > 0,
                label: Text('$cartCount'),
                child: const Icon(Icons.point_of_sale_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: cartCount > 0,
                label: Text('$cartCount'),
                child: const Icon(Icons.point_of_sale),
              ),
              label: 'Vendas',
            ),
            const NavigationDestination(
              icon: Icon(Icons.warehouse_outlined),
              selectedIcon: Icon(Icons.warehouse),
              label: 'Stock',
            ),
            const NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Mais',
            ),
          ],
        ),
      ),
    );
  }
}
