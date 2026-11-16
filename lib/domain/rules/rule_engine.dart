import '../entities.dart';

/// Parâmetros das regras da Tabela 4. Os valores padrão são as hipóteses de
/// trabalho do Bloco 2.
class RuleConfig {
  const RuleConfig({
    this.urgencyFactor = 2.0,
    this.splitThresholdMinutes = 90,
    this.splitChunkMinutes = 60,
    this.historyRatioThreshold = 1.25,
    this.minHistoryRecords = 3,
  });

  /// R5: urgente quando (prazo - agora) < fator × duração.
  final double urgencyFactor;

  /// R6: tarefas com duração acima deste valor são divididas.
  final int splitThresholdMinutes;

  /// R6: tamanho máximo de cada bloco após a divisão.
  final int splitChunkMinutes;

  /// R7: razão média (real / estimada) a partir da qual a duração é corrigida.
  final double historyRatioThreshold;

  /// R7: quantidade mínima de registros do mesmo tipo de tarefa.
  final int minHistoryRecords;
}

/// Memória de trabalho do motor de inferência para uma tarefa.
class TaskFacts {
  TaskFacts({
    required this.task,
    required this.now,
    required this.history,
    required this.config,
  })  : urgent = task.urgent,
        important = task.important,
        adjustedMinutes = task.estimatedMinutes;

  final Task task;
  final DateTime now;

  /// Histórico de durações do mesmo tipo da tarefa.
  final List<DurationRecord> history;
  final RuleConfig config;

  bool urgent;
  bool important;
  int adjustedMinutes;
  int? priority;
  bool preferPeak = false;
  List<int> chunks = const [];
  double? correctionFactor;
}

class Rule {
  const Rule({
    required this.id,
    required this.condition,
    required this.conclusion,
    required this.salience,
    required this.when,
    required this.then,
  });

  final String id;

  /// Texto da condição, como na Tabela 4.
  final String condition;

  /// Texto da conclusão, como na Tabela 4.
  final String conclusion;

  /// Regras com saliência maior disparam primeiro quando mais de uma está ativa.
  final int salience;
  final bool Function(TaskFacts facts) when;

  /// Altera a memória de trabalho e devolve uma explicação para o usuário.
  final String Function(TaskFacts facts) then;
}

class RuleFiring {
  const RuleFiring(this.ruleId, this.explanation);
  final String ruleId;
  final String explanation;
}

/// Resultado da inferência para uma tarefa.
class RuleEvaluation {
  const RuleEvaluation({
    required this.suggestedPriority,
    required this.priority,
    required this.urgent,
    required this.important,
    required this.adjustedMinutes,
    required this.preferPeak,
    required this.chunks,
    required this.fired,
    this.correctionFactor,
  });

  /// Prioridade concluída pelas regras R1 a R4.
  final int suggestedPriority;

  /// Prioridade efetiva: a manual, quando existir, ou a sugerida.
  final int priority;
  final bool urgent;
  final bool important;
  final int adjustedMinutes;
  final bool preferPeak;

  /// Durações, em minutos, dos blocos em que a tarefa será executada.
  final List<int> chunks;
  final List<RuleFiring> fired;
  final double? correctionFactor;

  /// Peso w usado na função de custo.
  int get weight => priority;

  bool hasFired(String ruleId) => fired.any((f) => f.ruleId == ruleId);
}

int _roundUpToQuarter(double minutes) => ((minutes / 15).ceil() * 15);

String _fmtFactor(double value) => value.toStringAsFixed(2).replaceAll('.', ',');

/// Base de conhecimento SE-ENTÃO (Tabela 4 do Bloco 2).
List<Rule> standardRules() => [
      Rule(
        id: 'R7',
        condition:
            'Média histórica de duração real ≥ 1,25 × estimada (mínimo de 3 registros)',
        conclusion: 'Multiplicar a duração estimada pelo fator observado',
        salience: 100,
        when: (f) {
          if (f.history.length < f.config.minHistoryRecords) return false;
          final mean =
              f.history.map((r) => r.ratio).reduce((a, b) => a + b) / f.history.length;
          return mean >= f.config.historyRatioThreshold;
        },
        then: (f) {
          final mean =
              f.history.map((r) => r.ratio).reduce((a, b) => a + b) / f.history.length;
          final before = f.adjustedMinutes;
          f.correctionFactor = mean;
          f.adjustedMinutes = _roundUpToQuarter(before * mean);
          return 'Nas últimas ${f.history.length} tarefas do tipo '
              '${f.task.type.label.toLowerCase()}, a duração real foi em média '
              '${_fmtFactor(mean)}× a estimada; duração ajustada de $before para '
              '${f.adjustedMinutes} min.';
        },
      ),
      Rule(
        id: 'R5',
        condition: 'prazo − agora < 2 × duração',
        conclusion: 'Marcar a tarefa como urgente',
        salience: 90,
        when: (f) {
          if (f.urgent) return false;
          final remaining = f.task.deadline.difference(f.now).inMinutes;
          return remaining < f.config.urgencyFactor * f.adjustedMinutes;
        },
        then: (f) {
          f.urgent = true;
          final remaining = f.task.deadline.difference(f.now).inMinutes;
          final text = remaining <= 0
              ? 'o prazo já passou'
              : 'faltam $remaining min para o prazo';
          return 'Marcada como urgente: $text, menos que '
              '${_fmtFactor(f.config.urgencyFactor)} × ${f.adjustedMinutes} min.';
        },
      ),
      Rule(
        id: 'R1',
        condition: 'Tarefa urgente E importante',
        conclusion: 'Prioridade 4 (peso alto)',
        salience: 50,
        when: (f) => f.priority == null && f.urgent && f.important,
        then: (f) {
          f.priority = 4;
          return 'Urgente e importante: prioridade 4.';
        },
      ),
      Rule(
        id: 'R2',
        condition: 'Tarefa importante E não urgente',
        conclusion: 'Prioridade 3; preferir horário de pico do usuário',
        salience: 50,
        when: (f) => f.priority == null && !f.urgent && f.important,
        then: (f) {
          f.priority = 3;
          f.preferPeak = true;
          return 'Importante e não urgente: prioridade 3, de preferência no '
              'horário de pico.';
        },
      ),
      Rule(
        id: 'R3',
        condition: 'Tarefa urgente E não importante',
        conclusion: 'Prioridade 2',
        salience: 50,
        when: (f) => f.priority == null && f.urgent && !f.important,
        then: (f) {
          f.priority = 2;
          return 'Urgente, mas não importante: prioridade 2.';
        },
      ),
      Rule(
        id: 'R4',
        condition: 'Tarefa nem urgente nem importante',
        conclusion: 'Prioridade 1',
        salience: 50,
        when: (f) => f.priority == null && !f.urgent && !f.important,
        then: (f) {
          f.priority = 1;
          return 'Nem urgente nem importante: prioridade 1.';
        },
      ),
      Rule(
        id: 'R6',
        condition: 'duração > 90 min',
        conclusion: 'Dividir em blocos menores, com pausa entre eles',
        salience: 40,
        when: (f) => f.chunks.isEmpty && f.adjustedMinutes > f.config.splitThresholdMinutes,
        then: (f) {
          final size = f.config.splitChunkMinutes;
          final parts = <int>[];
          var left = f.adjustedMinutes;
          while (left > 0) {
            final part = left >= size ? size : left;
            parts.add(part);
            left -= part;
          }
          f.chunks = parts;
          return 'Duração de ${f.adjustedMinutes} min dividida em '
              '${parts.length} blocos (${parts.join(' + ')} min), com pausa de '
              '15 min entre eles.';
        },
      ),
    ];

/// Motor de inferência com encadeamento para frente.
///
/// A cada ciclo, o motor procura as regras cuja condição é verdadeira e que
/// ainda não dispararam, escolhe a de maior saliência e executa sua
/// conclusão. O ciclo termina quando nenhuma regra nova pode disparar.
class RuleEngine {
  RuleEngine({List<Rule>? rules, this.config = const RuleConfig()})
      : rules = List.unmodifiable(rules ?? standardRules());

  final List<Rule> rules;
  final RuleConfig config;

  RuleEvaluation evaluate(
    Task task, {
    required DateTime now,
    Iterable<DurationRecord> history = const [],
  }) {
    final facts = TaskFacts(
      task: task,
      now: now,
      history: history.where((r) => r.type == task.type).toList(),
      config: config,
    );
    final fired = <RuleFiring>[];
    final firedIds = <String>{};

    while (true) {
      Rule? next;
      for (final rule in rules) {
        if (firedIds.contains(rule.id) || !rule.when(facts)) continue;
        if (next == null || rule.salience > next.salience) next = rule;
      }
      if (next == null) break;
      firedIds.add(next.id);
      fired.add(RuleFiring(next.id, next.then(facts)));
    }

    final suggested = facts.priority ?? 1;
    final chunks = facts.chunks.isEmpty ? [facts.adjustedMinutes] : facts.chunks;
    return RuleEvaluation(
      suggestedPriority: suggested,
      priority: task.priorityOverride ?? suggested,
      urgent: facts.urgent,
      important: facts.important,
      adjustedMinutes: facts.adjustedMinutes,
      preferPeak: facts.preferPeak || task.type == TaskType.foco,
      chunks: List.unmodifiable(chunks),
      fired: List.unmodifiable(fired),
      correctionFactor: facts.correctionFactor,
    );
  }
}
