import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shopping_list_app/services/shopping_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  test('New database has version 4, a default list and item defaults',
          () async {
        final db = await ShoppingDatabase.open(
          dbFactory: databaseFactoryFfi,
          path: inMemoryDatabasePath,
        );

        addTearDown(() async {
          await db.close();
        });

        expect(await db.getVersion(), 4);

        expect(await db.query('shopping_lists'), [
          {
            'id': 1,
            'name': 'Einkaufsliste',
          },
        ]);

        final id = await db.insert(
          'shopping_items',
          {'name': 'Milch'},
        );

        final rows = await db.query('shopping_items');

        expect(rows, [
          {
            'id': id,
            'name': 'Milch',
            'quantity': 1,
            'category': 'other',
            'isBought': 0,
            'listId': 1,
          },
        ]);
      });

  test('Items must belong to an existing shopping list', () async {
    final db = await ShoppingDatabase.open(
      dbFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );

    addTearDown(() async {
      await db.close();
    });

    await expectLater(
      db.insert(
        'shopping_items',
        {
          'name': 'Milch',
          'listId': 999,
        },
      ),
      throwsA(isA<DatabaseException>()),
    );

    expect(await db.query('shopping_items'), isEmpty);

    final listId = await db.insert(
      'shopping_lists',
      {'name': 'Wocheneinkauf'},
    );

    final itemId = await db.insert(
      'shopping_items',
      {
        'name': 'Milch',
        'listId': listId,
      },
    );

    final rows = await db.query('shopping_items');

    expect(rows, hasLength(1));
    expect(rows.single['id'], itemId);
    expect(rows.single['name'], 'Milch');
    expect(rows.single['listId'], listId);
  });

  for (final oldVersion in [1, 2, 3]) {
    test('Upgrade from version $oldVersion preserves items in the default list',
            () async {
          final directory = await Directory.systemTemp.createTemp(
            'shopping_database_v${oldVersion}_test_',
          );

          addTearDown(() async {
            await directory.delete(recursive: true);
          });

          final databasePath = p.join(directory.path, 'migration_test.db');

          final oldDb = await databaseFactoryFfi.openDatabase(
            databasePath,
            options: OpenDatabaseOptions(
              version: oldVersion,
              onCreate: (db, version) async {
                final columns = [
                  'id INTEGER PRIMARY KEY AUTOINCREMENT',
                  'name TEXT NOT NULL',
                  'isBought INTEGER NOT NULL DEFAULT 0',
                  if (oldVersion >= 2)
                    'quantity INTEGER NOT NULL DEFAULT 1',
                  if (oldVersion >= 3)
                    "category TEXT NOT NULL DEFAULT 'other'",
                ];

                await db.execute(
                  'CREATE TABLE shopping_items (${columns.join(', ')})',
                );
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
              'isBought': 1,
              if (oldVersion >= 2) 'quantity': 3,
              if (oldVersion >= 3) 'category': 'dairy',
            },
          );

          final breadId = await oldDb.insert(
            'shopping_items',
            {
              'name': 'Brot',
              'isBought': 0,
              if (oldVersion >= 2) 'quantity': 2,
              if (oldVersion >= 3) 'category': 'bakery',
            },
          );

          // Check that migration does not reuse previously assigned IDs.
          await oldDb.insert(
            'shopping_items',
            {
              'id': 50,
              'name': 'Temporary product',
            },
          );

          await oldDb.delete(
            'shopping_items',
            where: 'id = ?',
            whereArgs: [50],
          );

          await oldDb.close();

          final upgradedDb = await ShoppingDatabase.open(
            dbFactory: databaseFactoryFfi,
            path: databasePath,
          );

          addTearDown(() async {
            await upgradedDb.close();
          });

          expect(await upgradedDb.getVersion(), 4);

          expect(await upgradedDb.query('shopping_lists'), [
            {
              'id': 1,
              'name': 'Einkaufsliste',
            },
          ]);

          final rows = await upgradedDb.query(
            'shopping_items',
            orderBy: 'id ASC',
          );

          expect(rows, [
            {
              'id': milkId,
              'name': 'Milch',
              'quantity': oldVersion >= 2 ? 3 : 1,
              'category': oldVersion >= 3 ? 'dairy' : 'other',
              'isBought': 1,
              'listId': 1,
            },
            {
              'id': breadId,
              'name': 'Brot',
              'quantity': oldVersion >= 2 ? 2 : 1,
              'category': oldVersion >= 3 ? 'bakery' : 'other',
              'isBought': 0,
              'listId': 1,
            },
          ]);

          final newId = await upgradedDb.insert(
            'shopping_items',
            {'name': 'Reis'},
          );

          expect(newId, greaterThan(50));

          final newRows = await upgradedDb.query(
            'shopping_items',
            where: 'id = ?',
            whereArgs: [newId],
          );

          expect(newRows, [
            {
              'id': newId,
              'name': 'Reis',
              'quantity': 1,
              'category': 'other',
              'isBought': 0,
              'listId': 1,
            },
          ]);

          expect(
            await upgradedDb.rawQuery('PRAGMA foreign_key_check'),
            isEmpty,
          );
        });
  }
}