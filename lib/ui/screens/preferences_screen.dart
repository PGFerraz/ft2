import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities.dart';
import '../../state/agenda_controller.dart';
import '../format.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

/// T8 — Preferências: expediente, pico, pesos, limite de nós e dados.
class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(agendaProvider.select((s) => s.preferences));
    final controller = ref.read(agendaProvider.notifier);
    final rules = ref.watch(ruleEngineProvider).rules;
    final volatile = ref.watch(volatileStorageProvider);
    final text = Theme.of(context).textTheme;

    TimeOfDay tod(int minutes) => TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    int mins(TimeOfDay t) => t.hour * 60 + t.minute;

    void save(Preferences p, {String? error}) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      controller.savePreferences(p);
    }

    Future<void> confirm(String title, String body, Future<void> Function() action) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar')),
          ],
        ),
      );
      if (ok == true) await action();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Preferências')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          ContentWidth(
            maxWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader('Horário de trabalho',
                            subtitle: 'O agente só aloca tarefas dentro deste intervalo.'),
                        FieldPair(
                          first: TimeField(
                            label: 'Início',
                            value: tod(prefs.workStartMinutes),
                            onChanged: (t) => save(prefs.copyWith(workStartMinutes: mins(t)),
                                error: mins(t) >= prefs.workEndMinutes
                                    ? 'O início precisa ser antes do fim.'
                                    : null),
                          ),
                          second: TimeField(
                            label: 'Fim',
                            value: tod(prefs.workEndMinutes),
                            onChanged: (t) => save(prefs.copyWith(workEndMinutes: mins(t)),
                                error: mins(t) <= prefs.workStartMinutes
                                    ? 'O fim precisa ser depois do início.'
                                    : null),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const SectionHeader('Período de pico',
                            subtitle:
                                'Horário em que você rende mais. Tarefas de foco fora dele custam β.'),
                        FieldPair(
                          first: TimeField(
                            label: 'Início do pico',
                            value: tod(prefs.peakStartMinutes),
                            onChanged: (t) => save(prefs.copyWith(peakStartMinutes: mins(t)),
                                error: mins(t) >= prefs.peakEndMinutes
                                    ? 'O início do pico precisa ser antes do fim.'
                                    : null),
                          ),
                          second: TimeField(
                            label: 'Fim do pico',
                            value: tod(prefs.peakEndMinutes),
                            onChanged: (t) => save(prefs.copyWith(peakEndMinutes: mins(t)),
                                error: mins(t) <= prefs.peakStartMinutes
                                    ? 'O fim do pico precisa ser depois do início.'
                                    : null),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Pesos atuais: α = ${fmtNumber(prefs.alpha)}, β = ${fmtNumber(prefs.beta)}, '
                          'limite de ${prefs.nodeLimit} nós, horizonte de ${prefs.horizonDays} dia(s). '
                          'Eles são ajustados na tela de planejamento.',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: SectionHeader('Base de conhecimento',
                            subtitle:
                                'Regras SE-ENTÃO que o agente aplica a cada tarefa, por ordem de saliência.'),
                      ),
                      for (final r in rules)
                        ListTile(
                          leading: CircleAvatar(radius: 18, child: Text(r.id)),
                          title: Text('SE ${r.condition}'),
                          subtitle: Text('ENTÃO ${r.conclusion}'),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader('Dados',
                            subtitle: volatile
                                ? 'Armazenamento temporário (o banco local não abriu).'
                                : 'Tudo fica salvo neste dispositivo, em SQLite.'),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.tonalIcon(
                              key: const Key('load-demo'),
                              onPressed: () => confirm(
                                'Carregar demonstração?',
                                'Os dados atuais serão substituídos por um cenário de exemplo.',
                                controller.loadDemo,
                              ),
                              icon: const Icon(Icons.play_circle_outline),
                              label: const Text('Carregar cenário de demonstração'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => confirm(
                                'Apagar todos os dados?',
                                'Tarefas, compromissos, histórico e agendas serão removidos.',
                                controller.clearAll,
                              ),
                              icon: const Icon(Icons.delete_sweep_outlined),
                              label: const Text('Apagar todos os dados'),
                            ),
                          ],
                        ),
                      ],
                    ),
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
