import 'package:flutter/material.dart';

import '../../domain/rules/rule_engine.dart';
import '../format.dart';
import 'common.dart';

/// Mostra o raciocínio da base de regras: quais regras dispararam e por quê.
class RuleExplanationCard extends StatelessWidget {
  const RuleExplanationCard({
    super.key,
    required this.evaluation,
    required this.estimatedMinutes,
    this.title = 'Raciocínio do agente',
  });

  final RuleEvaluation evaluation;
  final int estimatedMinutes;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final adjusted = evaluation.adjustedMinutes != estimatedMinutes;
    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title,
                        style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                PriorityBadge(evaluation.suggestedPriority),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Fact(evaluation.urgent ? 'Urgente' : 'Não urgente'),
                _Fact(evaluation.important ? 'Importante' : 'Não importante'),
                _Fact(adjusted
                    ? 'Duração: ${fmtDuration(evaluation.adjustedMinutes)} (ajustada)'
                    : 'Duração: ${fmtDuration(evaluation.adjustedMinutes)}'),
                if (evaluation.chunks.length > 1)
                  _Fact('${evaluation.chunks.length} blocos'),
                if (evaluation.preferPeak) const _Fact('Prefere horário de pico'),
              ],
            ),
            const SizedBox(height: 12),
            for (final f in evaluation.fired)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(f.ruleId,
                          style: text.labelSmall?.copyWith(
                              color: scheme.onSecondaryContainer, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f.explanation, style: text.bodySmall)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
