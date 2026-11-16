import 'package:sqflite/sqflite.dart' show DatabaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// O SQLite roda em WebAssembly na própria página e grava no IndexedDB.
///
/// A variante sem web worker foi escolhida porque a versão com SharedWorker
/// não inicializou em todos os navegadores testados; como o AgendaIA é de uso
/// individual em uma aba, a perda de concorrência entre abas não afeta o uso.
DatabaseFactory platformDatabaseFactory() => databaseFactoryFfiWebNoWebWorker;
