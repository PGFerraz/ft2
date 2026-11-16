import 'package:agenda_ia/domain/entities.dart';
import 'package:agenda_ia/domain/rules/rule_engine.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 11, 8);

Task _task({
  int minutes = 60,
  Duration untilDeadline = const Duration(days: 3),
  bool urgent = false,
  bool important = false,
  TaskType type = TaskType.leve,
  int? override,
}) {
  return Task(
    id: 't',
    title: 'Tarefa',
    type: type,
    estimatedMinutes: minutes,
    deadline: _now.add(untilDeadline),
    urgent: urgent,
    important: important,
    priorityOverride: override,
    createdAt: _now,
  );
}

DurationRecord _record(TaskType type, int estimated, int actual) => DurationRecord(
      taskId: 'h',
      type: type,
      estimatedMinutes: estimated,
      actualMinutes: actual,
      recordedAt: _now,
    );

void main() {
  final engine = RuleEngine();

  group('R1 a R4 (matriz de urgência e importância)', () {
    test('R1: urgente e importante → prioridade 4', () {
      final e = engine.evaluate(_task(urgent: true, important: true), now: _now);
      expect(e.priority, 4);
      expect(e.hasFired('R1'), isTrue);
    });

    test('R2: importante e não urgente → prioridade 3 e preferência de pico', () {
      final e = engine.evaluate(_task(important: true), now: _now);
      expect(e.priority, 3);
      expect(e.preferPeak, isTrue);
      expect(e.hasFired('R2'), isTrue);
    });

    test('R3: urgente e não importante → prioridade 2', () {
      final e = engine.evaluate(_task(urgent: true), now: _now);
      expect(e.priority, 2);
      expect(e.preferPeak, isFalse);
    });

    test('R4: nem urgente nem importante → prioridade 1', () {
      final e = engine.evaluate(_task(), now: _now);
      expect(e.priority, 1);
      expect(e.fired.map((f) => f.ruleId), ['R4']);
    });

    test('apenas uma regra de prioridade dispara por tarefa', () {
      final e = engine.evaluate(_task(urgent: true, important: true), now: _now);
      final priorityRules =
          e.fired.where((f) => ['R1', 'R2', 'R3', 'R4'].contains(f.ruleId));
      expect(priorityRules, hasLength(1));
    });

    test('prioridade manual substitui a sugestão sem apagá-la', () {
      final e = engine.evaluate(_task(override: 2), now: _now);
      expect(e.suggestedPriority, 1);
      expect(e.priority, 2);
      expect(e.weight, 2);
    });
  });

  group('R5 (urgência pelo prazo)', () {
    test('prazo menor que 2 × duração marca a tarefa como urgente', () {
      final e = engine.evaluate(
        _task(minutes: 60, untilDeadline: const Duration(minutes: 90), important: true),
        now: _now,
      );
      expect(e.urgent, isTrue);
      expect(e.fired.map((f) => f.ruleId), containsAllInOrder(['R5', 'R1']));
      expect(e.priority, 4);
    });

    test('prazo igual a 2 × duração não dispara R5', () {
      final e = engine.evaluate(
        _task(minutes: 60, untilDeadline: const Duration(minutes: 120)),
        now: _now,
      );
      expect(e.hasFired('R5'), isFalse);
      expect(e.urgent, isFalse);
    });

    test('prazo vencido também é urgente', () {
      final e = engine.evaluate(
        _task(untilDeadline: const Duration(hours: -1)),
        now: _now,
      );
      expect(e.urgent, isTrue);
      expect(e.priority, 2);
    });
  });

  group('R6 (divisão de tarefas longas)', () {
    test('90 min não é dividida', () {
      final e = engine.evaluate(_task(minutes: 90), now: _now);
      expect(e.chunks, [90]);
      expect(e.hasFired('R6'), isFalse);
    });

    test('150 min vira blocos de 60 + 60 + 30', () {
      final e = engine.evaluate(_task(minutes: 150), now: _now);
      expect(e.chunks, [60, 60, 30]);
    });
  });

  group('R7 (aprendizado com o histórico)', () {
    test('menos de 3 registros não altera a duração', () {
      final e = engine.evaluate(
        _task(minutes: 60),
        now: _now,
        history: [_record(TaskType.leve, 60, 120), _record(TaskType.leve, 60, 120)],
      );
      expect(e.adjustedMinutes, 60);
    });

    test('média ≥ 1,25 corrige a duração e arredonda para 15 min', () {
      final e = engine.evaluate(
        _task(minutes: 60),
        now: _now,
        history: [
          _record(TaskType.leve, 60, 75),
          _record(TaskType.leve, 60, 80),
          _record(TaskType.leve, 30, 40),
        ],
      );
      // Razões: 1,25; 1,333...; 1,333... → média 1,305... → 78,3 min → 90 min.
      expect(e.correctionFactor, closeTo(1.3056, 1e-3));
      expect(e.adjustedMinutes, 90);
    });

    test('histórico de outro tipo de tarefa é ignorado', () {
      final e = engine.evaluate(
        _task(minutes: 60, type: TaskType.leve),
        now: _now,
        history: List.generate(3, (_) => _record(TaskType.foco, 60, 120)),
      );
      expect(e.adjustedMinutes, 60);
    });

    test('R7 dispara antes de R5 e de R6 (encadeamento)', () {
      // 60 min × 2,0 = 120 min > 90 → R6; prazo de 3 h < 2 × 120 → R5.
      final e = engine.evaluate(
        _task(minutes: 60, untilDeadline: const Duration(hours: 3)),
        now: _now,
        history: List.generate(3, (_) => _record(TaskType.leve, 60, 120)),
      );
      expect(e.fired.map((f) => f.ruleId), ['R7', 'R5', 'R3', 'R6']);
      expect(e.chunks, [60, 60]);
    });
  });

  test('tarefa de foco sempre prefere o horário de pico', () {
    final e = engine.evaluate(_task(type: TaskType.foco), now: _now);
    expect(e.preferPeak, isTrue);
  });
}
