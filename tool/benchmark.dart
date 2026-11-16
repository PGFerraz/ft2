// Experimento comparativo e de desempenho (Tabela 10 do Bloco 2).
//
// Uso:  dart run tool/benchmark.dart [instâncias por tamanho] [semente]
//
// Para cada tamanho (5, 8, 10 e 12 tarefas) gera instâncias aleatórias
// reprodutíveis, executa a busca gulosa e o A* e imprime uma tabela em
// Markdown com média e desvio-padrão de custo, tempo e nós expandidos.
//
// É um script de linha de comando: imprimir no terminal é o objetivo.
// ignore_for_file: avoid_print
import 'dart:math' as math;

import 'package:agenda_ia/domain/planning/astar.dart';
import 'package:agenda_ia/domain/planning/greedy.dart';
import 'package:agenda_ia/domain/planning/instance_generator.dart';

class _Stats {
  final List<double> values = [];
  void add(num v) => values.add(v.toDouble());
  double get mean => values.reduce((a, b) => a + b) / values.length;
  double get std {
    final m = mean;
    final variance =
        values.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) / (values.length - 1);
    return math.sqrt(variance);
  }

  double get max => values.reduce(math.max);
  String fmt([int decimals = 2]) =>
      '${mean.toStringAsFixed(decimals)} ± ${std.toStringAsFixed(decimals)}';
}

void main(List<String> args) {
  final instances = args.isNotEmpty ? int.parse(args[0]) : 100;
  final seed = args.length > 1 ? int.parse(args[1]) : 20261117;
  final sizes = [5, 8, 10, 12];

  // Aquecimento do compilador JIT para não distorcer a primeira medição.
  final warm = math.Random(1);
  for (var i = 0; i < 30; i++) {
    final p = randomProblem(warm, units: 8, horizon: 120);
    aStarSearch(p, greedy: greedySearch(p));
  }

  print('# Comparativo busca gulosa × A*\n');
  print('$instances instâncias por tamanho, semente $seed, horizonte de 2 dias '
      '(120 slots de 15 min), α = 1, β = 0,5. Valores: média ± desvio-padrão.\n');
  print('| Tarefas | Custo gulosa | Custo A* | Gulosa acima do ótimo | '
      'Excesso médio da gulosa | Tempo gulosa (ms) | Tempo A* (ms) | '
      'Pior tempo A* (ms) | Nós expandidos A* |');
  print('|---|---|---|---|---|---|---|---|---|');

  for (final n in sizes) {
    final random = math.Random(seed + n);
    final greedyCost = _Stats();
    final astarCost = _Stats();
    final greedyMs = _Stats();
    final astarMs = _Stats();
    final nodes = _Stats();
    final excess = _Stats();
    var worse = 0;
    var notOptimal = 0;

    for (var k = 0; k < instances; k++) {
      final p = randomProblem(random, units: n, horizon: 120);
      final g = greedySearch(p);
      final a = aStarSearch(p, greedy: g);
      if (!a.optimal) notOptimal++;
      greedyCost.add(g.cost);
      astarCost.add(a.cost);
      greedyMs.add(g.elapsed.inMicroseconds / 1000);
      // O tempo do A* inclui a busca gulosa usada como limite superior.
      astarMs.add(a.elapsed.inMicroseconds / 1000);
      nodes.add(a.expanded);
      if (g.cost > a.cost + 1e-9) {
        worse++;
        excess.add(a.cost == 0 ? 100 : (g.cost - a.cost) / a.cost * 100);
      }
    }

    final excessText = excess.values.isEmpty ? '—' : '${excess.mean.toStringAsFixed(1)}%';
    print('| $n | ${greedyCost.fmt(1)} | ${astarCost.fmt(1)} | '
        '$worse/$instances | $excessText | ${greedyMs.fmt(3)} | ${astarMs.fmt(2)} | '
        '${astarMs.max.toStringAsFixed(2)} | ${nodes.fmt(0)} |');
    if (notOptimal > 0) {
      print('\n> Atenção: em $notOptimal instância(s) com $n tarefas o A* atingiu o limite de nós.\n');
    }
  }

  print('\nExcesso médio da gulosa: (custo guloso − custo A*) / custo A*, calculado só '
      'nas instâncias em que a gulosa ficou acima do ótimo (100% quando o ótimo é zero).');
}
