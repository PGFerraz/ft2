/// Entidades do domínio do AgendaIA (Tabela 5 do Bloco 2).
///
/// Este arquivo é Dart puro: não importa Flutter, para que o motor de busca e a
/// base de regras possam ser testados isoladamente (RNF03).
library;

enum TaskType {
  foco('Foco'),
  leve('Leve');

  const TaskType(this.label);
  final String label;
}

enum TaskStatus {
  pendente('Pendente'),
  alocada('Alocada'),
  concluida('Concluída'),
  atrasada('Atrasada');

  const TaskStatus(this.label);
  final String label;

  /// Tarefas que ainda entram no planejamento.
  bool get isOpen => this != TaskStatus.concluida;
}

enum Algorithm {
  guloso('Busca gulosa'),
  aEstrela('A*');

  const Algorithm(this.label);
  final String label;
}

/// Compromisso com horário fixo: não pode ser movido pelo agente.
class FixedEvent {
  const FixedEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.location,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? location;

  Duration get duration => end.difference(start);

  FixedEvent copyWith({
    String? title,
    DateTime? start,
    DateTime? end,
    String? location,
    bool clearLocation = false,
  }) {
    return FixedEvent(
      id: id,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      location: clearLocation ? null : (location ?? this.location),
    );
  }
}

/// Tarefa flexível: o agente decide quando ela será executada.
class Task {
  const Task({
    required this.id,
    required this.title,
    required this.type,
    required this.estimatedMinutes,
    required this.deadline,
    required this.urgent,
    required this.important,
    required this.createdAt,
    this.priorityOverride,
    this.status = TaskStatus.pendente,
  });

  final String id;
  final String title;
  final TaskType type;
  final int estimatedMinutes;
  final DateTime deadline;

  /// Urgência informada pelo usuário. A regra R5 pode marcar a tarefa como
  /// urgente mesmo quando este campo é falso.
  final bool urgent;
  final bool important;

  /// Prioridade escolhida manualmente (1 a 4). Quando nula, vale a sugestão
  /// da base de regras.
  final int? priorityOverride;
  final TaskStatus status;
  final DateTime createdAt;

  Task copyWith({
    String? title,
    TaskType? type,
    int? estimatedMinutes,
    DateTime? deadline,
    bool? urgent,
    bool? important,
    int? priorityOverride,
    bool clearPriorityOverride = false,
    TaskStatus? status,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      deadline: deadline ?? this.deadline,
      urgent: urgent ?? this.urgent,
      important: important ?? this.important,
      priorityOverride: clearPriorityOverride
          ? null
          : (priorityOverride ?? this.priorityOverride),
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

/// Registro usado pela regra de aprendizado R7.
class DurationRecord {
  const DurationRecord({
    required this.taskId,
    required this.type,
    required this.estimatedMinutes,
    required this.actualMinutes,
    required this.recordedAt,
  });

  final String taskId;
  final TaskType type;
  final int estimatedMinutes;
  final int actualMinutes;
  final DateTime recordedAt;

  double get ratio => actualMinutes / estimatedMinutes;
}

/// Preferências do usuário. Horários são guardados em minutos desde 00:00.
class Preferences {
  const Preferences({
    this.workStartMinutes = 7 * 60,
    this.workEndMinutes = 22 * 60,
    this.peakStartMinutes = 8 * 60,
    this.peakEndMinutes = 11 * 60,
    this.alpha = 1.0,
    this.beta = 0.5,
    this.nodeLimit = 50000,
    this.horizonDays = 2,
  });

  final int workStartMinutes;
  final int workEndMinutes;
  final int peakStartMinutes;
  final int peakEndMinutes;

  /// Peso da troca de tipo de tarefa (α na Seção 3.4).
  final double alpha;

  /// Peso de tarefa de foco fora do período de pico (β na Seção 3.4).
  final double beta;

  /// Limite de nós expandidos pelo A* antes de devolver a melhor agenda conhecida.
  final int nodeLimit;
  final int horizonDays;

  Preferences copyWith({
    int? workStartMinutes,
    int? workEndMinutes,
    int? peakStartMinutes,
    int? peakEndMinutes,
    double? alpha,
    double? beta,
    int? nodeLimit,
    int? horizonDays,
  }) {
    return Preferences(
      workStartMinutes: workStartMinutes ?? this.workStartMinutes,
      workEndMinutes: workEndMinutes ?? this.workEndMinutes,
      peakStartMinutes: peakStartMinutes ?? this.peakStartMinutes,
      peakEndMinutes: peakEndMinutes ?? this.peakEndMinutes,
      alpha: alpha ?? this.alpha,
      beta: beta ?? this.beta,
      nodeLimit: nodeLimit ?? this.nodeLimit,
      horizonDays: horizonDays ?? this.horizonDays,
    );
  }
}

/// Bloco de tempo reservado para (parte de) uma tarefa em um planejamento.
class Allocation {
  const Allocation({
    required this.taskId,
    required this.title,
    required this.start,
    required this.end,
    this.part = 1,
    this.partCount = 1,
  });

  final String taskId;
  final String title;
  final DateTime start;
  final DateTime end;
  final int part;
  final int partCount;

  String get displayTitle =>
      partCount > 1 ? '$title ($part/$partCount)' : title;
}

/// Planejamento aceito pelo usuário (entidade "Planejamento" + "Alocação").
class PlanRecord {
  const PlanRecord({
    required this.id,
    required this.createdAt,
    required this.algorithm,
    required this.totalCost,
    required this.totalTardinessMinutes,
    required this.elapsedMilliseconds,
    required this.expandedNodes,
    required this.optimal,
    required this.allocations,
    required this.unscheduledTaskIds,
  });

  final String id;
  final DateTime createdAt;
  final Algorithm algorithm;
  final double totalCost;
  final int totalTardinessMinutes;
  final double elapsedMilliseconds;
  final int expandedNodes;
  final bool optimal;
  final List<Allocation> allocations;
  final List<String> unscheduledTaskIds;
}
