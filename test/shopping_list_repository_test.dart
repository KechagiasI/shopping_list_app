import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/repositories/shopping_list_repository.dart';
import 'package:shopping_list_app/services/shopping_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late ShoppingListRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await ShoppingDatabase.open(
      dbFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );

    addTearDown(() async {
      await db.close();
    });

    repository = ShoppingListRepository(
      openDatabase: () async => db,
    );
  });

  test('New database contains the default shopping list', () async {
    final lists = await repository.loadLists();

    expect(lists, hasLength(1));
    expect(lists.single.id, 1);
    expect(lists.single.name, 'Einkaufsliste');
  });

  test('Added lists retain their names and insertion order', () async {
    final weeklyId = await repository.addList('Wocheneinkauf');
    final partyId = await repository.addList('Party');

    final lists = await repository.loadLists();

    expect(weeklyId, greaterThan(1));
    expect(partyId, greaterThan(weeklyId));

    expect(
      lists.map((list) => list.id).toList(),
      [1, weeklyId, partyId],
    );

    expect(
      lists.map((list) => list.name).toList(),
      ['Einkaufsliste', 'Wocheneinkauf', 'Party'],
    );
  });

  test('Adding a list trims surrounding whitespace', () async {
    final id = await repository.addList('  Wochenende  ');

    final lists = await repository.loadLists();
    final savedList = lists.singleWhere((list) => list.id == id);

    expect(savedList.name, 'Wochenende');
  });

  test('Empty names are rejected without adding lists', () async {
    for (final name in ['', '   ', '\t\n']) {
      await expectLater(
        repository.addList(name),
        throwsArgumentError,
      );
    }

    final lists = await repository.loadLists();

    expect(lists, hasLength(1));
    expect(lists.single.id, 1);
    expect(lists.single.name, 'Einkaufsliste');
  });

  test('Renaming affects only the selected list and preserves its items',
          () async {
        final listId = await repository.addList('Wochenende');

        await db.insert(
          'shopping_items',
          {
            'name': 'Milch',
            'quantity': 3,
            'category': 'dairy',
            'isBought': 1,
            'listId': listId,
          },
        );

        final itemsBefore = await db.query('shopping_items');

        final updatedRows = await repository.renameList(
          id: listId,
          name: '  Wocheneinkauf  ',
        );

        expect(updatedRows, 1);

        final lists = await repository.loadLists();

        expect(lists, hasLength(2));
        expect(
          lists.map((list) => list.id).toList(),
          [1, listId],
        );
        expect(
          lists.map((list) => list.name).toList(),
          ['Einkaufsliste', 'Wocheneinkauf'],
        );

        final itemsAfter = await db.query('shopping_items');

        expect(itemsAfter, itemsBefore);
        expect(itemsAfter.single['listId'], listId);
      });

  test('Invalid names are rejected without renaming the list', () async {
    final listId = await repository.addList('Wochenende');

    final listsBefore = await db.query(
      'shopping_lists',
      orderBy: 'id ASC',
    );

    for (final invalidName in ['', '   ', '\t\n']) {
      await expectLater(
        repository.renameList(
          id: listId,
          name: invalidName,
        ),
        throwsArgumentError,
      );

      final listsAfter = await db.query(
        'shopping_lists',
        orderBy: 'id ASC',
      );

      expect(listsAfter, listsBefore);
    }
  });

  test('Renaming a missing list returns zero and preserves existing lists',
          () async {
        await repository.addList('Wochenende');

        final listsBefore = await db.query(
          'shopping_lists',
          orderBy: 'id ASC',
        );

        final updatedRows = await repository.renameList(
          id: 999,
          name: 'Wocheneinkauf',
        );

        expect(updatedRows, 0);

        final listsAfter = await db.query(
          'shopping_lists',
          orderBy: 'id ASC',
        );

        expect(listsAfter, listsBefore);
      });

  test('Deleting a list removes only that list and its items', () async {
    final listId = await repository.addList('Wochenende');

    await db.insert(
      'shopping_items',
      {
        'name': 'Milch',
        'quantity': 3,
        'category': 'dairy',
        'isBought': 1,
        'listId': 1,
      },
    );

    final originalItems = await db.query(
      'shopping_items',
      where: 'listId = ?',
      whereArgs: [1],
    );

    await db.insert(
      'shopping_items',
      {
        'name': 'Brot',
        'listId': listId,
      },
    );

    await db.insert(
      'shopping_items',
      {
        'name': 'Reis',
        'listId': listId,
      },
    );

    final deletedRows = await repository.deleteList(listId);

    // The result counts deleted lists, not deleted products.
    expect(deletedRows, 1);

    final lists = await repository.loadLists();

    expect(lists, hasLength(1));
    expect(lists.single.id, 1);
    expect(lists.single.name, 'Einkaufsliste');

    final remainingItems = await db.query('shopping_items');

    expect(remainingItems, originalItems);
    expect(
      await db.rawQuery('PRAGMA foreign_key_check'),
      isEmpty,
    );
  });

  test('The default list can be deleted and a new list created afterward',
          () async {
        await db.insert(
          'shopping_items',
          {
            'name': 'Milch',
            'listId': 1,
          },
        );

        expect(await repository.deleteList(1), 1);
        expect(await repository.loadLists(), isEmpty);
        expect(await db.query('shopping_items'), isEmpty);

        final newListId = await repository.addList('Neue Einkäufe');

        expect(newListId, greaterThan(1));

        final lists = await repository.loadLists();

        expect(lists, hasLength(1));
        expect(lists.single.id, newListId);
        expect(lists.single.name, 'Neue Einkäufe');

        final itemId = await db.insert(
          'shopping_items',
          {
            'name': 'Brot',
            'listId': newListId,
          },
        );

        final items = await db.query('shopping_items');

        expect(items, hasLength(1));
        expect(items.single['id'], itemId);
        expect(items.single['name'], 'Brot');
        expect(items.single['listId'], newListId);

        expect(
          await db.rawQuery('PRAGMA foreign_key_check'),
          isEmpty,
        );
      });

  test('Failed list deletion rolls back the deletion of its items',
          () async {
        final listId = await repository.addList('Wochenende');

        await db.insert(
          'shopping_items',
          {
            'name': 'Milch',
            'quantity': 3,
            'category': 'dairy',
            'isBought': 1,
            'listId': listId,
          },
        );

        final listsBefore = await db.query(
          'shopping_lists',
          orderBy: 'id ASC',
        );
        final itemsBefore = await db.query(
          'shopping_items',
          orderBy: 'id ASC',
        );

        // Force the list deletion to fail after its items were deleted.
        await db.execute('''
      CREATE TRIGGER reject_list_deletion
      BEFORE DELETE ON shopping_lists
      BEGIN
        SELECT RAISE(ABORT, 'Simulated list deletion failure');
      END
    ''');

        await expectLater(
          repository.deleteList(listId),
          throwsA(isA<DatabaseException>()),
        );

        expect(
          await db.query('shopping_lists', orderBy: 'id ASC'),
          listsBefore,
        );
        expect(
          await db.query('shopping_items', orderBy: 'id ASC'),
          itemsBefore,
        );

        await db.execute('DROP TRIGGER reject_list_deletion');

        expect(await repository.deleteList(listId), 1);
        expect(await db.query('shopping_items'), isEmpty);

        final remainingLists = await repository.loadLists();

        expect(remainingLists, hasLength(1));
        expect(remainingLists.single.id, 1);
      });

  test('Deleting a missing list returns zero and preserves existing data',
          () async {
        final listId = await repository.addList('Wochenende');

        await db.insert(
          'shopping_items',
          {
            'name': 'Milch',
            'listId': listId,
          },
        );

        final listsBefore = await db.query(
          'shopping_lists',
          orderBy: 'id ASC',
        );
        final itemsBefore = await db.query(
          'shopping_items',
          orderBy: 'id ASC',
        );

        expect(await repository.deleteList(999), 0);

        expect(
          await db.query('shopping_lists', orderBy: 'id ASC'),
          listsBefore,
        );
        expect(
          await db.query('shopping_items', orderBy: 'id ASC'),
          itemsBefore,
        );
      });
}