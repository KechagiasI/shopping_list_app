class ShoppingItem {
  final int? id;
  final String name;
  final int quantity;
  bool isBought;

  ShoppingItem({
    this.id,
    required this.name,
    this.quantity = 1,
    this.isBought = false,
  });

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'quantity': quantity,
      'isBought': isBought ? 1 : 0,
    };
  }

  factory ShoppingItem.fromMap(Map<String, Object?> map) {
    return ShoppingItem(
      id: map['id'] as int,
      name: map['name'] as String,
      quantity: map['quantity'] as int,
      isBought: map['isBought'] == 1,
    );
  }
}