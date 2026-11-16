import 'dart:math' as math;

import 'package:agenda_ia/domain/planning/astar.dart';
import 'package:agenda_ia/domain/planning/greedy.dart';
import 'package:agenda_ia/domain/planning/instance_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Teste de desempenho (Tabela 10): tempo de geração para 5, 8, 10 e 12
/// tarefas. RNF01 exige menos de 2 s para 10 tarefas.
void main() {
  for (final n in [5, 8, 10, 12]) {
    test('A* com $n tarefas termina dentro do limite de tempo', () {
      final random = math.Random(1000 + n);
      var worst = Duration.zero;
      for (var k = 0; k < 10; k++) {
        // Horizonte de dois dias de trabalho para caber até 12 tarefas.
        final p = randomProblem(random, units: n, horizon: 120);
        final greedy = greedySearch(p);
        final watch = Stopwatch()..start();
        final r = aStarSearch(p, greedy: greedy);
        watch.stop();
        if (watch.elapsed > worst) worst = watch.elapsed;
        expect(r.cost, lessThanOrEqualTo(greedy.cost + 1e-9));
      }
      // ignore: avoid_print
      print('n = $n: pior tempo do A* em 10 instâncias = ${worst.inMilliseconds} ms');
      if (n <= 10) expect(worst, lessThan(const Duration(seconds: 2)));
    });
  }
}
