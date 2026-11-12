import 'package:flutter/foundation.dart';

/// Barramento de actualização: qualquer alteração aos dados chama [bump] e
/// todos os ecrãs/providers que dependem da base de dados recarregam.
class AppData extends ChangeNotifier {
  int _version = 0;
  int get version => _version;

  void bump() {
    _version++;
    notifyListeners();
  }
}
