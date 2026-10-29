import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/estatisticas.dart';
import 'comum.dart';

class GraficoPessoal extends StatelessWidget {
  final EstatisticasPessoais dados;
  const GraficoPessoal({super.key, required this.dados});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CartaoIndicador(
          itens: [
            _Indicador('Valor concedido', formatarMzn(dados.valorConcedido)),
            _Indicador('Estado', dados.estadoCredito),
          ],
        ),
        const SizedBox(height: 16),
        Text('Pagamentos', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: dados.totalPrevisto == 0
              ? const _SemDados()
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, meta) => Text(
                            v == 0 ? 'Previsto' : 'Pago',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: [
                      BarChartGroupData(x: 0, barRods: [
                        BarChartRodData(toY: dados.totalPrevisto, color: cor.withOpacity(0.4), width: 28),
                      ]),
                      BarChartGroupData(x: 1, barRods: [
                        BarChartRodData(toY: dados.totalPago, color: cor, width: 28),
                      ]),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 20),
        Text('O crescimento do seu negócio', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: dados.vendasPorMes.isEmpty
              ? const _SemDados()
              : _LinhaVendas(pontos: dados.vendasPorMes, cor: cor),
        ),
      ],
    );
  }
}

class GraficoAgregado extends StatelessWidget {
  final EstatisticasAgregadas dados;
  const GraficoAgregado({super.key, required this.dados});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    final risco = dados.distribuicaoRisco;
    final totalRisco = risco.values.fold<int>(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CartaoIndicador(
          itens: [
            _Indicador('Mamanas apoiadas', '${dados.numeroMamanasApoiadas}'),
            _Indicador('Valor concedido', formatarMzn(dados.valorTotalConcedido)),
          ],
        ),
        const SizedBox(height: 16),
        Text('Pagamentos (todas as Mamanas)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: (dados.pagamentosEmDia + dados.pagamentosAtrasados) == 0
              ? const _SemDados()
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, meta) => Text(
                            v == 0 ? 'Em dia' : 'Atrasados',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: [
                      BarChartGroupData(x: 0, barRods: [
                        BarChartRodData(
                          toY: dados.pagamentosEmDia.toDouble(), color: cor, width: 28),
                      ]),
                      BarChartGroupData(x: 1, barRods: [
                        BarChartRodData(
                          toY: dados.pagamentosAtrasados.toDouble(),
                          color: Theme.of(context).colorScheme.error,
                          width: 28,
                        ),
                      ]),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 20),
        Text('Distribuição de risco', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (totalRisco == 0)
          const _SemDados()
        else
          Row(
            children: [
              SizedBox(
                height: 100,
                width: 100,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 24,
                    sections: [
                      PieChartSectionData(
                        value: (risco['baixo'] ?? 0).toDouble(),
                        color: Colors.green,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: (risco['moderado'] ?? 0).toDouble(),
                        color: Colors.orange,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: (risco['elevado'] ?? 0).toDouble(),
                        color: Colors.red,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendaRisco(cor: Colors.green, rotulo: 'Baixo', n: risco['baixo'] ?? 0),
                    _LegendaRisco(cor: Colors.orange, rotulo: 'Moderado', n: risco['moderado'] ?? 0),
                    _LegendaRisco(cor: Colors.red, rotulo: 'Elevado', n: risco['elevado'] ?? 0),
                  ],
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),
        Text('Crescimento médio dos negócios', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: dados.crescimentoMedioNegocios.isEmpty
              ? const _SemDados()
              : _LinhaVendas(pontos: dados.crescimentoMedioNegocios, cor: cor),
        ),
      ],
    );
  }
}

class _LinhaVendas extends StatelessWidget {
  final List<PontoMensal> pontos;
  final Color cor;
  const _LinhaVendas({required this.pontos, required this.cor});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1, // sem isto o fl_chart pode pedir 0.5, 1.5… e repetir o mês
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= pontos.length) return const SizedBox.shrink();
                return Text(pontos[i].rotulo, style: const TextStyle(fontSize: 11));
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < pontos.length; i++) FlSpot(i.toDouble(), pontos[i].valor),
            ],
            isCurved: true,
            color: cor,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: cor.withOpacity(0.12)),
          ),
        ],
      ),
    );
  }
}

class _Indicador {
  final String rotulo;
  final String valor;
  _Indicador(this.rotulo, this.valor);
}

class _CartaoIndicador extends StatelessWidget {
  final List<_Indicador> itens;
  const _CartaoIndicador({required this.itens});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: itens
          .map((it) => Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.rotulo, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(it.valor,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _LegendaRisco extends StatelessWidget {
  final Color cor;
  final String rotulo;
  final int n;
  const _LegendaRisco({required this.cor, required this.rotulo, required this.n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('$rotulo: $n'),
        ],
      ),
    );
  }
}

class _SemDados extends StatelessWidget {
  const _SemDados();
  @override
  Widget build(BuildContext context) => Center(
        child: Text('Ainda sem dados suficientes.', style: Theme.of(context).textTheme.bodySmall),
      );
}
