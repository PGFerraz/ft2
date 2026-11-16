import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/conflicts.dart';
import '../../domain/entities.dart';
import '../../state/agenda_controller.dart';
import '../format.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

/// T2 — Novo compromisso / edição. Avisa sobre conflitos enquanto o usuário
/// escolhe o horário.
class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.event, this.initialDay});

  final FixedEvent? event;
  final DateTime? initialDay;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _location;
  late DateTime _day;
  late TimeOfDay _start;
  late TimeOfDay _end;
  bool _saving = false;

  bool get _editing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    final now = ref.read(clockProvider)();
    final day = e?.start ?? widget.initialDay ?? now;
    _day = DateTime(day.year, day.month, day.day);
    _title = TextEditingController(text: e?.title ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    if (e != null) {
      _start = TimeOfDay(hour: e.start.hour, minute: e.start.minute);
      _end = TimeOfDay(hour: e.end.hour, minute: e.end.minute);
    } else {
      final next = roundToQuarter(TimeOfDay(hour: (now.hour + 1).clamp(0, 22), minute: 0));
      _start = next;
      _end = TimeOfDay(hour: (next.hour + 1).clamp(0, 23), minute: next.minute);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay t) => DateTime(_day.year, _day.month, _day.day, t.hour, t.minute);

  bool get _validRange => _at(_end).isAfter(_at(_start));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_validRange) {
      setState(() {});
      return;
    }
    setState(() => _saving = true);
    final event = FixedEvent(
      id: widget.event?.id ?? newId('compromisso'),
      title: _title.text.trim(),
      start: _at(_start),
      end: _at(_end),
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
    );
    await ref.read(agendaProvider.notifier).saveEvent(event);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir compromisso?'),
        content: Text('"${widget.event!.title}" será removido.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(agendaProvider.notifier).deleteEvent(widget.event!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(agendaProvider.select((s) => s.events));
    final clashes = _validRange
        ? events
            .where((e) => e.id != widget.event?.id && overlaps(_at(_start), _at(_end), e.start, e.end))
            .toList()
        : const <FixedEvent>[];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar compromisso' : 'Novo compromisso'),
        actions: [
          if (_editing)
            IconButton(
                tooltip: 'Excluir', onPressed: _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
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
                    key: const Key('event-title'),
                    controller: _title,
                    autofocus: !_editing,
                    maxLength: 80,
                    decoration: const InputDecoration(
                        labelText: 'Título', hintText: 'Ex.: Aula de Inteligência Artificial'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Informe um título.' : null,
                  ),
                  const SizedBox(height: 8),
                  DateField(label: 'Dia', value: _day, onChanged: (d) => setState(() => _day = d)),
                  const SizedBox(height: 16),
                  FieldPair(
                    first: TimeField(
                        label: 'Início', value: _start, onChanged: (t) => setState(() => _start = t)),
                    second: TimeField(
                        label: 'Fim', value: _end, onChanged: (t) => setState(() => _end = t)),
                  ),
                  if (!_validRange)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('O fim precisa ser depois do início.',
                          style: TextStyle(color: scheme.error)),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _location,
                    decoration: const InputDecoration(labelText: 'Local (opcional)'),
                  ),
                  if (clashes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: scheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Este horário conflita com:',
                                style: TextStyle(
                                    color: scheme.onErrorContainer, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            for (final c in clashes)
                              Text('• ${c.title} (${fmtTime(c.start)}–${fmtTime(c.end)})',
                                  style: TextStyle(color: scheme.onErrorContainer)),
                            const SizedBox(height: 6),
                            Text('Você pode salvar mesmo assim; o conflito aparecerá na aba Conflitos.',
                                style: TextStyle(color: scheme.onErrorContainer)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('event-save'),
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check),
                    label: Text(_editing ? 'Salvar alterações' : 'Adicionar compromisso'),
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
