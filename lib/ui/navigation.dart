import 'package:flutter/material.dart';

import '../domain/entities.dart';
import 'screens/event_form_screen.dart';
import 'screens/plan_config_screen.dart';
import 'screens/task_detail_screen.dart';
import 'screens/task_form_screen.dart';

Future<void> openTaskForm(BuildContext context, {Task? task}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)));

Future<void> openEventForm(BuildContext context, {FixedEvent? event, DateTime? day}) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EventFormScreen(event: event, initialDay: day)));

Future<void> openTaskDetail(BuildContext context, String taskId) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: taskId)));

Future<void> openPlanConfig(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlanConfigScreen()));

/// Pergunta se o usuário quer cadastrar uma tarefa ou um compromisso (T2).
Future<void> openNewItemSheet(BuildContext context, {DateTime? day}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.task_alt),
            title: const Text('Nova tarefa'),
            subtitle: const Text('O agente decide quando ela será feita'),
            onTap: () => Navigator.pop(context, 'task'),
          ),
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('Novo compromisso'),
            subtitle: const Text('Horário fixo, que não pode ser movido'),
            onTap: () => Navigator.pop(context, 'event'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (choice == 'task') {
    await openTaskForm(context);
  } else if (choice == 'event') {
    await openEventForm(context, day: day);
  }
}
