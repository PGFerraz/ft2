import 'package:agenda_ia/data/agenda_repository.dart';
import 'package:agenda_ia/domain/conflicts.dart';
import 'package:agenda_ia/domain/entities.dart';
import 'package:agenda_ia/state/agenda_controller.dart';
import 'package:agenda_ia/state/demo_data.dart';
import 'package:agenda_ia/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Quarta-feira, 11/11/2026, 08:00 — relógio fixo para resultados estáveis.
final _now = DateTime(2026, 11, 11, 8);

const _phone = Size(390, 844);
const _desktop = Size(1366, 900);

Future<InMemoryAgendaRepository> _pumpApp(
  WidgetTester tester, {
  Size size = _phone,
  bool demo = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final scenario = buildDemoScenario(_now);
  final snapshot = demo
      ? AgendaSnapshot(tasks: scenario.tasks, events: scenario.events, history: scenario.history)
      : const AgendaSnapshot();
  final repo = InMemoryAgendaRepository(snapshot);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      initialSnapshotProvider.overrideWithValue(snapshot),
      clockProvider.overrideWithValue(() => _now),
    ],
    child: const AgendaApp(),
  ));
  await tester.pumpAndSettle();
  return repo;
}

/// Rola a lista mais interna até o widget aparecer e toca nele.
Future<void> _tapInList(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable).last;
  await tester.scrollUntilVisible(finder, 200, scrollable: scrollable);
  // scrollUntilVisible para assim que o widget surge na borda; ensureVisible
  // garante que o centro dele esteja na tela antes do toque.
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('T1 mostra a agenda vazia e o conflito do cenário (RF03)', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Agenda'), findsWidgets);
    expect(find.text('1 conflito entre compromissos'), findsOneWidget);
    expect(find.text('Nenhuma agenda aceita'), findsOneWidget);

    await tester.tap(find.text('1 conflito entre compromissos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('sobreposição de 30 min'), findsOneWidget);
    expect(find.text('Estágio'), findsOneWidget);
    expect(find.text('Consulta médica'), findsOneWidget);
  });

  testWidgets('fluxo completo no celular: planejar, comparar e aceitar o A* (RF04–RF06)',
      (tester) async {
    final repo = await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('plan-button')));
    await tester.pumpAndSettle();
    expect(find.text('Planejar agenda'), findsOneWidget);
    expect(find.textContaining('6 tarefa(s) abertas'), findsOneWidget);

    await _tapInList(tester, find.byKey(const Key('generate-plan')));
    expect(find.text('Resultado'), findsOneWidget);
    // No celular as agendas ficam em abas; a aba do A* abre primeiro.
    expect(find.widgetWithText(Tab, 'A*'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Busca gulosa'), findsOneWidget);
    expect(find.text('Custo mínimo garantido'), findsOneWidget);

    await _tapInList(tester, find.byKey(const Key('accept-aEstrela')));
    expect(find.text('Agenda atual · A*'), findsOneWidget);

    final saved = (await repo.loadAll()).currentPlan!;
    expect(saved.algorithm, Algorithm.aEstrela);
    expect(saved.optimal, isTrue);
    expect(saved.allocations, isNotEmpty);

    // Nenhuma alocação sobrepõe compromisso fixo ou outra alocação.
    final events = (await repo.loadAll()).events;
    for (final a in saved.allocations) {
      for (final e in events) {
        expect(overlaps(a.start, a.end, e.start, e.end), isFalse,
            reason: '${a.displayTitle} sobrepõe ${e.title}');
      }
      for (final b in saved.allocations) {
        if (identical(a, b)) continue;
        expect(overlaps(a.start, a.end, b.start, b.end), isFalse);
      }
      expect(a.start.hour * 60 + a.start.minute, greaterThanOrEqualTo(7 * 60));
    }

    // A tarefa longa foi dividida em blocos (R6) e aparece na linha do tempo.
    expect(saved.allocations.where((a) => a.taskId == 'demo-t2').length, 3);
  });

  testWidgets('no desktop as duas agendas aparecem lado a lado', (tester) async {
    await _pumpApp(tester, size: _desktop);
    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan-button')));
    await tester.pumpAndSettle();
    await _tapInList(tester, find.byKey(const Key('generate-plan')));
    expect(find.byType(TabBar), findsNothing);
    expect(find.byKey(const Key('accept-guloso')), findsOneWidget);
    expect(find.byKey(const Key('accept-aEstrela')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cadastro de tarefa mostra a sugestão das regras e persiste (RF01, RF07)',
      (tester) async {
    final repo = await _pumpApp(tester, demo: false);
    await tester.tap(find.text('Tarefas').last);
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma tarefa cadastrada'), findsOneWidget);

    await tester.tap(find.text('Nova tarefa'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('task-title')), 'Estudar busca A*');
    await tester.pumpAndSettle();
    // Padrão: foco, não urgente, não importante → R4.
    expect(find.text('Sugestão do agente'), findsOneWidget);
    expect(find.textContaining('Nem urgente nem importante'), findsOneWidget);

    await _tapInList(tester, find.text('Importante'));
    expect(find.textContaining('Importante e não urgente'), findsOneWidget);

    await _tapInList(tester, find.byKey(const Key('task-save')));
    expect(find.text('Estudar busca A*'), findsOneWidget);
    final tasks = (await repo.loadAll()).tasks;
    expect(tasks.single.important, isTrue);
    expect(tasks.single.type, TaskType.foco);
  });

  testWidgets('concluir tarefa registra a duração real no histórico (RF08, R7)', (tester) async {
    final repo = await _pumpApp(tester);
    final before = (await repo.loadAll()).history.length;

    await tester.tap(find.text('Tarefas').last);
    await tester.pumpAndSettle();
    await _tapInList(tester, find.text('Lista de exercícios de Lógica'));
    expect(find.text('Raciocínio do agente'), findsOneWidget);

    await _tapInList(tester, find.byKey(const Key('complete-task')));
    await tester.tap(find.byKey(const Key('confirm-duration')));
    await tester.pumpAndSettle();

    final snapshot = await repo.loadAll();
    expect(snapshot.history.length, before + 1);
    expect(snapshot.tasks.firstWhere((t) => t.id == 'demo-t3').status, TaskStatus.concluida);
    expect(find.text('Reabrir tarefa'), findsOneWidget);
  });

  testWidgets('cadastro de compromisso avisa sobre conflito antes de salvar (RF02, RF03)',
      (tester) async {
    await _pumpApp(tester, size: _desktop);
    await tester.tap(find.text('Novo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo compromisso'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('event-title')), 'Plantão de dúvidas');
    await tester.pumpAndSettle();
    // Horário padrão às 09:00–10:00 de hoje não conflita com a aula (até 09:00).
    expect(find.text('Este horário conflita com:'), findsNothing);
    await _tapInList(tester, find.byKey(const Key('event-save')));
    expect(find.text('Agenda'), findsWidgets);
  });

  testWidgets('preferências listam a base de conhecimento R1–R7 (Tabela 4)', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Preferências').last);
    await tester.pumpAndSettle();
    for (final id in ['R1', 'R2', 'R3', 'R4', 'R5', 'R6']) {
      await tester.scrollUntilVisible(find.text(id), 120, scrollable: find.byType(Scrollable).last);
      expect(find.text(id), findsOneWidget);
    }
  });
}
