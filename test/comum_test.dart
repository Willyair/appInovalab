import 'package:estudos/widgets/comum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lerNumero', () {
    test('inteiros e espaços', () {
      expect(lerNumero('15000'), 15000);
      expect(lerNumero(' 15 000 '), 15000);
    });

    test('ponto como separador de milhares (o erro silencioso: "15.000" dava 15)', () {
      expect(lerNumero('15.000'), 15000);
      expect(lerNumero('1.500.000'), 1500000);
    });

    test('vírgula decimal e combinações', () {
      expect(lerNumero('1500,5'), 1500.5);
      expect(lerNumero('15.000,50'), 15000.5);
      expect(lerNumero('15,000.50'), 15000.5);
      expect(lerNumero('1,500,000'), 1500000);
    });

    test('decimais que a própria app escreve (ex.: "15000.0", "15000.50")', () {
      expect(lerNumero('15000.0'), 15000);
      expect(lerNumero('15000.50'), 15000.5);
    });

    test('lixo devolve null (antes alguns viravam 0 ou NaN)', () {
      expect(lerNumero(''), isNull);
      expect(lerNumero('abc'), isNull);
      expect(lerNumero('5000MZN'), isNull);
      expect(lerNumero('NaN'), isNull);
      expect(lerNumero('Infinity'), isNull);
    });
  });

  test('formatarMzn agrupa de três em três', () {
    expect(formatarMzn(15000), '15 000 MZN');
    expect(formatarMzn(-1500000), '-1 500 000 MZN');
  });
}
