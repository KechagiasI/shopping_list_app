import '../models/shopping_item.dart';
import '../services/shopping_database.dart';

class ShoppingRepository {
  Future<List<ShoppingItem>> loadItems() async {
    final db = await ShoppingDatabase.open();

    final rows = await db.query(
      'shopping_items',
      orderBy: 'id ASC',
    );

    return rows
        .map((row) => ShoppingItem.fromMap(row))
        .toList();
  }

  Future<int> addItem(ShoppingItem item) async {
    final db = await ShoppingDatabase.open();

    return db.insert(
      'shopping_items',
      item.toMap(),
    );
  }

  Future<int> setBought({
    required int id,
    required bool isBought,
  }) async {
    final db = await ShoppingDatabase.open();

    return db.update(
      'shopping_items',
      {'isBought': isBought ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await ShoppingDatabase.open();

    return db.delete(
      'shopping_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}