import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities.dart';
import '../../state/agenda_controller.dart';
import '../format.dart';
import '../navigation.dart';
import '../widgets/common.dart';

/// T4 — Alertas de conflito entre compromissos fixos (RF03).
class ConflictsScreen extends ConsumerWidget {
  const ConflictsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts = ref.watch(agendaProvider.select((s) => s.conflicts));
    final now = ref.watch(clockProvider)();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Conflitos')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ContentWidth(
            maxWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Dois compromissos estão em conflito quando seus intervalos se sobrepõem. '
                  'O agente nunca aloca tarefas por cima de compromissos, mas não decide qual '
                  'compromisso manter: isso cabe a você.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                if (conflicts.isEmpty)
                  const EmptyState(
                    icon: Icons.verified_outlined,
                    title: 'Nenhum conflito',
                    message: 'Seus compromissos fixos não se sobrepõem.',
                  ),
                for (final c in conflicts) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber, color: scheme.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${fmtRelativeDay(c.overlapStart, now)} · sobreposição de '
                                  '${fmtDuration(c.overlap.inMinutes)} '
                                  '(${fmtTime(c.overlapStart)}–${fmtTime(c.overlapEnd)})',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _EventLine(event: c.first),
                          _EventLine(event: c.second),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventLine extends StatelessWidget {
  const _EventLine({required this.event});
  final FixedEvent event;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event),
      title: Text(event.title),
      subtitle: Text('${fmtTime(event.start)}–${fmtTime(event.end)}'
          '${event.location == null ? '' : ' · ${event.location}'}'),
      trailing: TextButton(
        onPressed: () => openEventForm(context, event: event),
        child: const Text('Editar'),
      ),
    );
  }
}
