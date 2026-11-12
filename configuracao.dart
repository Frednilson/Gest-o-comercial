class Configuracao {
  const Configuracao({
    this.nomeEstabelecimento = 'O Meu Estabelecimento',
    this.logotipo,
    this.endereco,
    this.telefone,
    this.moeda = 'MZN',
    this.tema = 'system',
    this.rodapeRecibo = 'Obrigado pela preferência!',
  });

  final String nomeEstabelecimento;
  final String? logotipo;
  final String? endereco;
  final String? telefone;
  final String moeda;

  /// system | light | dark
  final String tema;
  final String? rodapeRecibo;

  factory Configuracao.fromMap(Map<String, Object?> m) => Configuracao(
        nomeEstabelecimento: (m['nome_estabelecimento'] as String?) ?? 'O Meu Estabelecimento',
        logotipo: m['logotipo'] as String?,
        endereco: m['endereco'] as String?,
        telefone: m['telefone'] as String?,
        moeda: (m['moeda'] as String?) ?? 'MZN',
        tema: (m['tema'] as String?) ?? 'system',
        rodapeRecibo: m['rodape_recibo'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': 1,
        'nome_estabelecimento': nomeEstabelecimento,
        'logotipo': logotipo,
        'endereco': endereco,
        'telefone': telefone,
        'moeda': moeda,
        'tema': tema,
        'rodape_recibo': rodapeRecibo,
      };

  Configuracao copyWith({
    String? nomeEstabelecimento,
    Object? logotipo = _keep,
    String? endereco,
    String? telefone,
    String? tema,
    String? rodapeRecibo,
  }) =>
      Configuracao(
        nomeEstabelecimento: nomeEstabelecimento ?? this.nomeEstabelecimento,
        logotipo: identical(logotipo, _keep) ? this.logotipo : logotipo as String?,
        endereco: endereco ?? this.endereco,
        telefone: telefone ?? this.telefone,
        moeda: moeda,
        tema: tema ?? this.tema,
        rodapeRecibo: rodapeRecibo ?? this.rodapeRecibo,
      );
}

const Object _keep = Object();
