import '../models/shopping_item.dart';
import '../services/shopping_database.dart';
import 'package:sqflite/sqflite.dart';
import '../models/shopping_category.dart';

class ShoppingRepository {

  final Future<Database> Function() _openDatabase;

  ShoppingRepository({
    Future<Database> Function()? openDatabase,
  }) : _openDatabase = openDatabase ?? ShoppingDatabase.open;

  Future<List<ShoppingItem>> loadItems() async {
    final db = await _openDatabase();

    final rows = await db.query(
      'shopping_items',
      orderBy: 'id ASC',
    );

    return rows
        .map((row) => ShoppingItem.fromMap(row))
        .toList();
  }

  Future<int> addItem(ShoppingItem item) async {
    final db = await _openDatabase();

    return db.insert(
      'shopping_items',
      item.toMap(),
    );
  }

  Future<int> setBought({
    required int id,
    required bool isBought,
  }) async {
    final db = await _openDatabase();

    return db.update(
      'shopping_items',
      {'isBought': isBought ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateItem({
    required int id,
    required String name,
    required int quantity,
    ShoppingCategory? category,
  }) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty.');
    }

    if (quantity <= 0) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Must be greater than zero.',
      );
    }

    final db = await _openDatabase();

    return db.update(
      'shopping_items',
      {
        'name': trimmedName,
        'quantity': quantity,
        if (category != null) 'category': category.databaseValue,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await _openDatabase();

    return db.delete(
      'shopping_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}