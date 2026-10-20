import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/models/shopping_list.dart';

void main() {
  group('ShoppingList', () {
    test('New list has a name and no database id', () {
      final list = ShoppingList(name: 'Wocheneinkauf');

      expect(list.id, isNull);
      expect(list.name, 'Wocheneinkauf');
    });

    test('New list is mapped without a database id', () {
      final list = ShoppingList(name: 'Wocheneinkauf');

      expect(list.toMap(), {
        'name': 'Wocheneinkauf',
      });
    });

    test('Stored list preserves its values when read and mapped', () {
      final storedValues = <String, Object?>{
        'id': 7,
        'name': 'Wocheneinkauf',
      };

      final list = ShoppingList.fromMap(storedValues);

      expect(list.id, 7);
      expect(list.name, 'Wocheneinkauf');
      expect(list.toMap(), storedValues);
    });
  });
}