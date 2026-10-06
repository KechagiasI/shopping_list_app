import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/models/shopping_item.dart';
import 'package:shopping_list_app/repositories/shopping_repository.dart';
import 'package:shopping_list_app/services/shopping_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
}