import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities.dart';
import '../../state/agenda_controller.dart';
import '../format.dart';
import '../navigation.dart';
import '../widgets/common.dart';

/// T3 — Lista de tarefas, com filtros por status e prioridade.
class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  TaskStatus? _status;
  int? _priority;
  bool _hideDone = true;

  @override
  Widget build(BuildContext context) {
    final agenda = ref.watch(agendaProvider);
    final controller = ref.read(agendaProvider.notifier);
    final now = ref.watch(clockProvider)();

    final items = [
      for (final t in agenda.tasks) (task: t, eval: controller.evaluate(t)),
    ].where((i) {
      if (_status != null && i.task.status != _status) return false;
      if (_status == null && _hideDone && i.task.status == TaskStatus.concluida) return false;
      if (_priority != null && i.eval.priority != _priority) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final byPriority = b.eval.priority.compareTo(a.eval.priority);
        return byPriority != 0 ? byPriority : a.task.deadline.compareTo(b.task.deadline);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Tarefas')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-tasks',
        onPressed: () => openTaskForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova tarefa'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          ContentWidth(
            maxWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final s in [null, ...TaskStatus.values])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s?.label ?? 'Abertas'),
                            selected: _status == s,
                            onSelected: (_) => setState(() => _status = s),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final p in [null, 4, 3, 2, 1])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(p == null ? 'Todas as prioridades' : 'P$p'),
                            selected: _priority == p,
                            onSelected: (_) => setState(() => _priority = p),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_status == null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Ocultar concluídas'),
                    value: _hideDone,
                    onChanged: (v) => setState(() => _hideDone = v),
                  ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  EmptyState(
                    icon: Icons.checklist,
                    title: agenda.tasks.isEmpty ? 'Nenhuma tarefa cadastrada' : 'Nenhuma tarefa neste filtro',
                    message: agenda.tasks.isEmpty
                        ? 'Cadastre tarefas ou carregue o cenário de demonstração em Preferências.'
                        : null,
                  )
                else
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          ListTile(
                            onTap: () => openTaskDetail(context, items[i].task.id),
                            leading: Icon(items[i].task.type == TaskType.foco
                                ? Icons.psychology_alt_outlined
                                : Icons.bolt_outlined),
                            title: Text(
                              items[i].task.title,
                              style: items[i].task.status == TaskStatus.concluida
                                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                                  : null,
                            ),
                            subtitle: Text(
                              '${fmtDuration(items[i].eval.adjustedMinutes)} · prazo '
                              '${fmtDateTime(items[i].task.deadline, now).toLowerCase()}',
                            ),
                            trailing: Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                StatusChip(items[i].task.status),
                                PriorityBadge(items[i].eval.priority, compact: true),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
