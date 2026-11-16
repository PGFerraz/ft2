import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities.dart';
import '../../domain/planning/problem.dart';
import '../../state/agenda_controller.dart';
import '../format.dart';
import '../shell.dart';
import '../widgets/common.dart';
import 'plan_result_screen.dart';

/// T5 — Configurar planejamento: estratégia, horizonte e pesos.
class PlanConfigScreen extends ConsumerStatefulWidget {
  const PlanConfigScreen({super.key});

  @override
  ConsumerState<PlanConfigScreen> createState() => _PlanConfigScreenState();
}

class _PlanConfigScreenState extends ConsumerState<PlanConfigScreen> {
  PlanStrategy _strategy = PlanStrategy.comparar;
  PlanStart _start = PlanStart.agora;
  late Preferences _prefs;
  bool _running = false;

  static const _nodeLimits = [1000, 10000, 50000, 200000];

  @override
  void initState() {
    super.initState();
    _prefs = ref.read(agendaProvider).preferences;
    final now = ref.read(clockProvider)();
    // Depois do expediente, o padrão passa a ser começar amanhã.
    if (now.hour * 60 + now.minute >= _prefs.workEndMinutes - 30) _start = PlanStart.amanha;
  }

  Future<void> _generate() async {
    setState(() => _running = true);
    // Deixa a interface desenhar o indicador antes de a busca ocupar a thread.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    await ref.read(agendaProvider.notifier).savePreferences(_prefs);
    final result = ref.read(planningProvider.notifier).generate(
          strategy: _strategy,
          start: _start,
          preferences: _prefs,
        );
    if (!mounted) return;
    setState(() => _running = false);
    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    final accepted = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const PlanResultScreen()));
    if (accepted == true && mounted) {
      ref.read(shellIndexProvider.notifier).select(0);
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agenda = ref.watch(agendaProvider);
    final controller = ref.read(agendaProvider.notifier);
    final open = agenda.tasks.where((t) => t.status.isOpen).toList();
    final blocks = open.fold<int>(0, (sum, t) => sum + controller.evaluate(t).chunks.length);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final aStarFallback = blocks > kAStarMaxUnits && _strategy != PlanStrategy.guloso;

    return Scaffold(
      appBar: AppBar(title: const Text('Planejar agenda')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          ContentWidth(
            maxWidth: 760,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text('${open.length} tarefa(s) abertas · $blocks bloco(s) para alocar'),
                    subtitle: Text('${agenda.events.length} compromisso(s) fixo(s) serão respeitados'
                        '${agenda.conflicts.isEmpty ? '' : ' · ${agenda.conflicts.length} conflito(s) não resolvido(s)'}'),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Estratégia', style: text.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<PlanStrategy>(
                  segments: const [
                    ButtonSegment(value: PlanStrategy.guloso, label: Text('Gulosa')),
                    ButtonSegment(value: PlanStrategy.aEstrela, label: Text('A*')),
                    ButtonSegment(value: PlanStrategy.comparar, label: Text('Comparar')),
                  ],
                  selected: {_strategy},
                  onSelectionChanged: (s) => setState(() => _strategy = s.first),
                ),
                const SizedBox(height: 6),
                Text(
                  switch (_strategy) {
                    PlanStrategy.guloso =>
                      'Rápida: escolhe a cada passo a tarefa que menos atrasa as demais, sem voltar atrás.',
                    PlanStrategy.aEstrela =>
                      'Explora ordens alternativas com f = g + h e devolve a agenda de menor custo.',
                    PlanStrategy.comparar => 'Executa as duas estratégias e mostra os resultados lado a lado.',
                  },
                  style: text.bodySmall,
                ),
                if (aStarFallback)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Com mais de $kAStarMaxUnits blocos, o A* recorre à solução gulosa para manter o tempo de resposta.',
                      style: text.bodySmall?.copyWith(color: scheme.error),
                    ),
                  ),
                const SizedBox(height: 20),
                Text('Início', style: text.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<PlanStart>(
                  segments: [
                    const ButtonSegment(value: PlanStart.agora, label: Text('Agora')),
                    ButtonSegment(
                        value: PlanStart.amanha,
                        label: Text('Amanhã, ${fmtMinutesOfDay(_prefs.workStartMinutes)}')),
                  ],
                  selected: {_start},
                  onSelectionChanged: (s) => setState(() => _start = s.first),
                ),
                const SizedBox(height: 20),
                _SliderRow(
                  label: 'Horizonte',
                  value: _prefs.horizonDays.toDouble(),
                  min: 1,
                  max: 7,
                  divisions: 6,
                  display: _prefs.horizonDays == 1 ? '1 dia' : '${_prefs.horizonDays} dias',
                  onChanged: (v) => setState(() => _prefs = _prefs.copyWith(horizonDays: v.round())),
                ),
                _SliderRow(
                  label: 'α · troca de tipo',
                  value: _prefs.alpha,
                  min: 0,
                  max: 5,
                  divisions: 10,
                  display: fmtNumber(_prefs.alpha),
                  onChanged: (v) => setState(() => _prefs = _prefs.copyWith(alpha: v)),
                ),
                _SliderRow(
                  label: 'β · foco fora do pico',
                  value: _prefs.beta,
                  min: 0,
                  max: 5,
                  divisions: 10,
                  display: fmtNumber(_prefs.beta),
                  onChanged: (v) => setState(() => _prefs = _prefs.copyWith(beta: v)),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                    isExpanded: true,
                  initialValue: _nodeLimits.contains(_prefs.nodeLimit) ? _prefs.nodeLimit : 50000,
                  decoration: const InputDecoration(labelText: 'Limite de nós do A*'),
                  items: [
                    for (final n in _nodeLimits)
                      DropdownMenuItem(value: n, child: Text('$n nós')),
                  ],
                  onChanged: (v) => setState(() => _prefs = _prefs.copyWith(nodeLimit: v)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Custo de cada tarefa: w × atraso (em blocos de 15 min) + α × troca de tipo + β × foco fora do pico.',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('generate-plan'),
                  onPressed: _running || open.isEmpty ? null : _generate,
                  icon: _running
                      ? const SizedBox.square(
                          dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: Text(_running ? 'Buscando…' : 'Gerar agenda'),
                ),
                if (open.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Não há tarefas abertas para planejar.', style: text.bodySmall),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 150, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: display,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 56, child: Text(display, textAlign: TextAlign.end)),
      ],
    );
  }
}
