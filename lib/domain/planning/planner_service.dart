import '../conflicts.dart';
import '../entities.dart';
import '../rules/rule_engine.dart';
import 'astar.dart';
import 'greedy.dart';
import 'problem.dart';
import 'search_core.dart';

/// Arredonda para o próximo múltiplo de 15 minutos do relógio.
DateTime ceilToSlot(DateTime time) {
  final base = DateTime(time.year, time.month, time.day, time.hour, time.minute);
  final hasSeconds = time.second > 0 || time.millisecond > 0 || time.microsecond > 0;
  final rest = base.minute % kSlotMinutes;
  if (rest == 0 && !hasSeconds) return base;
  return base.add(Duration(minutes: kSlotMinutes - rest));
}

/// Problema já discretizado, com o mapeamento de volta para datas reais.
class BuiltProblem {
  const BuiltProblem({
    required this.problem,
    required this.start,
    required this.tasks,
    required this.evaluations,
  });

  final PlanningProblem problem;

  /// Instante do slot 0.
  final DateTime start;
  final Map<String, Task> tasks;
  final Map<String, RuleEvaluation> evaluations;

  DateTime slotTime(int slot) =>
      start.add(Duration(minutes: slot * kSlotMinutes));
}

/// Resultado de uma estratégia, já convertido para datas.
class PlanOutcome {
  const PlanOutcome({
    required this.built,
    required this.search,
    required this.allocations,
    required this.unscheduledTaskIds,
    required this.totalTardinessMinutes,
    required this.lateTaskIds,
  });

  final BuiltProblem built;
  final SearchResult search;
  final List<Allocation> allocations;
  final List<String> unscheduledTaskIds;
  final int totalTardinessMinutes;
  final Set<String> lateTaskIds;

  Algorithm get algorithm => search.algorithm;
  double get cost => search.cost;
  double get elapsedMilliseconds => search.elapsed.inMicroseconds / 1000;
}

class PlanRequest {
  const PlanRequest({
    required this.tasks,
    required this.events,
    required this.preferences,
    required this.start,
    required this.now,
    this.history = const [],
    this.horizonDays,
  });

  /// Tarefas a planejar. Tarefas concluídas são ignoradas.
  final List<Task> tasks;
  final List<FixedEvent> events;
  final Preferences preferences;

  /// Início do planejamento; é arredondado para o próximo slot.
  final DateTime start;

  /// Instante atual, usado pela regra R5.
  final DateTime now;
  final List<DurationRecord> history;
  final int? horizonDays;
}

class PlannerService {
  PlannerService({RuleEngine? rules}) : rules = rules ?? RuleEngine();

  final RuleEngine rules;

  BuiltProblem build(PlanRequest request) {
    final prefs = request.preferences;
    final start = ceilToSlot(request.start);
    final days = (request.horizonDays ?? prefs.horizonDays).clamp(1, 7);
    final firstDay = DateTime(start.year, start.month, start.day);
    final end = DateTime(firstDay.year, firstDay.month, firstDay.day + days);
    final horizon = end.difference(start).inMinutes ~/ kSlotMinutes;

    final free = List<bool>.filled(horizon, false);
    final peak = List<bool>.filled(horizon, false);
    for (var s = 0; s < horizon; s++) {
      final slotStart = start.add(Duration(minutes: s * kSlotMinutes));
      final minuteOfDay = slotStart.hour * 60 + slotStart.minute;
      final inWork = minuteOfDay >= prefs.workStartMinutes &&
          minuteOfDay + kSlotMinutes <= prefs.workEndMinutes;
      free[s] = inWork;
      peak[s] = minuteOfDay >= prefs.peakStartMinutes &&
          minuteOfDay < prefs.peakEndMinutes;
    }
    for (final event in request.events) {
      for (var s = 0; s < horizon; s++) {
        if (!free[s]) continue;
        final slotStart = start.add(Duration(minutes: s * kSlotMinutes));
        final slotEnd = slotStart.add(const Duration(minutes: kSlotMinutes));
        if (overlaps(slotStart, slotEnd, event.start, event.end)) free[s] = false;
      }
    }

    final units = <PlanUnit>[];
    final tasks = <String, Task>{};
    final evaluations = <String, RuleEvaluation>{};
    for (final task in request.tasks) {
      if (!task.status.isOpen) continue;
      final evaluation =
          rules.evaluate(task, now: request.now, history: request.history);
      tasks[task.id] = task;
      evaluations[task.id] = evaluation;
      final deadlineSlot =
          (task.deadline.difference(start).inMinutes / kSlotMinutes).floor();
      final chunks = evaluation.chunks;
      for (var part = 0; part < chunks.length; part++) {
        units.add(PlanUnit(
          index: units.length,
          taskId: task.id,
          title: task.title,
          durationSlots: (chunks[part] / kSlotMinutes).ceil(),
          deadlineSlot: deadlineSlot,
          weight: evaluation.weight,
          type: task.type,
          preferPeak: evaluation.preferPeak,
          pauseAfterSlots: chunks.length > 1 ? 1 : 0,
          part: part + 1,
          partCount: chunks.length,
        ));
      }
    }

    return BuiltProblem(
      problem: PlanningProblem(
        units: units,
        free: free,
        peak: peak,
        alpha: prefs.alpha,
        beta: prefs.beta,
        nodeLimit: prefs.nodeLimit,
      ),
      start: start,
      tasks: tasks,
      evaluations: evaluations,
    );
  }

  /// Executa as estratégias pedidas sobre o mesmo problema.
  ///
  /// Acima de [kAStarMaxUnits] blocos, o A* recorre à solução gulosa e o
  /// resultado é marcado com [SearchResult.fellBackToGreedy].
  List<PlanOutcome> run(BuiltProblem built, Set<Algorithm> algorithms) {
    final outcomes = <PlanOutcome>[];
    SearchResult? greedy;
    if (algorithms.contains(Algorithm.guloso) || algorithms.contains(Algorithm.aEstrela)) {
      greedy = greedySearch(built.problem);
    }
    if (algorithms.contains(Algorithm.guloso)) {
      outcomes.add(_toOutcome(built, greedy!));
    }
    if (algorithms.contains(Algorithm.aEstrela)) {
      final SearchResult astar;
      if (built.problem.unitCount > kAStarMaxUnits) {
        astar = greedy!.copyWith(
          algorithm: Algorithm.aEstrela,
          fellBackToGreedy: true,
          optimal: false,
        );
      } else {
        astar = aStarSearch(built.problem, greedy: greedy);
      }
      outcomes.add(_toOutcome(built, astar));
    }
    return outcomes;
  }

  List<PlanOutcome> plan(PlanRequest request, Set<Algorithm> algorithms) =>
      run(build(request), algorithms);

  PlanOutcome _toOutcome(BuiltProblem built, SearchResult search) {
    final problem = built.problem;
    final allocations = <Allocation>[];
    final unscheduled = <String>{};
    final lateIds = <String>{};
    var tardiness = 0;
    for (var i = 0; i < problem.unitCount; i++) {
      final unit = problem.units[i];
      final start = search.starts[i];
      if (start < 0) {
        unscheduled.add(unit.taskId);
        continue;
      }
      final end = start + unit.durationSlots;
      final unitLate = end - unit.deadlineSlot;
      if (unitLate > 0) {
        tardiness += unitLate * kSlotMinutes;
        lateIds.add(unit.taskId);
      }
      allocations.add(Allocation(
        taskId: unit.taskId,
        title: unit.title,
        start: built.slotTime(start),
        end: built.slotTime(end),
        part: unit.part,
        partCount: unit.partCount,
      ));
    }
    allocations.sort((a, b) => a.start.compareTo(b.start));
    return PlanOutcome(
      built: built,
      search: search,
      allocations: List.unmodifiable(allocations),
      unscheduledTaskIds: List.unmodifiable(unscheduled),
      totalTardinessMinutes: tardiness,
      lateTaskIds: Set.unmodifiable(lateIds),
    );
  }
}
