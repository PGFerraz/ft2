import 'dart:math' as math;

import '../entities.dart';
import 'problem.dart';

/// Gera instâncias aleatórias reprodutíveis (semente fixa) para os testes de
/// admissibilidade, comparativos e de desempenho (Tabela 10 do Bloco 2).
///
/// O horizonte é um dia de trabalho das 07:00 às 22:00 (60 slots de 15 min),
/// com até três compromissos fixos e prazos apertados o bastante para que
/// haja atraso em parte das instâncias.
PlanningProblem randomProblem(
  math.Random random, {
  required int units,
  int horizon = 60,
  double alpha = 1.0,
  double beta = 0.5,
  int nodeLimit = 200000,
}) {
  final free = List<bool>.filled(horizon, true);
  final fixedCount = random.nextInt(4);
  for (var k = 0; k < fixedCount; k++) {
    final start = random.nextInt(horizon - 4);
    final length = 2 + random.nextInt(4);
    for (var s = start; s < math.min(horizon, start + length); s++) {
      free[s] = false;
    }
  }
  final peakStart = random.nextInt(horizon ~/ 2);
  final peak = [
    for (var s = 0; s < horizon; s++) s >= peakStart && s < peakStart + 12,
  ];

  final list = <PlanUnit>[];
  for (var i = 0; i < units; i++) {
    final duration = 1 + random.nextInt(8);
    final type = random.nextBool() ? TaskType.foco : TaskType.leve;
    list.add(PlanUnit(
      index: i,
      taskId: 't$i',
      title: 'Tarefa $i',
      durationSlots: duration,
      deadlineSlot: duration + random.nextInt(horizon),
      weight: 1 + random.nextInt(4),
      type: type,
      preferPeak: type == TaskType.foco || random.nextInt(4) == 0,
    ));
  }

  return PlanningProblem(
    units: list,
    free: free,
    peak: peak,
    alpha: alpha,
    beta: beta,
    nodeLimit: nodeLimit,
  );
}
