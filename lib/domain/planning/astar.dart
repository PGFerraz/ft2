import '../entities.dart';
import 'greedy.dart';
import 'problem.dart';
import 'search_core.dart';

const double _eps = 1e-9;

class _Node {
  _Node({
    required this.mask,
    required this.t,
    required this.g,
    required this.h,
    required this.lastType,
    required this.parent,
    required this.unitIndex,
    required this.start,
    required this.seq,
  });

  final int mask;
  final int t;
  final double g;
  final double h;
  final int lastType;
  final _Node? parent;

  /// Unidade alocada na transição que gerou este nó (-1 na raiz).
  final int unitIndex;
  final int start;
  final int seq;

  /// Nó descartado por dominância depois de ter entrado na fronteira.
  bool dead = false;

  double get f => g + h;
}

/// Fila de prioridade (heap binário) ordenada por f; empates favorecem o
/// maior g (nó mais profundo) e depois a ordem de inserção.
class _Frontier {
  final List<_Node> _heap = [];

  bool get isEmpty => _heap.isEmpty;
  int get length => _heap.length;

  static bool _less(_Node a, _Node b) {
    final df = a.f - b.f;
    if (df < -_eps) return true;
    if (df > _eps) return false;
    final dg = a.g - b.g;
    if (dg > _eps) return true;
    if (dg < -_eps) return false;
    return a.seq < b.seq;
  }

  void push(_Node node) {
    _heap.add(node);
    var i = _heap.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (!_less(_heap[i], _heap[p])) break;
      final tmp = _heap[i];
      _heap[i] = _heap[p];
      _heap[p] = tmp;
      i = p;
    }
  }

  _Node pop() {
    final top = _heap.first;
    final last = _heap.removeLast();
    if (_heap.isNotEmpty) {
      _heap[0] = last;
      var i = 0;
      while (true) {
        final l = 2 * i + 1;
        final r = l + 1;
        var m = i;
        if (l < _heap.length && _less(_heap[l], _heap[m])) m = l;
        if (r < _heap.length && _less(_heap[r], _heap[m])) m = r;
        if (m == i) break;
        final tmp = _heap[i];
        _heap[i] = _heap[m];
        _heap[m] = tmp;
        i = m;
      }
    }
    return top;
  }
}

/// Algoritmo A* aplicado ao agendamento (Quadro 1 do Bloco 2), com as três
/// medidas de contenção da Seção 3.5:
///
/// (a) poda por dominância entre estados com o mesmo conjunto de restantes;
/// (b) limite de nós expandidos, com retorno da melhor agenda conhecida;
/// (c) custo da solução gulosa como limite superior inicial.
SearchResult aStarSearch(PlanningProblem problem, {SearchResult? greedy}) {
  final watch = Stopwatch()..start();
  final incumbentGreedy = greedy ?? greedySearch(problem);

  final root = close(problem, problem.fullMask, 0);
  var seq = 0;
  final rootNode = _Node(
    mask: root.mask,
    t: 0,
    g: root.penalty,
    h: heuristic(problem, root.mask, 0),
    lastType: kNoType,
    parent: null,
    unitIndex: -1,
    start: -1,
    seq: seq++,
  );

  // Contagem de unidades que preferem o pico, por máscara (usada na folga da
  // regra de dominância).
  int peakCount(int mask) {
    var n = 0;
    for (var i = 0; i < problem.unitCount; i++) {
      if (mask & (1 << i) != 0 && problem.units[i].preferPeak) n++;
    }
    return n;
  }

  /// [a] domina [b] quando, a partir de a, qualquer continuação de b pode ser
  /// repetida com custo menor ou igual. Com o mesmo conjunto de restantes e
  /// t(a) ≤ t(b), cada unidade termina no mesmo instante ou antes; a folga
  /// cobre a única troca de tipo que pode diferir (α) e as parcelas de pico
  /// que podem mudar quando t(a) < t(b) (β por unidade restante).
  bool dominates(_Node a, _Node b) {
    if (a.t > b.t) return false;
    var slack = 0.0;
    if (a.lastType != kNoType && a.lastType != b.lastType) slack += problem.alpha;
    if (a.t < b.t) slack += problem.beta * peakCount(b.mask);
    return a.g + slack <= b.g + _eps;
  }

  final byMask = <int, List<_Node>>{};
  final frontier = _Frontier()..push(rootNode);
  byMask[rootNode.mask] = [rootNode];

  var upperBound = incumbentGreedy.cost;
  _Node? bestGoal;
  var expanded = 0;
  var generated = 0;
  var hitLimit = false;

  if (rootNode.mask == 0) {
    bestGoal = rootNode;
  }

  while (bestGoal == null && !frontier.isEmpty) {
    final node = frontier.pop();
    if (node.dead) continue;
    if (node.mask == 0) {
      // Teste de objetivo na remoção: com h admissível, a primeira meta
      // retirada da fronteira tem custo mínimo.
      bestGoal = node;
      break;
    }
    if (expanded >= problem.nodeLimit) {
      hitLimit = true;
      break;
    }
    expanded++;

    for (var i = 0; i < problem.unitCount; i++) {
      if (node.mask & (1 << i) == 0) continue;
      final tr = transition(problem, node.mask, node.t, node.lastType, i);
      if (tr == null) continue;
      generated++;
      final g = node.g + tr.cost;
      final h = heuristic(problem, tr.nextMask, tr.nextT);
      if (g + h > upperBound + _eps) continue;

      final child = _Node(
        mask: tr.nextMask,
        t: tr.nextT,
        g: g,
        h: h,
        lastType: tr.nextLastType,
        parent: node,
        unitIndex: i,
        start: tr.start,
        seq: seq++,
      );

      final peers = byMask.putIfAbsent(child.mask, () => []);
      if (peers.any((p) => dominates(p, child))) continue;
      peers.removeWhere((p) {
        if (dominates(child, p)) {
          p.dead = true;
          return true;
        }
        return false;
      });
      peers.add(child);

      if (child.mask == 0 && g < upperBound - _eps) {
        // Melhor agenda conhecida até aqui; serve de novo limite superior.
        upperBound = g;
      }
      frontier.push(child);
    }
  }

  watch.stop();

  if (bestGoal == null) {
    // Limite de nós atingido (ou nenhuma agenda melhor que a gulosa): devolve
    // a melhor agenda conhecida.
    final known = _bestKnownGoal(byMask);
    if (known != null && known.g < incumbentGreedy.cost - _eps) {
      return _resultFrom(problem, known, expanded, generated, watch.elapsed,
          optimal: false, hitLimit: hitLimit);
    }
    return incumbentGreedy.copyWith(
      algorithm: Algorithm.aEstrela,
      elapsed: watch.elapsed,
      expanded: expanded,
      generated: generated,
      // Fronteira esgotada sem meta melhor: a gulosa já era ótima.
      optimal: !hitLimit,
      hitNodeLimit: hitLimit,
    );
  }

  return _resultFrom(problem, bestGoal, expanded, generated, watch.elapsed,
      optimal: true, hitLimit: false);
}

_Node? _bestKnownGoal(Map<int, List<_Node>> byMask) {
  final goals = byMask[0];
  if (goals == null || goals.isEmpty) return null;
  return goals.reduce((a, b) => a.g <= b.g ? a : b);
}

SearchResult _resultFrom(
  PlanningProblem problem,
  _Node goal,
  int expanded,
  int generated,
  Duration elapsed, {
  required bool optimal,
  required bool hitLimit,
}) {
  final starts = List<int>.filled(problem.unitCount, -1);
  final order = <int>[];
  for (_Node? n = goal; n != null && n.unitIndex >= 0; n = n.parent) {
    starts[n.unitIndex] = n.start;
    order.add(n.unitIndex);
  }
  return SearchResult(
    algorithm: Algorithm.aEstrela,
    order: List.unmodifiable(order.reversed),
    starts: List.unmodifiable(starts),
    cost: goal.g,
    expanded: expanded,
    generated: generated,
    elapsed: elapsed,
    optimal: optimal,
    hitNodeLimit: hitLimit,
  );
}
