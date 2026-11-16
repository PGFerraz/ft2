import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities.dart';
import '../../domain/rules/rule_engine.dart';
import '../../state/agenda_controller.dart';
import '../format.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import '../widgets/rule_explanation.dart';

/// T2 — Nova tarefa / edição, com sugestão automática de prioridade.
class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.task});
  final Task? task;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  static const _durations = [15, 30, 45, 60, 75, 90, 120, 150, 180, 240];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late TaskType _type;
  late int _minutes;
  late DateTime _deadlineDay;
  late TimeOfDay _deadlineTime;
  late bool _urgent;
  late bool _important;
  int? _override;
  bool _saving = false;

  bool get _editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    final now = ref.read(clockProvider)();
    final defaultDeadline = DateTime(now.year, now.month, now.day + 1, 18);
    _title = TextEditingController(text: t?.title ?? '');
    _type = t?.type ?? TaskType.foco;
    _minutes = t?.estimatedMinutes ?? 60;
    final deadline = t?.deadline ?? defaultDeadline;
    _deadlineDay = DateTime(deadline.year, deadline.month, deadline.day);
    _deadlineTime = TimeOfDay(hour: deadline.hour, minute: deadline.minute);
    _urgent = t?.urgent ?? false;
    _important = t?.important ?? false;
    _override = t?.priorityOverride;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  DateTime get _deadline => DateTime(_deadlineDay.year, _deadlineDay.month, _deadlineDay.day,
      _deadlineTime.hour, _deadlineTime.minute);

  Task _draft() {
    final now = ref.read(clockProvider)();
    final base = widget.task;
    return Task(
      id: base?.id ?? newId('tarefa'),
      title: _title.text.trim().isEmpty ? 'Nova tarefa' : _title.text.trim(),
      type: _type,
      estimatedMinutes: _minutes,
      deadline: _deadline,
      urgent: _urgent,
      important: _important,
      priorityOverride: _override,
      status: base?.status ?? TaskStatus.pendente,
      createdAt: base?.createdAt ?? now,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await ref.read(agendaProvider.notifier).saveTask(_draft());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Recalcula a sugestão a cada mudança no formulário.
    ref.watch(agendaProvider.select((s) => s.history.length));
    final RuleEvaluation evaluation = ref.read(agendaProvider.notifier).evaluate(
          _draft().copyWith(clearPriorityOverride: true),
        );
    final durations = {..._durations, _minutes}.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Editar tarefa' : 'Nova tarefa')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            ContentWidth(
              maxWidth: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('task-title'),
                    controller: _title,
                    autofocus: !_editing,
                    maxLength: 80,
                    decoration: const InputDecoration(
                        labelText: 'Título', hintText: 'Ex.: Revisar capítulo 3'),
                    textInputAction: TextInputAction.done,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Informe um título.' : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text('Tipo', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<TaskType>(
                    segments: const [
                      ButtonSegment(
                          value: TaskType.foco,
                          icon: Icon(Icons.psychology_alt_outlined),
                          label: Text('Foco')),
                      ButtonSegment(
                          value: TaskType.leve,
                          icon: Icon(Icons.bolt_outlined),
                          label: Text('Leve')),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() => _type = s.first),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _type == TaskType.foco
                        ? 'Exige concentração; o agente prefere o seu horário de pico.'
                        : 'Pode ser feita em qualquer horário.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _minutes,
                    decoration: const InputDecoration(labelText: 'Duração estimada'),
                    items: [
                      for (final m in durations)
                        DropdownMenuItem(value: m, child: Text(fmtDuration(m))),
                    ],
                    onChanged: (v) => setState(() => _minutes = v ?? _minutes),
                  ),
                  const SizedBox(height: 16),
                  FieldPair(
                    first: DateField(
                      label: 'Prazo · dia',
                      value: _deadlineDay,
                      onChanged: (d) => setState(() => _deadlineDay = d),
                    ),
                    second: TimeField(
                      label: 'Prazo · hora',
                      value: _deadlineTime,
                      onChanged: (t) => setState(() => _deadlineTime = t),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Urgente'),
                    subtitle: const Text('Precisa ser feita logo'),
                    value: _urgent,
                    onChanged: (v) => setState(() => _urgent = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Importante'),
                    subtitle: const Text('Contribui para os seus objetivos'),
                    value: _important,
                    onChanged: (v) => setState(() => _important = v),
                  ),
                  const SizedBox(height: 12),
                  RuleExplanationCard(
                    evaluation: evaluation,
                    estimatedMinutes: _minutes,
                    title: 'Sugestão do agente',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    initialValue: _override,
                    decoration: const InputDecoration(labelText: 'Prioridade'),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Automática (sugerida: P${evaluation.suggestedPriority})'),
                      ),
                      for (final p in [4, 3, 2, 1])
                        DropdownMenuItem<int?>(value: p, child: Text('Manual: P$p')),
                    ],
                    onChanged: (v) => setState(() => _override = v),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('task-save'),
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text(_editing ? 'Salvar alterações' : 'Adicionar tarefa'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
