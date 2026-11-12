import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/configuracao.dart';
import '../services/config_service.dart';

/// Configurações do estabelecimento e tema da aplicação.
class ConfigProvider extends ChangeNotifier {
  final _service = ConfigService();

  Configuracao config = const Configuracao();
  ThemeMode themeMode = ThemeMode.system;

  static ThemeMode _parse(String t) {
    switch (t) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> load() async {
    config = await _service.obter();
    final prefs = await SharedPreferences.getInstance();
    themeMode = _parse(prefs.getString('tema') ?? config.tema);
    notifyListeners();
  }

  Future<void> salvar(Configuracao nova) async {
    await _service.guardar(nova);
    config = nova;
    notifyListeners();
  }

  Future<void> setTema(String tema) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tema', tema);
    themeMode = _parse(tema);
    await salvar(config.copyWith(tema: tema));
  }
}
