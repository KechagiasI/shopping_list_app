import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/services/shopping_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dart:io';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('New database has version 3 and default item values', () async {
    final db = await ShoppingDatabase.open(
      dbFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );

    addTearDown(() async {
      await db.close();
    });

    expect(await db.getVersion(), 3);

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
    expect(rows.single['category'], 'other');
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

    expect(await upgradedDb.getVersion(), 3);

    final rows = await upgradedDb.query('shopping_items');

    expect(rows, hasLength(1));
    expect(rows.single['id'], id);
    expect(rows.single['name'], 'Milch');
    expect(rows.single['isBought'], 1);
    expect(rows.single['quantity'], 1);
    expect(rows.single['category'], 'other');
  });

  test('Upgrade from version 2 adds category and preserves item values',
          () async {
        final directory = await Directory.systemTemp.createTemp(
          'shopping_database_v2_test_',
        );

        addTearDown(() async {
          await directory.delete(recursive: true);
        });

        final databasePath = p.join(directory.path, 'migration_test.db');

        final oldDb = await databaseFactoryFfi.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(
            version: 2,
            onCreate: (db, version) async {
              await db.execute('''
            CREATE TABLE shopping_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              isBought INTEGER NOT NULL DEFAULT 0,
              quantity INTEGER NOT NULL DEFAULT 1
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

        final milkId = await oldDb.insert(
          'shopping_items',
          {
            'name': 'Milch',
            'quantity': 3,
            'isBought': 1,
          },
        );

        final breadId = await oldDb.insert(
          'shopping_items',
          {
            'name': 'Brot',
            'quantity': 2,
            'isBought': 0,
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

        expect(await upgradedDb.getVersion(), 3);

        final rows = await upgradedDb.query(
          'shopping_items',
          orderBy: 'id ASC',
        );

        expect(rows, [
          {
            'id': milkId,
            'name': 'Milch',
            'quantity': 3,
            'isBought': 1,
            'category': 'other',
          },
          {
            'id': breadId,
            'name': 'Brot',
            'quantity': 2,
            'isBought': 0,
            'category': 'other',
          },
        ]);

        final newId = await upgradedDb.insert(
          'shopping_items',
          {'name': 'Reis'},
        );

        final newRows = await upgradedDb.query(
          'shopping_items',
          where: 'id = ?',
          whereArgs: [newId],
        );

        expect(newRows, hasLength(1));
        expect(newRows.single['quantity'], 1);
        expect(newRows.single['isBought'], 0);
        expect(newRows.single['category'], 'other');
      });
}