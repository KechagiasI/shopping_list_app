import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class ShoppingDatabase {
  static Future<Database> open() async {
    final databasePath = await getDatabasesPath();

    return openDatabase(
      p.join(databasePath, 'shopping_list.db'),
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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE shopping_items '
                'ADD COLUMN quantity INTEGER NOT NULL DEFAULT 1',
          );
        }
      },
    );
  }
}