import 'package:agenda_ia/data/sqlite_agenda_repository.dart';
import 'package:agenda_ia/domain/entities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late SqliteAgendaRepository repo;
  final now = DateTime(2026, 11, 11, 9, 30);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    repo = await SqliteAgendaRepository.open(databaseFactoryFfi, path: inMemoryDatabasePath);
  });

  tearDown(() => repo.close());

  Task task(String id, {TaskStatus status = TaskStatus.pendente, int? override}) => Task(
        id: id,
        title: 'Tarefa $id',
        type: TaskType.foco,
        estimatedMinutes: 90,
        deadline: now.add(const Duration(days: 1)),
        urgent: true,
        important: false,
        priorityOverride: override,
        status: status,
        createdAt: now,
      );

  test('banco novo carrega vazio e com preferências padrão', () async {
    final s = await repo.loadAll();
    expect(s.tasks, isEmpty);
    expect(s.events, isEmpty);
    expect(s.currentPlan, isNull);
    expect(s.preferences.alpha, 1.0);
  });

  test('tarefa é gravada, atualizada e lida sem perda de campos', () async {
    await repo.upsertTask(task('a', override: 3));
    await repo.upsertTask(task('a', status: TaskStatus.atrasada, override: 3));
    final t = (await repo.loadAll()).tasks.single;
    expect(t.title, 'Tarefa a');
    expect(t.type, TaskType.foco);
    expect(t.estimatedMinutes, 90);
    expect(t.deadline, now.add(const Duration(days: 1)));
    expect(t.urgent, isTrue);
    expect(t.important, isFalse);
    expect(t.priorityOverride, 3);
    expect(t.status, TaskStatus.atrasada);
  });

  test('compromissos, histórico e preferências persistem', () async {
    await repo.upsertEvent(FixedEvent(
        id: 'e', title: 'Aula', start: now, end: now.add(const Duration(hours: 1)), location: 'Sala 3'));
    await repo.addDurationRecord(DurationRecord(
        taskId: 'a', type: TaskType.leve, estimatedMinutes: 30, actualMinutes: 45, recordedAt: now));
    await repo.savePreferences(const Preferences(alpha: 2, beta: 0.25, horizonDays: 5));
    final s = await repo.loadAll();
    expect(s.events.single.location, 'Sala 3');
    expect(s.history.single.ratio, 1.5);
    expect(s.preferences.alpha, 2);
    expect(s.preferences.beta, 0.25);
    expect(s.preferences.horizonDays, 5);
  });

  test('planejamento mais recente é o atual; excluir tarefa remove alocações', () async {
    await repo.upsertTask(task('a'));
    await repo.upsertTask(task('b'));
    PlanRecord plan(String id, DateTime at) => PlanRecord(
          id: id,
          createdAt: at,
          algorithm: Algorithm.aEstrela,
          totalCost: 4.5,
          totalTardinessMinutes: 15,
          elapsedMilliseconds: 1.25,
          expandedNodes: 12,
          optimal: true,
          allocations: [
            Allocation(taskId: 'a', title: 'A', start: now, end: now.add(const Duration(hours: 1))),
            Allocation(
                taskId: 'b',
                title: 'B',
                start: now.add(const Duration(hours: 2)),
                end: now.add(const Duration(hours: 3)),
                part: 1,
                partCount: 2),
          ],
          unscheduledTaskIds: const ['c'],
        );
    await repo.savePlan(plan('p1', now));
    await repo.savePlan(plan('p2', now.add(const Duration(minutes: 5))));

    var current = (await repo.loadAll()).currentPlan!;
    expect(current.id, 'p2');
    expect(current.algorithm, Algorithm.aEstrela);
    expect(current.allocations, hasLength(2));
    expect(current.allocations[1].partCount, 2);
    expect(current.unscheduledTaskIds, ['c']);

    await repo.deleteTask('a');
    current = (await repo.loadAll()).currentPlan!;
    expect(current.allocations.map((a) => a.taskId), ['b']);
  });

  test('restrições do esquema rejeitam dados inválidos', () async {
    expect(
      () => repo.upsertEvent(FixedEvent(id: 'x', title: 'Inválido', start: now, end: now)),
      throwsA(isA<DatabaseException>()),
    );
  });
}
