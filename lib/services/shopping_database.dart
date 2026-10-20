import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class ShoppingDatabase {
  static Future<Database> open({
    DatabaseFactory? dbFactory,
    String? path,
  }) async {
    final selectedFactory = dbFactory ?? databaseFactory;

    final databasePath = path ??
        p.join(
          await selectedFactory.getDatabasesPath(),
          'shopping_list.db',
        );

    return selectedFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 4,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _createListsTable(db);
          await _createItemsTable(db);
          await _createItemsIndex(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE shopping_items '
                  'ADD COLUMN quantity INTEGER NOT NULL DEFAULT 1',
            );
          }

          if (oldVersion < 3) {
            await db.execute(
              'ALTER TABLE shopping_items '
                  "ADD COLUMN category TEXT NOT NULL DEFAULT 'other'",
            );
          }

          if (oldVersion < 4) {
            await _createListsTable(db);

            final sequenceRows = await db.rawQuery(
              'SELECT seq FROM sqlite_sequence WHERE name = ?',
              ['shopping_items'],
            );

            final previousSequence = sequenceRows.isEmpty
                ? 0
                : sequenceRows.single['seq'] as int;

            await db.execute(
              'ALTER TABLE shopping_items '
                  'RENAME TO shopping_items_legacy',
            );

            await _createItemsTable(db);

            await db.execute('''
              INSERT INTO shopping_items (
                id, name, isBought, quantity, category, listId
              )
              SELECT
                id, name, isBought, quantity, category, 1
              FROM shopping_items_legacy
            ''');

            await db.execute('DROP TABLE shopping_items_legacy');

            await db.rawUpdate(
              'UPDATE sqlite_sequence '
                  'SET seq = MAX(seq, ?) WHERE name = ?',
              [previousSequence, 'shopping_items'],
            );

            await _createItemsIndex(db);
          }
        },
      ),
    );
  }

  static Future<void> _createListsTable(Database db) async {
    await db.execute('''
      CREATE TABLE shopping_lists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.insert(
      'shopping_lists',
      {
        'id': 1,
        'name': 'Einkaufsliste',
      },
    );
  }

  static Future<void> _createItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE shopping_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        isBought INTEGER NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 1,
        category TEXT NOT NULL DEFAULT 'other',
        listId INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (listId) REFERENCES shopping_lists(id)
      )
    ''');
  }

  static Future<void> _createItemsIndex(Database db) async {
    await db.execute(
      'CREATE INDEX idx_shopping_items_list_id '
          'ON shopping_items(listId)',
    );
  }
}