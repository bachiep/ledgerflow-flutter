import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

QueryExecutor openAppConnection() {
  return LazyDatabase(() async {
    final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
    try {
      final fs = await IndexedDbFileSystem.open(dbName: 'ledgerflow_web');
      sqlite3.registerVirtualFileSystem(fs, makeDefault: true);
      return WasmDatabase(
        sqlite3: sqlite3,
        path: '/ledgerflow.sqlite',
        fileSystem: fs,
        setup: (database) {
          database.execute('PRAGMA foreign_keys = ON;');
        },
      );
    } catch (_) {
      sqlite3.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);
      return WasmDatabase.inMemory(
        sqlite3,
        setup: (database) {
          database.execute('PRAGMA foreign_keys = ON;');
        },
      );
    }
  });
}
