/// Erro de negócio com mensagem pronta para apresentar ao utilizador.
class AppException implements Exception {
  AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Converte qualquer erro numa mensagem legível.
String errorMessage(Object error) {
  if (error is AppException) return error.message;
  return 'Ocorreu um erro inesperado: $error';
}
