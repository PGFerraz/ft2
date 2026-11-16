// Seleciona a implementação do SQLite conforme a plataforma:
// - Android/iOS/macOS: plugin nativo do sqflite;
// - Windows/Linux: sqflite_common_ffi (biblioteca SQLite via FFI);
// - Web: sqflite_common_ffi_web (SQLite compilado para WebAssembly).
export 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart';
