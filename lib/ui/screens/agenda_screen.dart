import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities.dart';
import '../../state/agenda_controller.dart';
import '../format.dart';
import '../navigation.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/timeline.dart';

/// T1 — Agenda do dia: visão geral e ponto de partida.
class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key});

  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  int _dayOffset = 0;

  @override
  Widget build(BuildContext context) {
    final agenda = ref.watch(agendaProvider);
    final now = ref.watch(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(today.year, today.month, today.day + _dayOffset);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= Breakpoints.expanded;

    final timeline = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              fmtRelativeDay(day, now),
              subtitle:
                  '${fmtDayLabel(day)} · expediente ${fmtMinutesOfDay(agenda.preferences.workStartMinutes)}–${fmtMinutesOfDay(agenda.preferences.workEndMinutes)}',
            ),
            DayTimeline(day: day, agenda: agenda, now: now),
          ],
        ),
      ),
    );

    final side = [
      if (agenda.conflicts.isNotEmpty) _ConflictBanner(count: agenda.conflicts.length),
      _PlanSummary(agenda: agenda, now: now),
      _PendingTasks(agenda: agenda, now: now),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              key: const Key('plan-button'),
              onPressed: () => openPlanConfig(context),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Planejar'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-agenda',
        onPressed: () => openNewItemSheet(context, day: day),
        icon: const Icon(Icons.add),
        label: const Text('Novo'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _DaySelector(
                  today: today,
                  selected: _dayOffset,
                  agenda: agenda,
                  onSelected: (o) => setState(() => _dayOffset = o),
                ),
                const SizedBox(height: 12),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: timeline),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _spaced(side),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _spaced([...side.take(side.length - 1), timeline, side.last]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _spaced(List<Widget> items) => [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          items[i],
        ],
      ];
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.today,
    required this.selected,
    required this.agenda,
    required this.onSelected,
  });

  final DateTime today;
  final int selected;
  final AgendaState agenda;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, offset) {
          final day = DateTime(today.year, today.month, today.day + offset);
          final busy = agenda.allocations.where((a) => sameDay(a.start, day)).length +
              agenda.events.where((e) => sameDay(e.start, day)).length;
          final isSelected = offset == selected;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelected(offset),
            child: Container(
              width: 62,
              decoration: BoxDecoration(
                color: isSelected ? scheme.primary : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    offset == 0 ? 'hoje' : fmtWeekday(day),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    '${day.day}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected ? scheme.onPrimary : scheme.onSurface,
                        ),
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: busy == 0
                          ? Colors.transparent
                          : (isSelected ? scheme.onPrimary : scheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConflictBanner extends ConsumerWidget {
  const _ConflictBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: ListTile(
        leading: Icon(Icons.warning_amber, color: scheme.onErrorContainer),
        title: Text(
          count == 1 ? '1 conflito entre compromissos' : '$count conflitos entre compromissos',
          style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w700),
        ),
        subtitle: Text('Toque para revisar antes de planejar.',
            style: TextStyle(color: scheme.onErrorContainer)),
        trailing: Icon(Icons.chevron_right, color: scheme.onErrorContainer),
        onTap: () => ref.read(shellIndexProvider.notifier).select(2),
      ),
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.agenda, required this.now});
  final AgendaState agenda;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final plan = agenda.currentPlan;
    final open = agenda.tasks.where((t) => t.status.isOpen).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: plan == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('Nenhuma agenda aceita',
                      subtitle: 'Gere uma agenda para distribuir as tarefas nos horários livres.'),
                  Text('$open tarefa(s) aguardando planejamento.'),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    'Agenda atual · ${plan.algorithm.label}',
                    subtitle: 'Gerada ${fmtDateTime(plan.createdAt, now).toLowerCase()}',
                    trailing: plan.optimal
                        ? const Chip(label: Text('Ótima'), visualDensity: VisualDensity.compact)
                        : null,
                  ),
                  MetricGrid(minTileWidth: 110, children: [
                    MetricTile(label: 'Custo', value: fmtNumber(plan.totalCost)),
                    MetricTile(label: 'Atraso', value: fmtDuration(plan.totalTardinessMinutes)),
                    MetricTile(label: 'Nós', value: '${plan.expandedNodes}'),
                  ]),
                  if (plan.unscheduledTaskIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '${plan.unscheduledTaskIds.length} tarefa(s) não couberam no horizonte.',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _PendingTasks extends ConsumerWidget {
  const _PendingTasks({required this.agenda, required this.now});
  final AgendaState agenda;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(agendaProvider.notifier);
    final pending = agenda.tasks
        .where((t) => t.status == TaskStatus.pendente || t.status == TaskStatus.atrasada)
        .toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader('Fora da agenda',
                  subtitle: pending.isEmpty
                      ? 'Todas as tarefas abertas estão alocadas.'
                      : 'Tarefas pendentes ou atrasadas, por prazo.'),
            ),
            for (final t in pending.take(6))
              ListTile(
                dense: true,
                title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('Prazo ${fmtDateTime(t.deadline, now).toLowerCase()}'),
                trailing: PriorityBadge(controller.evaluate(t).priority, compact: true),
                onTap: () => openTaskDetail(context, t.id),
              ),
            if (pending.length > 6)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('+ ${pending.length - 6} tarefa(s)'),
              ),
          ],
        ),
      ),
    );
  }
}
