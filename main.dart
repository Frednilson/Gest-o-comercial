import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_PT');
  // A base de dados SQLite é aberta no SplashScreen (com ecrã de erro e nova tentativa).
  runApp(const GestaoComercialApp());
}
