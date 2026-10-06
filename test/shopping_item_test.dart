import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/models/shopping_item.dart';

void main() {
  group('ShoppingItem', () {
    test('New item has default quantity and purchase status', () {
      final item = ShoppingItem(name: 'Milch');

      expect(item.id, isNull);
      expect(item.quantity, 1);
      expect(item.isBought, isFalse);
    });

    test('New item is mapped without a database id', () {
      final item = ShoppingItem(
        name: 'Milch',
        quantity: 3,
      );

      expect(item.toMap(), {
        'name': 'Milch',
        'quantity': 3,
        'isBought': 0,
      });
    });

    test('Stored item is read with all its values', () {
      final item = ShoppingItem.fromMap({
        'id': 7,
        'name': 'Brot',
        'quantity': 2,
        'isBought': 1,
      });

      expect(item.id, 7);
      expect(item.name, 'Brot');
      expect(item.quantity, 2);
      expect(item.isBought, isTrue);
    });

    test('Purchase status uses SQLite integer values', () {
      for (final isBought in [false, true]) {
        final item = ShoppingItem(
          id: 7,
          name: 'Brot',
          isBought: isBought,
        );

        final map = item.toMap();

        expect(map['id'], 7);
        expect(map['isBought'], isBought ? 1 : 0);
        expect(ShoppingItem.fromMap(map).isBought, isBought);
      }
    });
  });
}