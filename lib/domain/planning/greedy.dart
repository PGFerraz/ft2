import '../entities.dart';
import 'problem.dart';
import 'search_core.dart';

/// Busca gulosa (Quadro 2 do Bloco 2).
///
/// A cada passo escolhe a unidade cujo estado resultante tem o menor h, sem
/// retrocesso. Desempates: maior peso, prazo mais cedo, menor duração e, por
/// fim, a ordem de cadastro, para que o resultado seja determinístico.
SearchResult greedySearch(PlanningProblem problem) {
  final watch = Stopwatch()..start();
  final starts = List<int>.filled(problem.unitCount, -1);
  final order = <int>[];

  final root = close(problem, problem.fullMask, 0);
  var mask = root.mask;
  var cost = root.penalty;
  var t = 0;
  var last = kNoType;
  var expanded = 0;
  var generated = 0;

  while (mask != 0) {
    expanded++;
    Transition? best;
    double bestH = double.infinity;
    for (var i = 0; i < problem.unitCount; i++) {
      if (mask & (1 << i) == 0) continue;
      final tr = transition(problem, mask, t, last, i);
      if (tr == null) continue;
      generated++;
      final h = heuristic(problem, tr.nextMask, tr.nextT);
      if (best == null || _better(problem, h, i, bestH, best.unitIndex)) {
        best = tr;
        bestH = h;
      }
    }
    // Estados fechados sempre têm ao menos uma unidade que cabe.
    final chosen = best!;
    starts[chosen.unitIndex] = chosen.start;
    order.add(chosen.unitIndex);
    cost += chosen.cost;
    mask = chosen.nextMask;
    t = chosen.nextT;
    last = chosen.nextLastType;
  }

  watch.stop();
  return SearchResult(
    algorithm: Algorithm.guloso,
    order: List.unmodifiable(order),
    starts: List.unmodifiable(starts),
    cost: cost,
    expanded: expanded,
    generated: generated,
    elapsed: watch.elapsed,
    optimal: false,
  );
}

bool _better(PlanningProblem problem, double h, int i, double bestH, int b) {
  const eps = 1e-9;
  if (h < bestH - eps) return true;
  if (h > bestH + eps) return false;
  final u = problem.units[i];
  final v = problem.units[b];
  if (u.weight != v.weight) return u.weight > v.weight;
  if (u.deadlineSlot != v.deadlineSlot) return u.deadlineSlot < v.deadlineSlot;
  if (u.durationSlots != v.durationSlots) return u.durationSlots < v.durationSlots;
  return i < b;
}
