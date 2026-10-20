import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/models/shopping_item.dart';
import 'package:shopping_list_app/repositories/shopping_repository.dart';
import 'package:shopping_list_app/services/shopping_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shopping_list_app/models/shopping_category.dart';

void main() {
  late Database db;
  late ShoppingRepository repository;

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

    repository = ShoppingRepository(
      openDatabase: () async => db,
    );
  });

  test('New database returns an empty list', () async {
    expect(await repository.loadItems(), isEmpty);
  });

  test('Added items retain their values and insertion order', () async {
    final milkId = await repository.addItem(
      ShoppingItem(name: 'Milch', quantity: 3),
    );

    final breadId = await repository.addItem(
      ShoppingItem(name: 'Brot', quantity: 2),
    );

    final items = await repository.loadItems();

    expect(milkId, greaterThan(0));
    expect(breadId, isNot(milkId));
    expect(items, hasLength(2));

    expect(items[0].id, milkId);
    expect(items[0].name, 'Milch');
    expect(items[0].quantity, 3);
    expect(items[0].isBought, isFalse);

    expect(items[1].id, breadId);
    expect(items[1].name, 'Brot');
    expect(items[1].quantity, 2);
  });

  test('Purchase status changes only the selected item', () async {
    final milkId = await repository.addItem(
      ShoppingItem(name: 'Milch', quantity: 3),
    );

    await repository.addItem(
      ShoppingItem(name: 'Brot'),
    );

    final updatedRows = await repository.setBought(
      id: milkId,
      isBought: true,
    );

    expect(updatedRows, 1);

    var items = await repository.loadItems();

    expect(items[0].isBought, isTrue);
    expect(items[0].name, 'Milch');
    expect(items[0].quantity, 3);
    expect(items[1].isBought, isFalse);

    expect(
      await repository.setBought(id: milkId, isBought: false),
      1,
    );

    items = await repository.loadItems();

    expect(items[0].isBought, isFalse);
  });

  test('Deletion removes only the selected item', () async {
    final milkId = await repository.addItem(
      ShoppingItem(name: 'Milch'),
    );

    final breadId = await repository.addItem(
      ShoppingItem(name: 'Brot'),
    );

    expect(await repository.deleteItem(milkId), 1);

    final items = await repository.loadItems();

    expect(items, hasLength(1));
    expect(items.single.id, breadId);
    expect(items.single.name, 'Brot');
  });

  test('Missing item returns zero affected rows', () async {
    expect(
      await repository.setBought(id: 999, isBought: true),
      0,
    );

    expect(await repository.deleteItem(999), 0);
    expect(await repository.loadItems(), isEmpty);
  });

  test('Database opening errors reach the caller', () async {
    final failingRepository = ShoppingRepository(
      openDatabase: () async {
        throw StateError('Simulated database opening failure');
      },
    );

    await expectLater(
      failingRepository.loadItems(),
      throwsA(isA<StateError>()),
    );

    await expectLater(
      failingRepository.addItem(ShoppingItem(name: 'Milch')),
      throwsA(isA<StateError>()),
    );

    await expectLater(
      failingRepository.setBought(id: 1, isBought: true),
      throwsA(isA<StateError>()),
    );

    await expectLater(
      failingRepository.deleteItem(1),
      throwsA(isA<StateError>()),
    );
  });

  test('Editing changes only the selected item and preserves its identity',
          () async {
        final milkId = await repository.addItem(
          ShoppingItem(
            name: 'Milch',
            quantity: 3,
            isBought: true,
          ),
        );

        final breadId = await repository.addItem(
          ShoppingItem(name: 'Brot', quantity: 2),
        );

        final updatedRows = await repository.updateItem(
          id: milkId,
          name: '  Hafermilch  ',
          quantity: 5,
        );

        expect(updatedRows, 1);

        final items = await repository.loadItems();

        expect(items, hasLength(2));

        final editedItem = items.singleWhere((item) => item.id == milkId);
        expect(editedItem.id, milkId);
        expect(editedItem.name, 'Hafermilch');
        expect(editedItem.quantity, 5);
        expect(editedItem.isBought, isTrue);

        final unchangedItem = items.singleWhere((item) => item.id == breadId);
        expect(unchangedItem.name, 'Brot');
        expect(unchangedItem.quantity, 2);
        expect(unchangedItem.isBought, isFalse);
      });

  test('Editing a missing item returns zero and keeps existing items',
          () async {
        final id = await repository.addItem(
          ShoppingItem(name: 'Milch', quantity: 3),
        );

        final updatedRows = await repository.updateItem(
          id: id + 1,
          name: 'Brot',
          quantity: 2,
        );

        expect(updatedRows, 0);

        final items = await repository.loadItems();

        expect(items, hasLength(1));
        expect(items.single.id, id);
        expect(items.single.name, 'Milch');
        expect(items.single.quantity, 3);
      });

  test('Invalid edits are rejected without changing the stored item',
          () async {
        final id = await repository.addItem(
          ShoppingItem(
            name: 'Milch',
            quantity: 3,
            isBought: true,
          ),
        );

        for (final invalidName in ['', '   ']) {
          await expectLater(
            repository.updateItem(
              id: id,
              name: invalidName,
              quantity: 5,
            ),
            throwsA(isA<ArgumentError>()),
          );
        }

        for (final invalidQuantity in [0, -1]) {
          await expectLater(
            repository.updateItem(
              id: id,
              name: 'Hafermilch',
              quantity: invalidQuantity,
            ),
            throwsA(isA<ArgumentError>()),
          );
        }

        final items = await repository.loadItems();

        expect(items, hasLength(1));
        expect(items.single.id, id);
        expect(items.single.name, 'Milch');
        expect(items.single.quantity, 3);
        expect(items.single.isBought, isTrue);
      });

  test('Category updates affect only the selected item and survive later edits',
          () async {
        final milkId = await repository.addItem(
          ShoppingItem(
            name: 'Milch',
            quantity: 3,
            isBought: true,
          ),
        );

        final breadId = await repository.addItem(
          ShoppingItem(
            name: 'Brot',
            quantity: 2,
            category: ShoppingCategory.bakery,
          ),
        );

        expect(
          await repository.updateItem(
            id: milkId,
            name: 'Milch',
            quantity: 3,
            category: ShoppingCategory.dairy,
          ),
          1,
        );

        var items = await repository.loadItems();
        var milk = items.singleWhere((item) => item.id == milkId);
        final bread = items.singleWhere((item) => item.id == breadId);

        expect(milk.category, ShoppingCategory.dairy);
        expect(milk.isBought, isTrue);
        expect(bread.category, ShoppingCategory.bakery);
        expect(bread.name, 'Brot');
        expect(bread.quantity, 2);

        // Omitting category must preserve the stored category.
        expect(
          await repository.updateItem(
            id: milkId,
            name: 'Vollmilch',
            quantity: 5,
          ),
          1,
        );

        items = await repository.loadItems();
        milk = items.singleWhere((item) => item.id == milkId);

        expect(milk.name, 'Vollmilch');
        expect(milk.quantity, 5);
        expect(milk.category, ShoppingCategory.dairy);
        expect(milk.isBought, isTrue);
      });

  test('Editing an item preserves its shopping list', () async {
    final listId = await db.insert(
      'shopping_lists',
      {'name': 'Wocheneinkauf'},
    );

    expect(listId, isNot(1));

    final itemId = await repository.addItem(
      ShoppingItem(
        name: 'Milch',
        quantity: 2,
        category: ShoppingCategory.other,
        listId: listId,
        isBought: true,
      ),
    );

    final updatedRows = await repository.updateItem(
      id: itemId,
      name: 'Vollmilch',
      quantity: 3,
      category: ShoppingCategory.dairy,
    );

    expect(updatedRows, 1);

    final rows = await db.query(
      'shopping_items',
      where: 'id = ?',
      whereArgs: [itemId],
    );

    expect(rows, hasLength(1));

    final savedItem = ShoppingItem.fromMap(rows.single);

    expect(savedItem.id, itemId);
    expect(savedItem.name, 'Vollmilch');
    expect(savedItem.quantity, 3);
    expect(savedItem.category, ShoppingCategory.dairy);
    expect(savedItem.listId, listId);
    expect(savedItem.isBought, isTrue);
  });

  test('Loading items returns only the selected shopping list', () async {
    final secondListId = await db.insert(
      'shopping_lists',
      {'name': 'Wochenende'},
    );

    final secondRepository = ShoppingRepository(
      openDatabase: () async => db,
      selectedListId: secondListId,
    );

    final milkId = await repository.addItem(
      ShoppingItem(name: 'Milch'),
    );

    // The second list must stay empty despite the first list's item.
    expect(await secondRepository.loadItems(), isEmpty);

    final breadId = await secondRepository.addItem(
      ShoppingItem(
        name: 'Brot',
        listId: secondListId,
      ),
    );

    final riceId = await repository.addItem(
      ShoppingItem(name: 'Reis'),
    );

    final defaultItems = await repository.loadItems();
    final secondItems = await secondRepository.loadItems();

    expect(
      defaultItems.map((item) => item.id).toList(),
      [milkId, riceId],
    );
    expect(
      defaultItems.map((item) => item.name).toList(),
      ['Milch', 'Reis'],
    );
    expect(
      defaultItems.every((item) => item.listId == 1),
      isTrue,
    );

    expect(secondItems, hasLength(1));
    expect(secondItems.single.id, breadId);
    expect(secondItems.single.name, 'Brot');
    expect(secondItems.single.listId, secondListId);
  });
}