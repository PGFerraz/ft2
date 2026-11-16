import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/agenda_repository.dart';
import 'data/db_factory.dart';
import 'data/sqlite_agenda_repository.dart';
import 'state/agenda_controller.dart';
import 'ui/app.dart';

/// `flutter run --dart-define=AGENDA_MEMORIA=true` dispensa o SQLite (útil
/// para demonstrações em navegadores sem suporte a WebAssembly).
const bool _memoryOnly = bool.fromEnvironment('AGENDA_MEMORIA');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AgendaRepository repository;
  var volatile = false;
  try {
    if (_memoryOnly) throw StateError('Modo somente memória ativado.');
    // Um banco que não responde não pode deixar o app em branco.
    repository = await SqliteAgendaRepository.open(platformDatabaseFactory())
        .timeout(const Duration(seconds: 10));
  } catch (error, stack) {
    // Sem SQLite (por exemplo, navegador sem suporte a WebAssembly), o app
    // continua funcionando em memória e avisa o usuário.
    debugPrint('Falha ao abrir o SQLite: $error\n$stack');
    repository = InMemoryAgendaRepository();
    volatile = true;
  }
  final snapshot = await repository.loadAll();

  runApp(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repository),
      initialSnapshotProvider.overrideWithValue(snapshot),
      volatileStorageProvider.overrideWithValue(volatile),
    ],
    child: const AgendaApp(),
  ));
}
