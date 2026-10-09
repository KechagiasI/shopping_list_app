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
        version: 3,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE shopping_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              isBought INTEGER NOT NULL DEFAULT 0,
              quantity INTEGER NOT NULL DEFAULT 1,
              category TEXT NOT NULL DEFAULT 'other'
            )
          ''');
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
        },
      ),
    );
  }
}