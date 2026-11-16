import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/conflicts.dart';
import '../../domain/entities.dart';
import '../../state/agenda_controller.dart';
import '../format.dart';
import '../navigation.dart';
import '../theme.dart';
import 'common.dart';

/// Linha do tempo da agenda aceita para um dia (usada na tela T1).
class DayTimeline extends ConsumerWidget {
  const DayTimeline({super.key, required this.day, required this.agenda, required this.now});

  final DateTime day;
  final AgendaState agenda;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(agendaProvider.notifier);
    return TimelineList(
      day: day,
      events: agenda.events,
      allocations: agenda.allocations,
      preferences: agenda.preferences,
      priorityOf: (taskId) {
        final t = agenda.taskById(taskId);
        return t == null ? 1 : controller.evaluate(t).priority;
      },
      statusOf: (taskId) => agenda.taskById(taskId)?.status,
      onTapAllocation: (a) => openTaskDetail(context, a.taskId),
      onTapEvent: (e) => openEventForm(context, event: e),
      emptyMessage: agenda.currentPlan == null
          ? 'Toque em "Planejar" para o agente distribuir suas tarefas.'
          : 'Nada alocado neste dia.',
    );
  }
}

class _Entry {
  _Entry.event(FixedEvent this.event)
      : allocation = null,
        start = event.start,
        end = event.end;
  _Entry.allocation(Allocation this.allocation)
      : event = null,
        start = allocation.start,
        end = allocation.end;

  final FixedEvent? event;
  final Allocation? allocation;
  final DateTime start;
  final DateTime end;
}

/// Lista cronológica de compromissos e alocações de um dia, com os
/// intervalos livres do expediente entre eles.
class TimelineList extends StatelessWidget {
  const TimelineList({
    super.key,
    required this.day,
    required this.events,
    required this.allocations,
    required this.preferences,
    required this.priorityOf,
    this.statusOf,
    this.onTapAllocation,
    this.onTapEvent,
    this.emptyMessage = 'Nada neste dia.',
    this.showFree = true,
    this.lateTaskIds = const {},
  });

  final DateTime day;
  final List<FixedEvent> events;
  final List<Allocation> allocations;
  final Preferences preferences;
  final int Function(String taskId) priorityOf;
  final TaskStatus? Function(String taskId)? statusOf;
  final ValueChanged<Allocation>? onTapAllocation;
  final ValueChanged<FixedEvent>? onTapEvent;
  final String emptyMessage;
  final bool showFree;
  final Set<String> lateTaskIds;

  @override
  Widget build(BuildContext context) {
    final dayEvents = events.where((e) => sameDay(e.start, day)).toList();
    final conflicting = {
      for (final c in detectConflicts(dayEvents)) ...[c.first.id, c.second.id],
    };
    final entries = [
      for (final e in dayEvents) _Entry.event(e),
      for (final a in allocations)
        if (sameDay(a.start, day)) _Entry.allocation(a),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final workStart = DateTime(day.year, day.month, day.day)
        .add(Duration(minutes: preferences.workStartMinutes));
    final workEnd = DateTime(day.year, day.month, day.day)
        .add(Duration(minutes: preferences.workEndMinutes));

    final children = <Widget>[];
    var cursor = workStart;
    void addFree(DateTime until) {
      if (!showFree) return;
      if (until.difference(cursor).inMinutes >= 15) {
        children.add(_FreeRow(start: cursor, end: until));
      }
    }

    for (final entry in entries) {
      if (entry.start.isAfter(cursor)) addFree(entry.start.isBefore(workEnd) ? entry.start : workEnd);
      if (entry.event != null) {
        children.add(_EventRow(
          event: entry.event!,
          conflict: conflicting.contains(entry.event!.id),
          onTap: onTapEvent,
        ));
      } else {
        final a = entry.allocation!;
        children.add(_AllocationRow(
          allocation: a,
          priority: priorityOf(a.taskId),
          status: statusOf?.call(a.taskId),
          late: lateTaskIds.contains(a.taskId),
          onTap: onTapAllocation,
        ));
      }
      if (entry.end.isAfter(cursor)) cursor = entry.end;
    }
    if (cursor.isBefore(workEnd)) addFree(workEnd);

    if (entries.isEmpty) {
      return EmptyState(icon: Icons.event_available, title: 'Dia livre', message: emptyMessage);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          children[i],
        ],
      ],
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn(this.start, this.end);
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    return SizedBox(
      width: 52,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(fmtTime(start), style: style), Text(fmtTime(end), style: style)],
      ),
    );
  }
}

class _FreeRow extends StatelessWidget {
  const _FreeRow({required this.start, required this.end});
  final DateTime start;
  final DateTime end;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        _TimeColumn(start, end),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text('Livre · ${fmtDuration(end.difference(start).inMinutes)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.conflict, this.onTap});
  final FixedEvent event;
  final bool conflict;
  final ValueChanged<FixedEvent>? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimeColumn(event.start, event.end),
        Expanded(
          child: Material(
            color: conflict ? scheme.errorContainer : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap == null ? null : () => onTap!(event),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(conflict ? Icons.warning_amber : Icons.lock_clock,
                        size: 18,
                        color: conflict ? scheme.onErrorContainer : scheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.title,
                              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            [
                              conflict ? 'Compromisso em conflito' : 'Compromisso fixo',
                              if (event.location != null && event.location!.isNotEmpty)
                                event.location!,
                            ].join(' · '),
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({
    required this.allocation,
    required this.priority,
    required this.status,
    required this.late,
    this.onTap,
  });

  final Allocation allocation;
  final int priority;
  final TaskStatus? status;
  final bool late;
  final ValueChanged<Allocation>? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = priorityColors(context, priority);
    final text = Theme.of(context).textTheme;
    final done = status == TaskStatus.concluida;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimeColumn(allocation.start, allocation.end),
        Expanded(
          child: Material(
            color: colors.background,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap == null ? null : () => onTap!(allocation),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: colors.foreground, width: 4)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            allocation.displayTitle,
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              decoration: done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          Text(
                            [
                              fmtDuration(allocation.end.difference(allocation.start).inMinutes),
                              if (late) 'termina após o prazo',
                              if (done) 'concluída',
                            ].join(' · '),
                            style: text.bodySmall?.copyWith(
                                color: late ? Theme.of(context).colorScheme.error : null),
                          ),
                        ],
                      ),
                    ),
                    PriorityBadge(priority, compact: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
