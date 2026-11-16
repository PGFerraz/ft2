import '../domain/entities.dart';

/// Cenário de demonstração para o Product Demo Day.
///
/// Os horários são relativos ao dia de hoje para que a demonstração funcione
/// em qualquer data. Inclui um conflito proposital (RF03), uma tarefa longa
/// que dispara R6 e um histórico que dispara R7 para tarefas de foco.
class DemoScenario {
  const DemoScenario(this.tasks, this.events, this.history);
  final List<Task> tasks;
  final List<FixedEvent> events;
  final List<DurationRecord> history;
}

DemoScenario buildDemoScenario(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  DateTime at(int dayOffset, int hour, [int minute = 0]) =>
      DateTime(today.year, today.month, today.day + dayOffset, hour, minute);

  final events = [
    FixedEvent(id: 'demo-e1', title: 'Aula de Inteligência Artificial', start: at(0, 7, 20), end: at(0, 9), location: 'Fainor'),
    FixedEvent(id: 'demo-e2', title: 'Almoço', start: at(0, 12), end: at(0, 13)),
    FixedEvent(id: 'demo-e3', title: 'Estágio', start: at(0, 14), end: at(0, 18)),
    FixedEvent(id: 'demo-e4', title: 'Consulta médica', start: at(0, 17, 30), end: at(0, 18, 30), location: 'Clínica'),
    FixedEvent(id: 'demo-e5', title: 'Almoço', start: at(1, 12), end: at(1, 13)),
    FixedEvent(id: 'demo-e6', title: 'Reunião do grupo', start: at(1, 19), end: at(1, 20)),
  ];

  var order = 0;
  Task task(String id, String title, TaskType type, int minutes, DateTime deadline,
      {bool urgent = false, bool important = false}) {
    return Task(
      id: id,
      title: title,
      type: type,
      estimatedMinutes: minutes,
      deadline: deadline,
      urgent: urgent,
      important: important,
      createdAt: now.add(Duration(milliseconds: order++)),
    );
  }

  final tasks = [
    task('demo-t1', 'Preparar slides do pitch', TaskType.foco, 90, at(1, 10), urgent: true, important: true),
    task('demo-t2', 'Implementar testes do motor A*', TaskType.foco, 120, at(1, 18), important: true),
    task('demo-t3', 'Lista de exercícios de Lógica', TaskType.leve, 45, at(0, 23), urgent: true),
    task('demo-t4', 'Revisar artigo de Hart, Nilsson e Raphael', TaskType.foco, 60, at(2, 12), important: true),
    task('demo-t5', 'Responder e-mails do estágio', TaskType.leve, 30, at(1, 9)),
    task('demo-t6', 'Organizar referências do documento', TaskType.leve, 30, at(3, 18)),
  ];

  // Histórico: tarefas de foco levaram em média ~1,3× o estimado (R7).
  final history = [
    DurationRecord(taskId: 'hist-1', type: TaskType.foco, estimatedMinutes: 60, actualMinutes: 80, recordedAt: at(-3, 10)),
    DurationRecord(taskId: 'hist-2', type: TaskType.foco, estimatedMinutes: 90, actualMinutes: 120, recordedAt: at(-2, 15)),
    DurationRecord(taskId: 'hist-3', type: TaskType.foco, estimatedMinutes: 45, actualMinutes: 55, recordedAt: at(-1, 9)),
    DurationRecord(taskId: 'hist-4', type: TaskType.leve, estimatedMinutes: 30, actualMinutes: 30, recordedAt: at(-1, 16)),
  ];

  return DemoScenario(tasks, events, history);
}
