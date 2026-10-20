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
}