import 'dart:math' as math;

import 'package:agenda_ia/domain/planning/astar.dart';
import 'package:agenda_ia/domain/planning/exhaustive.dart';
import 'package:agenda_ia/domain/planning/greedy.dart';
import 'package:agenda_ia/domain/planning/instance_generator.dart';
import 'package:agenda_ia/domain/planning/problem.dart';
import 'package:agenda_ia/domain/planning/search_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testes de admissibilidade e otimalidade da Tabela 10 do Bloco 2:
/// 100 instâncias aleatórias com até 7 tarefas, comparadas com a busca
/// exaustiva.
const _instances = 100;
const _seed = 20261111;
const _eps = 1e-9;

/// Percorre estados alcançáveis a partir da raiz (passeio aleatório) e
/// devolve-os para conferência de h.
List<({int mask, int t, int last, double g})> _sampleStates(
    PlanningProblem p, math.Random random) {
  final states = <({int mask, int t, int last, double g})>[];
  final root = close(p, p.fullMask, 0);
  var mask = root.mask;
  var t = 0;
  var last = kNoType;
  var g = root.penalty;
  states.add((mask: mask, t: t, last: last, g: g));
  while (mask != 0) {
    final options = [
      for (var i = 0; i < p.unitCount; i++)
        if (mask & (1 << i) != 0) i,
    ];
    final tr = transition(p, mask, t, last, options[random.nextInt(options.length)])!;
    mask = tr.nextMask;
    t = tr.nextT;
    last = tr.nextLastType;
    g += tr.cost;
    states.add((mask: mask, t: t, last: last, g: g));
  }
  return states;
}

void main() {
  test('h(n) nunca supera o custo ótimo restante ($_instances instâncias, até 7 tarefas)', () {
    final random = math.Random(_seed);
    var checked = 0;
    for (var k = 0; k < _instances; k++) {
      final p = randomProblem(random, units: 1 + random.nextInt(7));
      for (final s in _sampleStates(p, random)) {
        final exact = exhaustiveFrom(p, s.mask, s.t, s.last).cost;
        final h = heuristic(p, s.mask, s.t);
        expect(h, lessThanOrEqualTo(exact + _eps),
            reason: 'instância $k: h = $h > h* = $exact');
        checked++;
      }
    }
    expect(checked, greaterThan(_instances));
  });

  test('h é consistente: h(n) ≤ c(n, n\') + h(n\') em todas as arestas', () {
    final random = math.Random(_seed + 1);
    for (var k = 0; k < _instances; k++) {
      final p = randomProblem(random, units: 1 + random.nextInt(7));
      for (final s in _sampleStates(p, random)) {
        final h = heuristic(p, s.mask, s.t);
        for (var i = 0; i < p.unitCount; i++) {
          if (s.mask & (1 << i) == 0) continue;
          final tr = transition(p, s.mask, s.t, s.last, i)!;
          final hNext = heuristic(p, tr.nextMask, tr.nextT);
          expect(h, lessThanOrEqualTo(tr.cost + hNext + _eps));
        }
      }
    }
  });

  test('A* devolve o mesmo custo da busca exaustiva e nunca pior que a gulosa', () {
    final random = math.Random(_seed + 2);
    var greedyWorse = 0;
    for (var k = 0; k < _instances; k++) {
      final p = randomProblem(random, units: 1 + random.nextInt(7));
      final exact = exhaustiveSearch(p);
      final greedy = greedySearch(p);
      final astar = aStarSearch(p, greedy: greedy);

      expect(astar.optimal, isTrue);
      expect(astar.cost, closeTo(exact.cost, 1e-6), reason: 'instância $k');
      expect(greedy.cost, greaterThanOrEqualTo(exact.cost - 1e-6));
      expect(evaluateOrder(p, astar.order).cost, closeTo(astar.cost, 1e-6));
      expect(evaluateOrder(p, greedy.order).cost, closeTo(greedy.cost, 1e-6));
      if (greedy.cost > exact.cost + 1e-6) greedyWorse++;
    }
    // Registro informativo para o relatório do Bloco 3.
    // ignore: avoid_print
    print('Gulosa acima do ótimo em $greedyWorse de $_instances instâncias.');
  });

  test('a poda por dominância não altera o ótimo com α e β altos', () {
    final random = math.Random(_seed + 3);
    for (var k = 0; k < 40; k++) {
      final p = randomProblem(random, units: 2 + random.nextInt(6), alpha: 5, beta: 4);
      expect(aStarSearch(p).cost, closeTo(exhaustiveSearch(p).cost, 1e-6),
          reason: 'instância $k');
    }
  });
}
