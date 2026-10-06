import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/services/shopping_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('New database has version 2 and default item values', () async {
    final db = await ShoppingDatabase.open(
      dbFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );

    addTearDown(() async {
      await db.close();
    });

    expect(await db.getVersion(), 2);

    final id = await db.insert(
      'shopping_items',
      {'name': 'Milch'},
    );

    final rows = await db.query(
      'shopping_items',
      where: 'id = ?',
      whereArgs: [id],
    );

    expect(rows, hasLength(1));
    expect(rows.single['name'], 'Milch');
    expect(rows.single['quantity'], 1);
    expect(rows.single['isBought'], 0);
  });

  test('Upgrade from version 1 preserves existing items', () async {
    final directory = await Directory.systemTemp.createTemp(
      'shopping_database_test_',
    );

    addTearDown(() async {
      await directory.delete(recursive: true);
    });

    final databasePath = p.join(directory.path, 'migration_test.db');

    final oldDb = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE shopping_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              isBought INTEGER NOT NULL DEFAULT 0
            )
          ''');
        },
      ),
    );

    addTearDown(() async {
      if (oldDb.isOpen) {
        await oldDb.close();
      }
    });

    final id = await oldDb.insert(
      'shopping_items',
      {
        'name': 'Milch',
        'isBought': 1,
      },
    );

    await oldDb.close();

    final upgradedDb = await ShoppingDatabase.open(
      dbFactory: databaseFactoryFfi,
      path: databasePath,
    );

    addTearDown(() async {
      await upgradedDb.close();
    });

    expect(await upgradedDb.getVersion(), 2);

    final rows = await upgradedDb.query('shopping_items');

    expect(rows, hasLength(1));
    expect(rows.single['id'], id);
    expect(rows.single['name'], 'Milch');
    expect(rows.single['isBought'], 1);
    expect(rows.single['quantity'], 1);
  });
}