enum ShoppingCategory {
  other('other', 'Sonstiges'),
  fruitVegetables('fruit_vegetables', 'Obst & Gemüse'),
  dairy('dairy', 'Milchprodukte & Eier'),
  bakery('bakery', 'Brot & Backwaren'),
  meatFish('meat_fish', 'Fleisch & Fisch'),
  pantry('pantry', 'Vorrat'),
  beverages('beverages', 'Getränke'),
  household('household', 'Haushalt');

  final String databaseValue;
  final String label;


  const ShoppingCategory(this.databaseValue, this.label);

  static ShoppingCategory fromDatabaseValue(String? value) {
    return ShoppingCategory.values.firstWhere(
          (category) => category.databaseValue == value,
      orElse: () => ShoppingCategory.other,
    );
  }
}