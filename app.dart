import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../providers/app_data.dart';
import '../providers/cart_provider.dart';
import '../providers/config_provider.dart';
import '../providers/people_providers.dart';
import '../providers/product_provider.dart';
import 'routes.dart';

class GestaoComercialApp extends StatelessWidget {
  const GestaoComercialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppData()),
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
        ChangeNotifierProvider(create: (c) => ProductProvider(c.read<AppData>())),
        ChangeNotifierProvider(create: (c) => CartProvider(c.read<AppData>())),
        ChangeNotifierProvider(create: (c) => CustomerProvider(c.read<AppData>())),
        ChangeNotifierProvider(create: (c) => SupplierProvider(c.read<AppData>())),
        ChangeNotifierProvider(create: (c) => ExpenseProvider(c.read<AppData>())),
      ],
      child: Consumer<ConfigProvider>(
        builder: (context, config, _) => MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: config.themeMode,
          locale: const Locale('pt', 'PT'),
          supportedLocales: const [Locale('pt', 'PT')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: AppRoutes.splash,
          routes: AppRoutes.routes,
        ),
      ),
    );
  }
}
