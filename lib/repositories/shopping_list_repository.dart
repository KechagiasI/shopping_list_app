import 'package:sqflite/sqflite.dart';

import '../models/shopping_list.dart';
import '../services/shopping_database.dart';

class ShoppingListRepository {
  final Future<Database> Function() _openDatabase;

  ShoppingListRepository({
    Future<Database> Function()? openDatabase,
  }) : _openDatabase = openDatabase ?? ShoppingDatabase.open;

  Future<List<ShoppingList>> loadLists() async {
    final db = await _openDatabase();

    final rows = await db.query(
      'shopping_lists',
      orderBy: 'id ASC',
    );

    return rows
        .map((row) => ShoppingList.fromMap(row))
        .toList();
  }

  Future<int> addList(String name) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'Must not be empty.',
      );
    }

    final db = await _openDatabase();

    return db.insert(
      'shopping_lists',
      ShoppingList(name: trimmedName).toMap(),
    );
  }

  Future<int> renameList({
    required int id,
    required String name,
  }) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError.value(
        name,
        'name',
        'Must not be empty.',
      );
    }

    final db = await _openDatabase();

    return db.update(
      'shopping_lists',
      {'name': trimmedName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}