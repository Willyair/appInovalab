import 'package:estudos/services/risco_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const params = ParametrosRisco();
  const boa = Pontuacao(
      documentacao: 18, negocio: 17, capacidade: 20, historico: 10, finalidade: 8, comunitaria: 8);

  test('máximos somam 100', () {
    expect(Pontuacao.maximos.values.reduce((a, b) => a + b), 100);
  });

  test('pontuação alta e sem lacunas dá risco baixo', () {
    final r = RiscoService.classificar(pontuacao: boa, parametros: params);
    expect(r.total, 81);
    expect(r.nivel, NivelRisco.baixo);
  });

  test('capacidade abaixo do mínimo impede risco baixo', () {
    const p = Pontuacao(
        documentacao: 20, negocio: 20, capacidade: 5, historico: 15, finalidade: 10, comunitaria: 10);
    expect(p.total, 80); // acima de 75, mas capacidade 5 < 12
    final r = RiscoService.classificar(pontuacao: p, parametros: params);
    expect(r.nivel, NivelRisco.moderado);
  });

  test('pontuação média dá moderado; baixa dá elevado', () {
    expect(
      RiscoService.classificar(
              pontuacao: const Pontuacao(documentacao: 15, negocio: 15, capacidade: 15, historico: 5),
              parametros: params)
          .nivel,
      NivelRisco.moderado,
    );
    expect(
      RiscoService.classificar(
              pontuacao: const Pontuacao(documentacao: 10, negocio: 10, capacidade: 10),
              parametros: params)
          .nivel,
      NivelRisco.elevado,
    );
  });

  test('sinal grave ou documento essencial em falta força elevado', () {
    expect(
      RiscoService.classificar(
              pontuacao: boa, parametros: params, sinaisGraves: ['Negócio não localizado'])
          .nivel,
      NivelRisco.elevado,
    );
    expect(
      RiscoService.classificar(
              pontuacao: boa,
              parametros: params,
              documentosEssenciaisEmFalta: ['Documento de identificação'])
          .nivel,
      NivelRisco.elevado,
    );
  });

  test('sinal leve ou documento obrigatório em falta limita a moderado', () {
    expect(
      RiscoService.classificar(
              pontuacao: boa, parametros: params, sinaisLeves: ['Finalidade pouco clara'])
          .nivel,
      NivelRisco.moderado,
    );
    expect(
      RiscoService.classificar(
              pontuacao: boa, parametros: params, documentosObrigatoriosEmFalta: ['Termo'])
          .nivel,
      NivelRisco.moderado,
    );
  });

  test('toda a classificação traz fatores', () {
    expect(RiscoService.classificar(pontuacao: boa, parametros: params).fatores, isNotEmpty);
  });

  test('capacidade sugerida pela cobertura da prestação', () {
    double cob(double v, double c, double o, double p) =>
        RiscoService.cobertura(vendas: v, custos: c, outrasDividas: o, prestacao: p)!;
    expect(RiscoService.sugerirCapacidade(cob(5000, 2000, 0, 1000)), 25); // 3.0
    expect(RiscoService.sugerirCapacidade(cob(3000, 2000, 0, 1000)), 10); // 1.0
    expect(RiscoService.sugerirCapacidade(cob(3000, 2000, 500, 1000)), 0); // 0.5
    expect(RiscoService.sugerirCapacidade(null), 0);
  });

  test('dimensão fora dos limites é detetada', () {
    expect(const Pontuacao(capacidade: 26).dimensaoInvalida(), 'capacidade');
    expect(boa.dimensaoInvalida(), isNull);
  });
}
