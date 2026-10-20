class ShoppingList {
  final int? id;
  final String name;

  ShoppingList({
    this.id,
    required this.name,
  });

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
    };
  }

  factory ShoppingList.fromMap(Map<String, Object?> map) {
    return ShoppingList(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }
}