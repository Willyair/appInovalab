/// Lógica de risco PURA (sem base de dados), para ser fácil de testar.
/// Segue o documento "Análise e Gestão de Risco de Crédito" (§7 e §8).
/// Todos os números aqui são PROPOSTAS a validar com a MZN.
library;

enum NivelRisco { baixo, moderado, elevado }

String rotuloNivel(NivelRisco n) => switch (n) {
      NivelRisco.baixo => 'Risco baixo',
      NivelRisco.moderado => 'Risco moderado',
      NivelRisco.elevado => 'Risco elevado',
    };

/// Limiares lidos da tabela `configuracoes`.
class ParametrosRisco {
  final int limiarBaixo;
  final int limiarModerado;
  final int capacidadeMinimaParaBaixo;

  const ParametrosRisco({
    this.limiarBaixo = 75,
    this.limiarModerado = 50,
    this.capacidadeMinimaParaBaixo = 12,
  });
}

/// Pontuação por dimensão (§8): 20 + 20 + 25 + 15 + 10 + 10 = 100.
class Pontuacao {
  final int documentacao;
  final int negocio;
  final int capacidade;
  final int historico;
  final int finalidade;
  final int comunitaria;

  const Pontuacao({
    this.documentacao = 0,
    this.negocio = 0,
    this.capacidade = 0,
    this.historico = 0,
    this.finalidade = 0,
    this.comunitaria = 0,
  });

  static const maximos = <String, int>{
    'documentacao': 20,
    'negocio': 20,
    'capacidade': 25,
    'historico': 15,
    'finalidade': 10,
    'comunitaria': 10,
  };

  static const rotulos = <String, String>{
    'documentacao': 'Documentação e identificação',
    'negocio': 'Existência e estabilidade do negócio',
    'capacidade': 'Capacidade de pagamento',
    'historico': 'Histórico financeiro',
    'finalidade': 'Finalidade e viabilidade do investimento',
    'comunitaria': 'Verificação comunitária e consistência',
  };

  int get total =>
      documentacao + negocio + capacidade + historico + finalidade + comunitaria;

  int valor(String chave) => switch (chave) {
        'documentacao' => documentacao,
        'negocio' => negocio,
        'capacidade' => capacidade,
        'historico' => historico,
        'finalidade' => finalidade,
        'comunitaria' => comunitaria,
        _ => throw ArgumentError('Dimensão desconhecida: $chave'),
      };

  Pontuacao com(String chave, int v) => Pontuacao(
        documentacao: chave == 'documentacao' ? v : documentacao,
        negocio: chave == 'negocio' ? v : negocio,
        capacidade: chave == 'capacidade' ? v : capacidade,
        historico: chave == 'historico' ? v : historico,
        finalidade: chave == 'finalidade' ? v : finalidade,
        comunitaria: chave == 'comunitaria' ? v : comunitaria,
      );

  /// Devolve a primeira dimensão fora dos limites, ou null se estiver tudo bem.
  String? dimensaoInvalida() {
    for (final e in maximos.entries) {
      final v = valor(e.key);
      if (v < 0 || v > e.value) return e.key;
    }
    return null;
  }
}

class ResultadoClassificacao {
  final NivelRisco nivel;
  final int total;

  /// Razões que justificam a classificação (o documento exige que a
  /// classificação venha sempre acompanhada dos fatores).
  final List<String> fatores;

  const ResultadoClassificacao(this.nivel, this.total, this.fatores);
}

class RiscoService {
  /// Documentos sem os quais não há análise possível (PROPOSTA a validar).
  static const documentosEssenciais = {'identificacao', 'prova_negocio'};

  /// Sobra mensal depois de custos e outras dívidas.
  static double excedenteMensal({
    required double vendas,
    required double custos,
    required double outrasDividas,
  }) =>
      vendas - custos - outrasDividas;

  /// Quantas vezes o excedente cobre a prestação. Null se não há prestação.
  static double? cobertura({
    required double vendas,
    required double custos,
    required double outrasDividas,
    required double prestacao,
  }) {
    if (prestacao <= 0) return null;
    return excedenteMensal(
          vendas: vendas,
          custos: custos,
          outrasDividas: outrasDividas,
        ) /
        prestacao;
  }

  /// Sugestão (0–25) para "capacidade de pagamento", a partir da cobertura.
  /// O técnico pode alterar; é só ponto de partida.
  static int sugerirCapacidade(double? cobertura) {
    if (cobertura == null) return 0;
    if (cobertura >= 2) return 25;
    if (cobertura >= 1.5) return 20;
    if (cobertura >= 1.25) return 15;
    if (cobertura >= 1) return 10;
    if (cobertura >= 0.75) return 5;
    return 0;
  }

  /// Prestação mensal simples (sem juros). Os juros são definidos pela MZN.
  static double prestacaoSimples(double valor, int prazoMeses) =>
      prazoMeses <= 0 ? 0 : valor / prazoMeses;

  static int _ordem(NivelRisco n) => n.index;
  static NivelRisco _pior(NivelRisco a, NivelRisco b) =>
      _ordem(a) >= _ordem(b) ? a : b;

  /// Classifica segundo o §7:
  /// - Baixo: pontuação alta, capacidade compatível, sem lacunas nem sinais.
  /// - Moderado: lacunas corrigíveis (documentos não essenciais, sinais leves,
  ///   capacidade abaixo do mínimo para "baixo").
  /// - Elevado: pontuação baixa, documento essencial em falta ou sinal grave.
  static ResultadoClassificacao classificar({
    required Pontuacao pontuacao,
    required ParametrosRisco parametros,
    List<String> sinaisGraves = const [],
    List<String> sinaisLeves = const [],
    List<String> documentosEssenciaisEmFalta = const [],
    List<String> documentosObrigatoriosEmFalta = const [],
  }) {
    final total = pontuacao.total;
    final fatores = <String>[];

    var nivel = NivelRisco.elevado;
    if (total >= parametros.limiarBaixo) {
      nivel = NivelRisco.baixo;
    } else if (total >= parametros.limiarModerado) {
      nivel = NivelRisco.moderado;
    }
    fatores.add(
      'Pontuação total $total/100 (baixo a partir de ${parametros.limiarBaixo}, '
      'moderado a partir de ${parametros.limiarModerado}).',
    );

    if (nivel == NivelRisco.baixo &&
        pontuacao.capacidade < parametros.capacidadeMinimaParaBaixo) {
      nivel = NivelRisco.moderado;
      fatores.add(
        'Capacidade de pagamento (${pontuacao.capacidade}/25) abaixo do mínimo '
        '(${parametros.capacidadeMinimaParaBaixo}) exigido para risco baixo.',
      );
    }

    if (documentosObrigatoriosEmFalta.isNotEmpty) {
      nivel = _pior(nivel, NivelRisco.moderado);
      fatores.add(
        'Documentos obrigatórios em falta: ${documentosObrigatoriosEmFalta.join(', ')}.',
      );
    }
    if (documentosEssenciaisEmFalta.isNotEmpty) {
      nivel = NivelRisco.elevado;
      fatores.add(
        'Documentação essencial em falta: ${documentosEssenciaisEmFalta.join(', ')}.',
      );
    }
    if (sinaisLeves.isNotEmpty) {
      nivel = _pior(nivel, NivelRisco.moderado);
      fatores.add('Sinais de alerta: ${sinaisLeves.join('; ')}.');
    }
    if (sinaisGraves.isNotEmpty) {
      nivel = NivelRisco.elevado;
      fatores.add('Sinais de alerta graves: ${sinaisGraves.join('; ')}.');
    }

    return ResultadoClassificacao(nivel, total, fatores);
  }
}
