import 'dart:math' as math;
import 'dart:typed_data';

import '../entities.dart';

/// Duração de um slot, em minutos (Seção 3.4).
const int kSlotMinutes = 15;

/// Penalidade extra, em slots de atraso, para uma tarefa que não coube no
/// horizonte. Ela é maior que qualquer atraso possível dentro do horizonte,
/// de modo que deixar uma tarefa de fora sempre custa mais que alocá-la.
const int kUnscheduledExtraSlots = 1000;

/// Maior quantidade de unidades que o A* aceita antes de recorrer à busca
/// gulosa (Seção 3.5: "viável para até cerca de 10 a 12 tarefas").
const int kAStarMaxUnits = 12;

/// Limite rígido de unidades de um problema (o conjunto de restantes é
/// guardado em uma máscara de bits de 32 bits, que funciona também na web).
const int kMaxUnits = 30;

/// Uma unidade de planejamento: uma tarefa inteira ou um bloco de uma tarefa
/// dividida pela regra R6.
class PlanUnit {
  const PlanUnit({
    required this.index,
    required this.taskId,
    required this.title,
    required this.durationSlots,
    required this.deadlineSlot,
    required this.weight,
    required this.type,
    required this.preferPeak,
    this.pauseAfterSlots = 0,
    this.part = 1,
    this.partCount = 1,
  });

  final int index;
  final String taskId;
  final String title;
  final int durationSlots;

  /// Prazo p, em slots a partir do início do horizonte. Pode ser negativo
  /// quando o prazo já passou.
  final int deadlineSlot;

  /// Peso w, derivado da prioridade.
  final int weight;
  final TaskType type;

  /// Verdadeiro para tarefas de foco e para as que dispararam R2.
  final bool preferPeak;

  /// Pausa obrigatória depois do bloco (R6).
  final int pauseAfterSlots;
  final int part;
  final int partCount;
}

/// Instância do problema de agendamento, já discretizada em slots.
class PlanningProblem {
  PlanningProblem({
    required List<PlanUnit> units,
    required List<bool> free,
    required List<bool> peak,
    this.alpha = 1.0,
    this.beta = 0.5,
    this.nodeLimit = 50000,
  })  : units = List.unmodifiable(units),
        free = List.unmodifiable(free),
        peak = List.unmodifiable(peak),
        assert(free.length == peak.length) {
    if (units.length > kMaxUnits) {
      throw ArgumentError(
          'O planejamento aceita até $kMaxUnits blocos de tarefa; recebeu ${units.length}.');
    }
    for (var i = 0; i < units.length; i++) {
      if (units[i].index != i) {
        throw ArgumentError('O índice da unidade $i não corresponde à posição.');
      }
      if (units[i].durationSlots <= 0) {
        throw ArgumentError('A unidade "${units[i].title}" tem duração inválida.');
      }
    }
    _freeRun = Int32List(horizon + 1);
    for (var s = horizon - 1; s >= 0; s--) {
      _freeRun[s] = free[s] ? _freeRun[s + 1] + 1 : 0;
    }
  }

  final List<PlanUnit> units;

  /// free[s] é verdadeiro quando o slot s está dentro do horário de trabalho e
  /// não toca nenhum compromisso fixo.
  final List<bool> free;

  /// peak[s] é verdadeiro quando o slot s está no período de pico do usuário.
  final List<bool> peak;
  final double alpha;
  final double beta;
  final int nodeLimit;

  late final Int32List _freeRun;
  final Map<int, Int32List> _nextFitByDuration = {};

  int get horizon => free.length;
  int get unitCount => units.length;
  int get fullMask => unitCount == 0 ? 0 : (1 << unitCount) - 1;

  /// Primeiro slot s ≥ from tal que [s, s + d) está todo livre, ou -1.
  ///
  /// A tabela de cada duração é calculada uma única vez, o que deixa a
  /// consulta em O(1) durante a busca.
  int earliestStart(int from, int durationSlots) {
    if (from >= horizon) return -1;
    final table = _nextFitByDuration.putIfAbsent(durationSlots, () {
      final t = Int32List(horizon + 1);
      t[horizon] = -1;
      for (var s = horizon - 1; s >= 0; s--) {
        t[s] = _freeRun[s] >= durationSlots ? s : t[s + 1];
      }
      return t;
    });
    return table[from < 0 ? 0 : from];
  }

  /// Custo de deixar a unidade fora da agenda. É sempre maior ou igual ao
  /// termo da heurística da unidade em qualquer instante do horizonte, o que
  /// mantém h admissível.
  double unscheduledPenalty(PlanUnit unit) {
    final worstTardiness =
        math.max(0, horizon + unit.durationSlots - unit.deadlineSlot);
    return unit.weight * (worstTardiness + kUnscheduledExtraSlots).toDouble();
  }
}
