import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/planning/planner_service.dart';
import '../../state/agenda_controller.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/timeline.dart';

/// T6 — Resultado e comparação: agendas lado a lado e aceite.
class PlanResultScreen extends ConsumerWidget {
  const PlanResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcomes = ref.watch(planningProvider).outcomes;
    final width = MediaQuery.sizeOf(context).width;
    if (outcomes.isEmpty) {
      return Scaffold(
          appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, title: 'Sem resultado'));
    }

    final columns = [for (final o in outcomes) _OutcomeColumn(outcome: o)];
    final summary = outcomes.length == 2 ? _ComparisonSummary(outcomes[0], outcomes[1]) : null;

    if (outcomes.length == 2 && width < Breakpoints.expanded) {
      return DefaultTabController(
        length: 2,
        initialIndex: 1,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Resultado'),
            bottom: TabBar(tabs: [for (final o in outcomes) Tab(text: o.algorithm.label)]),
          ),
          body: Column(
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: summary),
              Expanded(
                child: TabBarView(children: [
                  for (final c in columns)
                    ListView(padding: const EdgeInsets.all(16), children: [c]),
                ]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          ContentWidth(
            maxWidth: 1200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (summary != null) ...[summary, const SizedBox(height: 16)],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < columns.length; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      Expanded(child: columns[i]),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonSummary extends StatelessWidget {
  const _ComparisonSummary(this.greedy, this.astar);
  final PlanOutcome greedy;
  final PlanOutcome astar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final diff = greedy.cost - astar.cost;
    final String message;
    if (astar.search.fellBackToGreedy) {
      message = 'O problema tem mais blocos do que o limite do A*; as duas agendas são iguais.';
    } else if (diff > 1e-9) {
      final pct = greedy.cost == 0 ? 0 : diff / greedy.cost * 100;
      message = 'O A* reduziu o custo em ${fmtNumber(diff)} (${fmtNumber(pct.toDouble())}%) '
          'explorando ${astar.search.expanded} estados.';
    } else {
      message = 'Neste cenário a busca gulosa já encontrou uma agenda de custo mínimo.';
    }
    return Card(
      color: scheme.secondaryContainer,
      child: ListTile(
        leading: Icon(Icons.compare_arrows, color: scheme.onSecondaryContainer),
        title: Text(message, style: TextStyle(color: scheme.onSecondaryContainer)),
      ),
    );
  }
}

class _OutcomeColumn extends ConsumerWidget {
  const _OutcomeColumn({required this.outcome});
  final PlanOutcome outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(agendaProvider);
    final now = ref.watch(clockProvider)();
    final search = outcome.search;
    final built = outcome.built;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final taskCount = built.tasks.length;
    final scheduledTasks = taskCount - outcome.unscheduledTaskIds.length;

    final days = <DateTime>[];
    for (final a in outcome.allocations) {
      final d = DateTime(a.start.year, a.start.month, a.start.day);
      if (!days.any((x) => sameDay(x, d))) days.add(d);
    }

    final badge = search.fellBackToGreedy
        ? 'Recorreu à gulosa'
        : search.hitNodeLimit
            ? 'Limite de nós atingido'
            : search.optimal
                ? 'Custo mínimo garantido'
                : 'Sem garantia de ótimo';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              outcome.algorithm.label,
              subtitle: 'A partir de ${fmtDateTime(built.start, now).toLowerCase()}',
              trailing: Chip(label: Text(badge), visualDensity: VisualDensity.compact),
            ),
            MetricGrid(minTileWidth: 120, children: [
              MetricTile(label: 'Custo total', value: fmtNumber(outcome.cost), highlight: true),
              MetricTile(label: 'Atraso total', value: fmtDuration(outcome.totalTardinessMinutes)),
              MetricTile(label: 'Tempo', value: fmtMs(outcome.elapsedMilliseconds)),
              MetricTile(label: 'Nós expandidos', value: '${search.expanded}'),
              MetricTile(label: 'Tarefas alocadas', value: '$scheduledTasks/$taskCount'),
            ]),
            const SizedBox(height: 16),
            if (outcome.unscheduledTaskIds.isNotEmpty)
              Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Não couberam no horizonte:',
                          style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w700)),
                      for (final id in outcome.unscheduledTaskIds)
                        Text('• ${built.tasks[id]?.title ?? id}',
                            style: TextStyle(color: scheme.onErrorContainer)),
                      const SizedBox(height: 4),
                      Text('Aumente o horizonte ou o expediente em Preferências.',
                          style: text.bodySmall?.copyWith(color: scheme.onErrorContainer)),
                    ],
                  ),
                ),
              ),
            for (final day in days) ...[
              const SizedBox(height: 8),
              Text(fmtRelativeDay(day, now), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TimelineList(
                day: day,
                events: agenda.events,
                allocations: outcome.allocations,
                preferences: agenda.preferences,
                priorityOf: (id) => built.evaluations[id]?.priority ?? 1,
                lateTaskIds: outcome.lateTaskIds,
                showFree: false,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              key: Key('accept-${outcome.algorithm.name}'),
              onPressed: () async {
                await ref.read(agendaProvider.notifier).acceptPlan(outcome);
                if (context.mounted) Navigator.of(context).pop(true);
              },
              icon: const Icon(Icons.check),
              label: Text('Aceitar agenda ${outcome.algorithm.label}'),
            ),
          ],
        ),
      ),
    );
  }
}
