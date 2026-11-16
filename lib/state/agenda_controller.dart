import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/agenda_repository.dart';
import '../domain/conflicts.dart';
import '../domain/entities.dart';
import '../domain/planning/planner_service.dart';
import '../domain/rules/rule_engine.dart';
import 'demo_data.dart';

/// Repositório em uso; substituído em main.dart pelo repositório SQLite.
final repositoryProvider = Provider<AgendaRepository>(
  (ref) => throw UnimplementedError('repositoryProvider precisa ser sobrescrito'),
);

/// Dados carregados do banco antes de a interface abrir.
final initialSnapshotProvider = Provider<AgendaSnapshot>((ref) => const AgendaSnapshot());

/// Verdadeiro quando o SQLite não pôde ser aberto e os dados ficam só na memória.
final volatileStorageProvider = Provider<bool>((ref) => false);

/// Relógio injetável, para que os testes controlem "agora".
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final ruleEngineProvider = Provider<RuleEngine>((ref) => RuleEngine());

final plannerProvider =
    Provider<PlannerService>((ref) => PlannerService(rules: ref.watch(ruleEngineProvider)));

final _random = math.Random();

String newId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
    '${_random.nextInt(1 << 20).toRadixString(36)}';

class AgendaState {
  AgendaState({
    required this.tasks,
    required this.events,
    required this.history,
    required this.preferences,
    required this.currentPlan,
  });

  final List<Task> tasks;
  final List<FixedEvent> events;
  final List<DurationRecord> history;
  final Preferences preferences;
  final PlanRecord? currentPlan;

  late final List<Conflict> conflicts = detectConflicts(events);

  Task? taskById(String id) {
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  FixedEvent? eventById(String id) {
    for (final e in events) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Alocações do plano atual cujas tarefas ainda existem.
  List<Allocation> get allocations {
    final plan = currentPlan;
    if (plan == null) return const [];
    final ids = {for (final t in tasks) t.id};
    return plan.allocations.where((a) => ids.contains(a.taskId)).toList();
  }

  List<Allocation> allocationsOf(String taskId) =>
      allocations.where((a) => a.taskId == taskId).toList();

  AgendaState copyWith({
    List<Task>? tasks,
    List<FixedEvent>? events,
    List<DurationRecord>? history,
    Preferences? preferences,
    PlanRecord? currentPlan,
    bool clearPlan = false,
  }) {
    return AgendaState(
      tasks: tasks ?? this.tasks,
      events: events ?? this.events,
      history: history ?? this.history,
      preferences: preferences ?? this.preferences,
      currentPlan: clearPlan ? null : (currentPlan ?? this.currentPlan),
    );
  }
}

class AgendaController extends Notifier<AgendaState> {
  AgendaRepository get _repo => ref.read(repositoryProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  AgendaState build() {
    final s = ref.read(initialSnapshotProvider);
    return AgendaState(
      tasks: s.tasks,
      events: s.events,
      history: s.history,
      preferences: s.preferences,
      currentPlan: s.currentPlan,
    );
  }

  /// Aplica as regras à tarefa com o histórico atual.
  RuleEvaluation evaluate(Task task) => ref
      .read(ruleEngineProvider)
      .evaluate(task, now: _now(), history: state.history);

  Future<void> saveTask(Task task) async {
    final previous = state.taskById(task.id);
    var toSave = task;
    if (previous != null && previous.status == TaskStatus.alocada) {
      // A alocação antiga deixou de valer: a tarefa volta a pendente.
      toSave = task.copyWith(status: TaskStatus.pendente);
      await _repo.deleteAllocationsOf(task.id);
    }
    await _repo.upsertTask(toSave);
    final tasks = [
      for (final t in state.tasks)
        if (t.id != toSave.id) t,
      toSave,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    state = state.copyWith(tasks: tasks, currentPlan: _planWithout(task.id, previous));
  }

  Future<void> deleteTask(String id) async {
    await _repo.deleteTask(id);
    state = state.copyWith(
      tasks: state.tasks.where((t) => t.id != id).toList(),
      currentPlan: _planWithout(id, null, force: true),
    );
  }

  Future<void> saveEvent(FixedEvent event) async {
    await _repo.upsertEvent(event);
    final events = [
      for (final e in state.events)
        if (e.id != event.id) e,
      event,
    ]..sort((a, b) => a.start.compareTo(b.start));
    state = state.copyWith(events: events);
  }

  Future<void> deleteEvent(String id) async {
    await _repo.deleteEvent(id);
    state = state.copyWith(events: state.events.where((e) => e.id != id).toList());
  }

  /// Conclui a tarefa e registra a duração real (alimenta a regra R7).
  Future<void> completeTask(String id, int actualMinutes) async {
    final task = state.taskById(id);
    if (task == null) return;
    final record = DurationRecord(
      taskId: id,
      type: task.type,
      estimatedMinutes: task.estimatedMinutes,
      actualMinutes: actualMinutes,
      recordedAt: _now(),
    );
    await _repo.addDurationRecord(record);
    await _setStatus(task, TaskStatus.concluida);
    state = state.copyWith(history: [...state.history, record]);
  }

  Future<void> markLate(String id) async {
    final task = state.taskById(id);
    if (task == null) return;
    await _repo.deleteAllocationsOf(id);
    await _setStatus(task, TaskStatus.atrasada);
    state = state.copyWith(currentPlan: _planWithout(id, null, force: true));
  }

  Future<void> reopenTask(String id) async {
    final task = state.taskById(id);
    if (task == null) return;
    await _setStatus(task, TaskStatus.pendente);
  }

  Future<void> _setStatus(Task task, TaskStatus status) async {
    final updated = task.copyWith(status: status);
    await _repo.upsertTask(updated);
    state = state.copyWith(
      tasks: [for (final t in state.tasks) t.id == task.id ? updated : t],
    );
  }

  Future<void> savePreferences(Preferences preferences) async {
    await _repo.savePreferences(preferences);
    state = state.copyWith(preferences: preferences);
  }

  /// Aceita a agenda proposta por uma estratégia (tela T6).
  Future<void> acceptPlan(PlanOutcome outcome) async {
    final plan = PlanRecord(
      id: newId('plano'),
      createdAt: _now(),
      algorithm: outcome.algorithm,
      totalCost: outcome.cost,
      totalTardinessMinutes: outcome.totalTardinessMinutes,
      elapsedMilliseconds: outcome.elapsedMilliseconds,
      expandedNodes: outcome.search.expanded,
      optimal: outcome.search.optimal,
      allocations: outcome.allocations,
      unscheduledTaskIds: outcome.unscheduledTaskIds,
    );
    await _repo.savePlan(plan);

    final allocated = {for (final a in outcome.allocations) a.taskId};
    final unscheduled = outcome.unscheduledTaskIds.toSet();
    final tasks = <Task>[];
    for (final t in state.tasks) {
      if (!outcome.built.tasks.containsKey(t.id)) {
        tasks.add(t);
        continue;
      }
      final status = allocated.contains(t.id) && !unscheduled.contains(t.id)
          ? TaskStatus.alocada
          : TaskStatus.pendente;
      final updated = t.copyWith(status: status);
      if (updated.status != t.status) await _repo.upsertTask(updated);
      tasks.add(updated);
    }
    state = state.copyWith(tasks: tasks, currentPlan: plan);
  }

  Future<void> loadDemo() async {
    await _repo.clearAll();
    final demo = buildDemoScenario(_now());
    for (final e in demo.events) {
      await _repo.upsertEvent(e);
    }
    for (final t in demo.tasks) {
      await _repo.upsertTask(t);
    }
    for (final r in demo.history) {
      await _repo.addDurationRecord(r);
    }
    await _repo.savePreferences(state.preferences);
    state = AgendaState(
      tasks: demo.tasks,
      events: demo.events,
      history: demo.history,
      preferences: state.preferences,
      currentPlan: null,
    );
  }

  Future<void> clearAll() async {
    await _repo.clearAll();
    state = AgendaState(
      tasks: const [],
      events: const [],
      history: const [],
      preferences: const Preferences(),
      currentPlan: null,
    );
  }

  PlanRecord? _planWithout(String taskId, Task? previous, {bool force = false}) {
    final plan = state.currentPlan;
    if (plan == null) return null;
    if (!force && (previous == null || previous.status != TaskStatus.alocada)) {
      return plan;
    }
    return PlanRecord(
      id: plan.id,
      createdAt: plan.createdAt,
      algorithm: plan.algorithm,
      totalCost: plan.totalCost,
      totalTardinessMinutes: plan.totalTardinessMinutes,
      elapsedMilliseconds: plan.elapsedMilliseconds,
      expandedNodes: plan.expandedNodes,
      optimal: plan.optimal,
      allocations: plan.allocations.where((a) => a.taskId != taskId).toList(),
      unscheduledTaskIds: plan.unscheduledTaskIds,
    );
  }
}

final agendaProvider =
    NotifierProvider<AgendaController, AgendaState>(AgendaController.new);

// ------------------------------------------------------------- planejamento

enum PlanStart { agora, amanha }

enum PlanStrategy {
  guloso('Gulosa', {Algorithm.guloso}),
  aEstrela('A*', {Algorithm.aEstrela}),
  comparar('Comparar', {Algorithm.guloso, Algorithm.aEstrela});

  const PlanStrategy(this.label, this.algorithms);
  final String label;
  final Set<Algorithm> algorithms;
}

class PlanningState {
  const PlanningState({this.outcomes = const [], this.error});
  final List<PlanOutcome> outcomes;
  final String? error;
}

class PlanningController extends Notifier<PlanningState> {
  @override
  PlanningState build() => const PlanningState();

  /// Gera as agendas com as preferências informadas (tela T5).
  PlanningState generate({
    required PlanStrategy strategy,
    required PlanStart start,
    required Preferences preferences,
  }) {
    final agenda = ref.read(agendaProvider);
    final now = ref.read(clockProvider)();
    final startAt = start == PlanStart.agora
        ? now
        : DateTime(now.year, now.month, now.day + 1, 0, 0)
            .add(Duration(minutes: preferences.workStartMinutes));
    try {
      final outcomes = ref.read(plannerProvider).plan(
            PlanRequest(
              tasks: agenda.tasks,
              events: agenda.events,
              preferences: preferences,
              start: startAt,
              now: now,
              history: agenda.history,
            ),
            strategy.algorithms,
          );
      state = PlanningState(outcomes: outcomes);
    } on ArgumentError catch (e) {
      state = PlanningState(error: e.message.toString());
    }
    return state;
  }
}

final planningProvider =
    NotifierProvider<PlanningController, PlanningState>(PlanningController.new);
