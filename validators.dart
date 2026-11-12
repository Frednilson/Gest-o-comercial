import 'formatters.dart';

/// Validadores reutilizáveis para formulários.
class Validators {
  Validators._();

  static String? required(String? value, [String message = 'Campo obrigatório']) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  /// Valor monetário >= 0 (ou > 0 se [allowZero] for falso).
  static String? money(String? value, {bool required = true, bool allowZero = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Campo obrigatório' : null;
    }
    final v = Fmt.parseMoney(value);
    if (v == null) return 'Valor inválido';
    if (v < 0) return 'Não pode ser negativo';
    if (!allowZero && v == 0) return 'Deve ser superior a zero';
    return null;
  }

  /// Número inteiro >= 0.
  static String? integer(String? value, {bool required = true, int min = 0}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Campo obrigatório' : null;
    }
    final v = int.tryParse(value.trim());
    if (v == null) return 'Número inteiro inválido';
    if (v < min) return min == 0 ? 'Não pode ser negativo' : 'Mínimo: $min';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
    return ok ? null : 'Email inválido';
  }
}
