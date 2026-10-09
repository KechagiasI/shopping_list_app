import 'shopping_category.dart';

class ShoppingItem {
  final int? id;
  final String name;
  final int quantity;
  final ShoppingCategory category;
  bool isBought;

  ShoppingItem({
    this.id,
    required this.name,
    this.quantity = 1,
    this.category = ShoppingCategory.other,
    this.isBought = false,
  });

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'quantity': quantity,
      'category': category.databaseValue,
      'isBought': isBought ? 1 : 0,
    };
  }

  factory ShoppingItem.fromMap(Map<String, Object?> map) {
    return ShoppingItem(
      id: map['id'] as int,
      name: map['name'] as String,
      quantity: map['quantity'] as int,
      category: ShoppingCategory.fromDatabaseValue(
        map['category'] as String?,
      ),
      isBought: map['isBought'] == 1,
    );
  }
}