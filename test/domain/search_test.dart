import 'package:agenda_ia/domain/entities.dart';
import 'package:agenda_ia/domain/planning/astar.dart';
import 'package:agenda_ia/domain/planning/exhaustive.dart';
import 'package:agenda_ia/domain/planning/greedy.dart';
import 'package:agenda_ia/domain/planning/problem.dart';
import 'package:agenda_ia/domain/planning/search_core.dart';
import 'package:flutter_test/flutter_test.dart';

PlanUnit _unit(
  int index, {
  required int d,
  required int p,
  int w = 1,
  TaskType type = TaskType.leve,
  bool preferPeak = false,
  int pause = 0,
}) {
  return PlanUnit(
    index: index,
    taskId: 't$index',
    title: 'T$index',
    durationSlots: d,
    deadlineSlot: p,
    weight: w,
    type: type,
    preferPeak: preferPeak,
    pauseAfterSlots: pause,
  );
}

PlanningProblem _problem(
  List<PlanUnit> units, {
  int horizon = 20,
  Set<int> blocked = const {},
  Set<int> peak = const {},
  double alpha = 1,
  double beta = 0.5,
  int nodeLimit = 100000,
}) {
  return PlanningProblem(
    units: units,
    free: [for (var s = 0; s < horizon; s++) !blocked.contains(s)],
    peak: [for (var s = 0; s < horizon; s++) peak.contains(s)],
    alpha: alpha,
    beta: beta,
    nodeLimit: nodeLimit,
  );
}

void main() {
  group('earliestStart', () {
    final p = _problem([], horizon: 10, blocked: {2, 3, 7});

    test('respeita os slots bloqueados por compromissos fixos', () {
      expect(p.earliestStart(0, 2), 0);
      expect(p.earliestStart(1, 2), 4);
      expect(p.earliestStart(0, 3), 4);
      expect(p.earliestStart(0, 4), -1);
    });

    test('devolve -1 quando a busca começa fora do horizonte', () {
      expect(p.earliestStart(10, 1), -1);
      expect(p.earliestStart(9, 2), -1);
    });
  });

  group('função de custo', () {
    final p = _problem([], peak: {0, 1, 2, 3}, alpha: 1, beta: 0.5);

    test('atraso ponderado: w × max(0, término − prazo)', () {
      final u = _unit(0, d: 4, p: 2, w: 3);
      expect(stepCost(p, u, 0, kNoType), 3 * 2);
    });

    test('troca de tipo soma α; primeira tarefa não conta troca', () {
      final u = _unit(0, d: 1, p: 10, type: TaskType.foco);
      expect(stepCost(p, u, 0, kNoType), 0);
      expect(stepCost(p, u, 0, typeCode(TaskType.leve)), 1);
      expect(stepCost(p, u, 0, typeCode(TaskType.foco)), 0);
    });

    test('tarefa que prefere o pico soma β quando começa fora dele', () {
      final u = _unit(0, d: 1, p: 10, preferPeak: true);
      expect(stepCost(p, u, 2, kNoType), 0);
      expect(stepCost(p, u, 5, kNoType), 0.5);
    });
  });

  group('heurística', () {
    test('é zero quando todas as tarefas cabem antes do prazo a partir de t', () {
      final p = _problem([_unit(0, d: 2, p: 10), _unit(1, d: 3, p: 10)]);
      expect(heuristic(p, p.fullMask, 0), 0);
    });

    test('soma w × max(0, t + d − p) só das tarefas restantes', () {
      final p = _problem([_unit(0, d: 2, p: 3, w: 2), _unit(1, d: 3, p: 4, w: 3)]);
      // t = 4: unidade 0 → 2 × (4 + 2 − 3) = 6; unidade 1 → 3 × (4 + 3 − 4) = 9.
      expect(heuristic(p, p.fullMask, 4), 15);
      expect(heuristic(p, 1 << 1, 4), 9);
    });
  });

  group('busca gulosa e A*', () {
    test('agenda vazia', () {
      final p = _problem([]);
      expect(greedySearch(p).cost, 0);
      final a = aStarSearch(p);
      expect(a.cost, 0);
      expect(a.optimal, isTrue);
    });

    test('nenhuma tarefa ocupa slot bloqueado e não há sobreposição', () {
      final p = _problem(
        [_unit(0, d: 3, p: 8), _unit(1, d: 2, p: 6, w: 3), _unit(2, d: 4, p: 20)],
        blocked: {2, 3, 9},
      );
      for (final result in [greedySearch(p), aStarSearch(p)]) {
        final used = <int>{};
        for (var i = 0; i < p.unitCount; i++) {
          final s = result.starts[i];
          expect(s, greaterThanOrEqualTo(0));
          for (var k = s; k < s + p.units[i].durationSlots; k++) {
            expect(p.free[k], isTrue, reason: 'slot $k está bloqueado');
            expect(used.add(k), isTrue, reason: 'slot $k usado duas vezes');
          }
        }
      }
    });

    test('A* encontra a ordem ótima onde a gulosa erra', () {
      // A gulosa olha só para h do estado seguinte e prefere a tarefa curta;
      // a ótima é começar pela longa de peso alto e prazo curto.
      final p = _problem([
        _unit(0, d: 1, p: 2, w: 1),
        _unit(1, d: 4, p: 4, w: 4),
        _unit(2, d: 1, p: 2, w: 1),
      ], alpha: 0, beta: 0);
      final greedy = greedySearch(p);
      final astar = aStarSearch(p);
      final exact = exhaustiveSearch(p);
      expect(astar.cost, closeTo(exact.cost, 1e-9));
      expect(astar.cost, lessThanOrEqualTo(greedy.cost));
      expect(astar.optimal, isTrue);
    });

    test('tarefa que não cabe no horizonte fica explicitamente não alocada', () {
      final p = _problem([_unit(0, d: 30, p: 5), _unit(1, d: 2, p: 5)], horizon: 20);
      for (final result in [greedySearch(p), aStarSearch(p)]) {
        expect(result.starts[0], -1);
        expect(result.starts[1], 0);
        expect(result.unscheduled, [0]);
        expect(result.cost, greaterThanOrEqualTo(p.unscheduledPenalty(p.units[0])));
      }
    });

    test('pausa depois de um bloco (R6) é respeitada', () {
      final p = _problem([
        _unit(0, d: 2, p: 20, pause: 1),
        _unit(1, d: 2, p: 20, pause: 1),
      ]);
      final r = aStarSearch(p);
      final starts = r.starts.toList()..sort();
      expect(starts[1] - starts[0], greaterThanOrEqualTo(3));
    });

    test('limite de nós devolve a melhor agenda conhecida, sem garantia de ótimo', () {
      final p = _problem([
        for (var i = 0; i < 8; i++) _unit(i, d: 1 + i % 3, p: 3 + i, w: 1 + i % 4),
      ], nodeLimit: 3);
      final r = aStarSearch(p);
      expect(r.hitNodeLimit, isTrue);
      expect(r.optimal, isFalse);
      expect(r.expanded, 3);
      expect(r.cost, lessThanOrEqualTo(greedySearch(p).cost + 1e-9));
    });

    test('o custo informado corresponde à agenda devolvida', () {
      final p = _problem([
        _unit(0, d: 3, p: 4, w: 2, type: TaskType.foco, preferPeak: true),
        _unit(1, d: 2, p: 3, w: 4),
        _unit(2, d: 4, p: 12, w: 1, type: TaskType.foco, preferPeak: true),
        _unit(3, d: 1, p: 2, w: 3),
      ], blocked: {5, 6}, peak: {0, 1, 2, 3, 4});
      for (final result in [greedySearch(p), aStarSearch(p)]) {
        final replay = evaluateOrder(p, result.order);
        expect(replay.cost, closeTo(result.cost, 1e-9));
        expect(replay.starts, result.starts);
      }
    });
  });
}
