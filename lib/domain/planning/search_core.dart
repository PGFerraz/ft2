import 'dart:math' as math;

import '../entities.dart';
import 'problem.dart';

/// Tipo da última tarefa alocada, codificado como inteiro (-1 = nenhuma).
int typeCode(TaskType type) => type.index;
const int kNoType = -1;

/// h(n) = Σ w·max(0, t + d − p) para as unidades restantes (Seção 3.5).
///
/// Relaxação: cada unidade restante começaria exatamente em t, ignorando as
/// demais e os compromissos fixos. Como nenhuma agenda real termina uma
/// unidade antes disso e as parcelas α e β são não negativas, h é admissível.
double heuristic(PlanningProblem problem, int mask, int t) {
  var estimate = 0.0;
  for (var i = 0; i < problem.unitCount; i++) {
    if (mask & (1 << i) == 0) continue;
    final u = problem.units[i];
    final overdue = t + u.durationSlots - u.deadlineSlot;
    if (overdue > 0) estimate += u.weight * overdue;
  }
  return estimate;
}

/// Custo de passo c = w·atraso + α·troca + β·fora_da_preferência (Seção 3.4).
double stepCost(PlanningProblem problem, PlanUnit unit, int start, int lastType) {
  final end = start + unit.durationSlots;
  final tardiness = math.max(0, end - unit.deadlineSlot);
  final change = lastType != kNoType && lastType != typeCode(unit.type) ? 1 : 0;
  final offPeak = unit.preferPeak && !problem.peak[start] ? 1 : 0;
  return unit.weight * tardiness + problem.alpha * change + problem.beta * offPeak;
}

/// Resultado do fechamento: unidades que não cabem mais a partir de t.
class Closure {
  const Closure(this.mask, this.droppedMask, this.penalty);

  /// Unidades restantes que ainda cabem no horizonte.
  final int mask;

  /// Unidades marcadas como não alocadas neste passo.
  final int droppedMask;
  final double penalty;
}

/// Marca como não alocadas as unidades que já não cabem a partir de t.
///
/// Como t só cresce ao longo de um caminho, uma unidade que não cabe a partir
/// de t nunca mais caberá; decidir isso imediatamente não altera a solução
/// ótima e reduz o fator de ramificação. É a forma operacional do teste de
/// objetivo do Bloco 2 ("se o horizonte se esgotar, tarefas restantes
/// marcadas como não alocadas com penalidade elevada").
Closure close(PlanningProblem problem, int mask, int t) {
  var remaining = mask;
  var dropped = 0;
  var penalty = 0.0;
  for (var i = 0; i < problem.unitCount; i++) {
    final bit = 1 << i;
    if (mask & bit == 0) continue;
    final u = problem.units[i];
    if (problem.earliestStart(t, u.durationSlots) < 0) {
      remaining &= ~bit;
      dropped |= bit;
      penalty += problem.unscheduledPenalty(u);
    }
  }
  return Closure(remaining, dropped, penalty);
}

/// Transição: aloca a unidade [unitIndex] no primeiro intervalo livre a partir
/// de t e aplica o fechamento ao novo estado.
class Transition {
  const Transition({
    required this.unitIndex,
    required this.start,
    required this.nextT,
    required this.nextMask,
    required this.droppedMask,
    required this.cost,
    required this.nextLastType,
  });

  final int unitIndex;
  final int start;
  final int nextT;
  final int nextMask;
  final int droppedMask;

  /// Custo de passo mais a penalidade das unidades descartadas.
  final double cost;
  final int nextLastType;
}

/// Gera a transição para [unitIndex]. Devolve null se a unidade não cabe
/// (o que não acontece em estados já fechados).
Transition? transition(
  PlanningProblem problem,
  int mask,
  int t,
  int lastType,
  int unitIndex,
) {
  final unit = problem.units[unitIndex];
  final start = problem.earliestStart(t, unit.durationSlots);
  if (start < 0) return null;
  final cost = stepCost(problem, unit, start, lastType);
  final nextT = start + unit.durationSlots + unit.pauseAfterSlots;
  final closure = close(problem, mask & ~(1 << unitIndex), nextT);
  return Transition(
    unitIndex: unitIndex,
    start: start,
    nextT: nextT,
    nextMask: closure.mask,
    droppedMask: closure.droppedMask,
    cost: cost + closure.penalty,
    nextLastType: typeCode(unit.type),
  );
}

/// Agenda produzida por uma estratégia, em slots.
class SearchResult {
  const SearchResult({
    required this.algorithm,
    required this.order,
    required this.starts,
    required this.cost,
    required this.expanded,
    required this.generated,
    required this.elapsed,
    required this.optimal,
    this.hitNodeLimit = false,
    this.fellBackToGreedy = false,
  });

  final Algorithm algorithm;

  /// Unidades na ordem em que foram alocadas.
  final List<int> order;

  /// starts[i] é o slot inicial da unidade i, ou -1 se ela não foi alocada.
  final List<int> starts;
  final double cost;
  final int expanded;
  final int generated;
  final Duration elapsed;

  /// Verdadeiro quando há garantia de custo mínimo (A* concluído).
  final bool optimal;
  final bool hitNodeLimit;
  final bool fellBackToGreedy;

  int get scheduledCount => starts.where((s) => s >= 0).length;

  List<int> get unscheduled => [
        for (var i = 0; i < starts.length; i++)
          if (starts[i] < 0) i,
      ];

  /// Atraso total (sem peso), em slots, das unidades alocadas.
  int tardinessSlots(PlanningProblem problem) {
    var total = 0;
    for (var i = 0; i < starts.length; i++) {
      if (starts[i] < 0) continue;
      final u = problem.units[i];
      total += math.max(0, starts[i] + u.durationSlots - u.deadlineSlot);
    }
    return total;
  }

  SearchResult copyWith({
    Algorithm? algorithm,
    Duration? elapsed,
    int? expanded,
    int? generated,
    bool? optimal,
    bool? hitNodeLimit,
    bool? fellBackToGreedy,
  }) {
    return SearchResult(
      algorithm: algorithm ?? this.algorithm,
      order: order,
      starts: starts,
      cost: cost,
      expanded: expanded ?? this.expanded,
      generated: generated ?? this.generated,
      elapsed: elapsed ?? this.elapsed,
      optimal: optimal ?? this.optimal,
      hitNodeLimit: hitNodeLimit ?? this.hitNodeLimit,
      fellBackToGreedy: fellBackToGreedy ?? this.fellBackToGreedy,
    );
  }
}

/// Simula uma ordem de alocação e devolve os inícios e o custo total.
///
/// Usada para conferir, nos testes, que o custo informado por cada estratégia
/// corresponde de fato à agenda que ela devolveu.
({List<int> starts, double cost}) evaluateOrder(
    PlanningProblem problem, List<int> order) {
  final starts = List<int>.filled(problem.unitCount, -1);
  final root = close(problem, problem.fullMask, 0);
  var mask = root.mask;
  var cost = root.penalty;
  var t = 0;
  var last = kNoType;
  for (final i in order) {
    if (mask & (1 << i) == 0) continue;
    final tr = transition(problem, mask, t, last, i)!;
    starts[i] = tr.start;
    cost += tr.cost;
    mask = tr.nextMask;
    t = tr.nextT;
    last = tr.nextLastType;
  }
  for (var i = 0; i < problem.unitCount; i++) {
    if (mask & (1 << i) != 0) {
      throw StateError('A ordem informada não aloca a unidade $i.');
    }
  }
  return (starts: starts, cost: cost);
}
