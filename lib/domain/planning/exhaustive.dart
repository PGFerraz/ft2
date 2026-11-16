import 'problem.dart';
import 'search_core.dart';

/// Busca exaustiva em profundidade sobre o mesmo modelo de transição do A*.
///
/// Não é usada pelo aplicativo: serve de referência nos testes de
/// admissibilidade e de otimalidade (Tabela 10 do Bloco 2), em instâncias de
/// até 7 unidades (no máximo 7! = 5040 ordens).
class ExhaustiveResult {
  const ExhaustiveResult(this.cost, this.order, this.leaves);
  final double cost;
  final List<int> order;
  final int leaves;
}

/// Custo ótimo para completar a agenda a partir do estado (mask, t, last).
ExhaustiveResult exhaustiveFrom(
  PlanningProblem problem,
  int mask,
  int t,
  int lastType,
) {
  var bestCost = double.infinity;
  var bestOrder = <int>[];
  var leaves = 0;
  final path = <int>[];

  void dfs(int mask, int t, int last, double g) {
    if (mask == 0) {
      leaves++;
      if (g < bestCost) {
        bestCost = g;
        bestOrder = List.of(path);
      }
      return;
    }
    for (var i = 0; i < problem.unitCount; i++) {
      if (mask & (1 << i) == 0) continue;
      final tr = transition(problem, mask, t, last, i);
      if (tr == null) continue;
      path.add(i);
      dfs(tr.nextMask, tr.nextT, tr.nextLastType, g + tr.cost);
      path.removeLast();
    }
  }

  dfs(mask, t, lastType, 0);
  return ExhaustiveResult(bestCost, bestOrder, leaves);
}

/// Custo ótimo do problema completo, a partir do estado inicial.
ExhaustiveResult exhaustiveSearch(PlanningProblem problem) {
  final root = close(problem, problem.fullMask, 0);
  final rest = exhaustiveFrom(problem, root.mask, 0, kNoType);
  return ExhaustiveResult(rest.cost + root.penalty, rest.order, rest.leaves);
}
