/// Constantes globais da aplicação.
class AppConstants {
  AppConstants._();

  static const appName = 'Gestão Comercial';
  static const appVersion = '1.0.0';
  static const currency = 'MZN';

  static const expenseCategories = <String>[
    'Transporte',
    'Energia',
    'Água',
    'Renda',
    'Salários',
    'Manutenção',
    'Comunicação',
    'Outras',
  ];

  /// chave interna -> nome apresentado
  static const paymentMethods = <String, String>{
    'dinheiro': 'Dinheiro',
    'mpesa': 'M-Pesa',
    'emola': 'e-Mola',
    'transferencia': 'Transferência bancária',
  };

  static String paymentLabel(String key) => paymentMethods[key] ?? key;

  /// chave interna -> nome apresentado
  static const movementTypes = <String, String>{
    'entrada': 'Entrada',
    'saida': 'Saída',
    'venda': 'Venda',
    'devolucao': 'Devolução',
    'ajuste': 'Ajuste de stock',
  };

  static String movementLabel(String key) => movementTypes[key] ?? key;

  /// Tipos que o utilizador pode registar manualmente no ecrã de stock.
  static const manualMovementTypes = <String>['entrada', 'saida', 'devolucao', 'ajuste'];
}
