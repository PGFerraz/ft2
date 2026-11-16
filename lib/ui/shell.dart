import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/agenda_controller.dart';
import 'screens/agenda_screen.dart';
import 'screens/conflicts_screen.dart';
import 'screens/preferences_screen.dart';
import 'screens/task_list_screen.dart';
import 'theme.dart';

/// Aba selecionada no shell (permite que uma tela abra outra aba).
class ShellIndex extends Notifier<int> {
  @override
  int build() => 0;
  void select(int index) => state = index;
}

final shellIndexProvider = NotifierProvider<ShellIndex, int>(ShellIndex.new);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _pages = <Widget>[
    AgendaScreen(),
    TaskListScreen(),
    ConflictsScreen(),
    PreferencesScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shellIndexProvider);
    final conflicts = ref.watch(agendaProvider.select((s) => s.conflicts.length));
    final volatile = ref.watch(volatileStorageProvider);
    final width = MediaQuery.sizeOf(context).width;

    Widget conflictIcon(IconData icon) => conflicts == 0
        ? Icon(icon)
        : Badge(label: Text('$conflicts'), child: Icon(icon));

    final destinations = [
      (icon: const Icon(Icons.today_outlined), selected: const Icon(Icons.today), label: 'Agenda'),
      (icon: const Icon(Icons.checklist_outlined), selected: const Icon(Icons.checklist), label: 'Tarefas'),
      (
        icon: conflictIcon(Icons.warning_amber_outlined),
        selected: conflictIcon(Icons.warning_amber),
        label: 'Conflitos'
      ),
      (icon: const Icon(Icons.tune_outlined), selected: const Icon(Icons.tune), label: 'Preferências'),
    ];

    final body = Column(
      children: [
        if (volatile)
          MaterialBanner(
            content: const Text(
                'Não foi possível abrir o banco local. Os dados desta sessão serão perdidos ao fechar.'),
            leading: const Icon(Icons.storage),
            actions: [const SizedBox.shrink()],
          ),
        Expanded(child: IndexedStack(index: index, children: _pages)),
      ],
    );

    void select(int i) => ref.read(shellIndexProvider.notifier).select(i);

    if (width < Breakpoints.medium) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: select,
          destinations: [
            for (final d in destinations)
              NavigationDestination(icon: d.icon, selectedIcon: d.selected, label: d.label),
          ],
        ),
      );
    }

    final extended = width >= Breakpoints.large;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: select,
            extended: extended,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: extended
                  ? Row(children: [
                      Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('AgendaIA',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ])
                  : Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
            ),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                    icon: d.icon, selectedIcon: d.selected, label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
