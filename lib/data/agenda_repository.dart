import '../domain/entities.dart';

/// Tudo o que o aplicativo precisa carregar ao abrir.
class AgendaSnapshot {
  const AgendaSnapshot({
    this.tasks = const [],
    this.events = const [],
    this.history = const [],
    this.preferences = const Preferences(),
    this.currentPlan,
  });

  final List<Task> tasks;
  final List<FixedEvent> events;
  final List<DurationRecord> history;
  final Preferences preferences;

  /// Último planejamento aceito pelo usuário.
  final PlanRecord? currentPlan;
}

/// Contrato da camada de dados. A interface e o estado só conhecem esta
/// abstração; a implementação em SQLite fica em [SqliteAgendaRepository].
abstract class AgendaRepository {
  Future<AgendaSnapshot> loadAll();
  Future<void> upsertTask(Task task);
  Future<void> deleteTask(String id);
  Future<void> upsertEvent(FixedEvent event);
  Future<void> deleteEvent(String id);
  Future<void> addDurationRecord(DurationRecord record);
  Future<void> savePreferences(Preferences preferences);

  /// Grava o planejamento aceito e suas alocações.
  Future<void> savePlan(PlanRecord plan);

  /// Remove as alocações de uma tarefa do planejamento atual (por exemplo,
  /// quando ela é editada ou concluída).
  Future<void> deleteAllocationsOf(String taskId);
  Future<void> clearAll();
}

/// Implementação em memória, usada nos testes de widget.
class InMemoryAgendaRepository implements AgendaRepository {
  InMemoryAgendaRepository([AgendaSnapshot initial = const AgendaSnapshot()])
      : _tasks = {for (final t in initial.tasks) t.id: t},
        _events = {for (final e in initial.events) e.id: e},
        _history = List.of(initial.history),
        _preferences = initial.preferences,
        _plan = initial.currentPlan;

  final Map<String, Task> _tasks;
  final Map<String, FixedEvent> _events;
  final List<DurationRecord> _history;
  Preferences _preferences;
  PlanRecord? _plan;

  @override
  Future<AgendaSnapshot> loadAll() async => AgendaSnapshot(
        tasks: _tasks.values.toList(),
        events: _events.values.toList(),
        history: List.of(_history),
        preferences: _preferences,
        currentPlan: _plan,
      );

  @override
  Future<void> upsertTask(Task task) async => _tasks[task.id] = task;

  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
    await deleteAllocationsOf(id);
  }

  @override
  Future<void> upsertEvent(FixedEvent event) async => _events[event.id] = event;

  @override
  Future<void> deleteEvent(String id) async => _events.remove(id);

  @override
  Future<void> addDurationRecord(DurationRecord record) async => _history.add(record);

  @override
  Future<void> savePreferences(Preferences preferences) async =>
      _preferences = preferences;

  @override
  Future<void> savePlan(PlanRecord plan) async => _plan = plan;

  @override
  Future<void> deleteAllocationsOf(String taskId) async {
    final plan = _plan;
    if (plan == null) return;
    _plan = PlanRecord(
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

  @override
  Future<void> clearAll() async {
    _tasks.clear();
    _events.clear();
    _history.clear();
    _preferences = const Preferences();
    _plan = null;
  }
}
