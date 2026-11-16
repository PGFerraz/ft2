import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities.dart';
import '../../state/agenda_controller.dart';
import '../format.dart';
import '../navigation.dart';
import '../widgets/common.dart';
import '../widgets/rule_explanation.dart';

/// T7 — Detalhe da tarefa: concluir, marcar atraso e replanejar (RF08).
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agenda = ref.watch(agendaProvider);
    final task = agenda.taskById(taskId);
    final now = ref.watch(clockProvider)();
    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.search_off, title: 'Tarefa não encontrada'),
      );
    }
    final controller = ref.read(agendaProvider.notifier);
    final evaluation = controller.evaluate(task);
    final allocations = agenda.allocationsOf(task.id);
    final text = Theme.of(context).textTheme;
    final done = task.status == TaskStatus.concluida;

    Future<void> complete() async {
      final minutes = await showDialog<int>(
        context: context,
        builder: (_) => _ActualDurationDialog(initial: evaluation.adjustedMinutes),
      );
      if (minutes == null) return;
      await controller.completeTask(task.id, minutes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Concluída em ${fmtDuration(minutes)}. O histórico alimenta a regra R7.'),
        ));
      }
    }

    Future<void> delete() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Excluir tarefa?'),
          content: Text('"${task.title}" e suas alocações serão removidas.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
          ],
        ),
      );
      if (ok != true) return;
      await controller.deleteTask(task.id);
      if (context.mounted) Navigator.of(context).pop();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarefa'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            onPressed: () => openTaskForm(context, task: task),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(tooltip: 'Excluir', onPressed: delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          ContentWidth(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(task.title, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  StatusChip(task.status),
                  PriorityBadge(evaluation.priority),
                  if (task.priorityOverride != null) const Chip(label: Text('Prioridade manual')),
                ]),
                const SizedBox(height: 16),
                MetricGrid(minTileWidth: 150, children: [
                  MetricTile(label: 'Tipo', value: task.type.label),
                  MetricTile(label: 'Estimativa', value: fmtDuration(task.estimatedMinutes)),
                  MetricTile(label: 'Planejada com', value: fmtDuration(evaluation.adjustedMinutes)),
                  MetricTile(label: 'Prazo', value: fmtDateTime(task.deadline, now)),
                ]),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader('Na agenda'),
                        if (allocations.isEmpty)
                          Text(done
                              ? 'Tarefa concluída.'
                              : 'Ainda não alocada. Gere uma agenda para encaixá-la.')
                        else
                          for (final a in allocations)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.schedule),
                              title: Text('${fmtRelativeDay(a.start, now)}, '
                                  '${fmtTime(a.start)}–${fmtTime(a.end)}'),
                              subtitle: a.partCount > 1 ? Text('Bloco ${a.part} de ${a.partCount}') : null,
                              trailing: a.end.isAfter(task.deadline)
                                  ? Text('após o prazo',
                                      style: TextStyle(color: Theme.of(context).colorScheme.error))
                                  : null,
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                RuleExplanationCard(evaluation: evaluation, estimatedMinutes: task.estimatedMinutes),
                const SizedBox(height: 24),
                if (done)
                  OutlinedButton.icon(
                    onPressed: () => controller.reopenTask(task.id),
                    icon: const Icon(Icons.undo),
                    label: const Text('Reabrir tarefa'),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        key: const Key('complete-task'),
                        onPressed: complete,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Concluir'),
                      ),
                      OutlinedButton.icon(
                        onPressed: task.status == TaskStatus.atrasada
                            ? null
                            : () => controller.markLate(task.id),
                        icon: const Icon(Icons.running_with_errors),
                        label: const Text('Marcar como atrasada'),
                      ),
                      FilledButton.tonalIcon(
                        key: const Key('replan'),
                        onPressed: () => openPlanConfig(context),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Replanejar'),
                      ),
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

class _ActualDurationDialog extends StatefulWidget {
  const _ActualDurationDialog({required this.initial});
  final int initial;

  @override
  State<_ActualDurationDialog> createState() => _ActualDurationDialogState();
}

class _ActualDurationDialogState extends State<_ActualDurationDialog> {
  late int _minutes = widget.initial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quanto tempo levou?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('A duração real ajuda o agente a corrigir estimativas futuras (R7).'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                onPressed: _minutes > 15 ? () => setState(() => _minutes -= 15) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 110,
                child: Text(fmtDuration(_minutes),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton.outlined(
                onPressed: () => setState(() => _minutes += 15),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
            key: const Key('confirm-duration'),
            onPressed: () => Navigator.pop(context, _minutes),
            child: const Text('Registrar')),
      ],
    );
  }
}
