/// Um ponto no tempo (ex.: vendas de um mês).
class PontoMensal {
  final String rotulo; // ex.: 'Jan', 'Fev'
  final double valor;
  const PontoMensal(this.rotulo, this.valor);
}

/// Indicadores pessoais, vistos pela própria Mamana.
class EstatisticasPessoais {
  final double valorConcedido;
  final String estadoCredito;
  final double totalPrevisto;
  final double totalPago;
  final List<PontoMensal> vendasPorMes;

  const EstatisticasPessoais({
    required this.valorConcedido,
    required this.estadoCredito,
    required this.totalPrevisto,
    required this.totalPago,
    required this.vendasPorMes,
  });
}

/// Indicadores acumulados, vistos pela MZN e pela InovaLab (sem nomes).
class EstatisticasAgregadas {
  final int numeroMamanasApoiadas;
  final double valorTotalConcedido;
  final int pagamentosEmDia;
  final int pagamentosAtrasados;
  final Map<String, int> distribuicaoRisco; // baixo / moderado / elevado
  final List<PontoMensal> crescimentoMedioNegocios;

  const EstatisticasAgregadas({
    required this.numeroMamanasApoiadas,
    required this.valorTotalConcedido,
    required this.pagamentosEmDia,
    required this.pagamentosAtrasados,
    required this.distribuicaoRisco,
    required this.crescimentoMedioNegocios,
  });
}
