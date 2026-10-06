import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/models/shopping_item.dart';
import 'package:shopping_list_app/repositories/shopping_repository.dart';
import 'package:shopping_list_app/screens/shopping_list_page.dart';

class LoadingTestRepository implements ShoppingRepository {
  final Future<List<ShoppingItem>> Function() onLoad;

  LoadingTestRepository({required this.onLoad});

  @override
  Future<List<ShoppingItem>> loadItems() => onLoad();

  @override
  Future<int> addItem(ShoppingItem item) {
    throw UnsupportedError('Not used in loading tests.');
  }

  @override
  Future<int> setBought({
    required int id,
    required bool isBought,
  }) {
    throw UnsupportedError('Not used in loading tests.');
  }

  @override
  Future<int> deleteItem(int id) {
    throw UnsupportedError('Not used in loading tests.');
  }
}

class AddTestRepository extends LoadingTestRepository {
  final Future<int> Function(ShoppingItem item) onAdd;

  AddTestRepository({required this.onAdd})
      : super(onLoad: () async => <ShoppingItem>[]);

  @override
  Future<int> addItem(ShoppingItem item) => onAdd(item);
}

class PurchaseTestRepository extends LoadingTestRepository {
  final Future<int> Function(int id, bool isBought) onSetBought;

  PurchaseTestRepository({
    required List<ShoppingItem> items,
    required this.onSetBought,
  }) : super(onLoad: () async => items);

  @override
  Future<int> setBought({
    required int id,
    required bool isBought,
  }) {
    return onSetBought(id, isBought);
  }
}

class DeleteTestRepository extends LoadingTestRepository {
  final Future<int> Function(int id) onDelete;

  DeleteTestRepository({
    required List<ShoppingItem> items,
    required this.onDelete,
  }) : super(onLoad: () async => items);

  @override
  Future<int> deleteItem(int id) => onDelete(id);
}

void main() {
  testWidgets('Shows loading until products arrive', (tester) async {
    final pendingLoad = Completer<List<ShoppingItem>>();

    final repository = LoadingTestRepository(
      onLoad: () => pendingLoad.future,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ShoppingListPage(repository: repository),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Die Einkaufsliste ist leer.'), findsNothing);

    final addButton = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(addButton.onPressed, isNull);

    pendingLoad.complete([
      ShoppingItem(id: 1, name: 'Milch', quantity: 3),
    ]);

    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Milch'), findsOneWidget);
    expect(find.text('Menge: 3'), findsOneWidget);

    final enabledAddButton = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(enabledAddButton.onPressed, isNotNull);
  });

  testWidgets('Shows empty message after loading an empty list',
          (tester) async {
        final repository = LoadingTestRepository(
          onLoad: () async => <ShoppingItem>[],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Die Einkaufsliste ist leer.'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Erneut versuchen'), findsNothing);
      });

  testWidgets('Failed loading can be retried successfully', (tester) async {
    var loadCalls = 0;

    final repository = LoadingTestRepository(
      onLoad: () async {
        loadCalls++;

        if (loadCalls == 1) {
          throw StateError('Simulated loading failure');
        }

        return [
          ShoppingItem(id: 1, name: 'Brot', quantity: 2),
        ];
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ShoppingListPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Die Einkaufsliste konnte nicht geladen werden.'),
      findsOneWidget,
    );
    expect(find.text('Die Einkaufsliste ist leer.'), findsNothing);
    expect(loadCalls, 1);

    final addButton = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(addButton.onPressed, isNull);

    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();

    expect(loadCalls, 2);
    expect(find.text('Brot'), findsOneWidget);
    expect(find.text('Menge: 2'), findsOneWidget);
    expect(
      find.text('Die Einkaufsliste konnte nicht geladen werden.'),
      findsNothing,
    );
    expect(find.text('Erneut versuchen'), findsNothing);

    final enabledAddButton = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(enabledAddButton.onPressed, isNotNull);
  });

  testWidgets('Failed addition preserves input and can be retried',
          (tester) async {
        var addCalls = 0;
        final submittedItems = <ShoppingItem>[];

        final repository = AddTestRepository(
          onAdd: (item) async {
            addCalls++;
            submittedItems.add(item);

            if (addCalls == 1) {
              throw StateError('Simulated saving failure');
            }

            return 7;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        final inputs = find.byType(EditableText);
        expect(inputs, findsNWidgets(2));

        await tester.enterText(inputs.at(0), 'Milch');
        await tester.enterText(inputs.at(1), '3');

        await tester.tap(find.text('Hinzufügen'));
        await tester.pumpAndSettle();

        expect(addCalls, 1);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text('Speichern fehlgeschlagen. Bitte erneut versuchen.'),
          findsOneWidget,
        );

        final nameField = tester.widget<EditableText>(inputs.at(0));
        final quantityField = tester.widget<EditableText>(inputs.at(1));

        expect(nameField.controller.text, 'Milch');
        expect(quantityField.controller.text, '3');
        expect(find.byType(ListTile), findsNothing);

        await tester.tap(find.text('Hinzufügen'));
        await tester.pumpAndSettle();

        expect(addCalls, 2);

        for (final item in submittedItems) {
          expect(item.name, 'Milch');
          expect(item.quantity, 3);
        }

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(ListTile), findsOneWidget);
        expect(find.text('Milch'), findsOneWidget);
        expect(find.text('Menge: 3'), findsOneWidget);
      });

  testWidgets('Repeated add taps save only one item', (tester) async {
    final pendingSave = Completer<int>();
    var addCalls = 0;

    final repository = AddTestRepository(
      onAdd: (item) {
        addCalls++;
        return pendingSave.future;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ShoppingListPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final inputs = find.byType(EditableText);

    await tester.enterText(inputs.at(0), 'Milch');
    await tester.enterText(inputs.at(1), '3');

    final addButton = find.widgetWithText(TextButton, 'Hinzufügen');

    // Two taps before the dialog rebuilds.
    await tester.tap(addButton);
    await tester.tap(addButton);

    expect(addCalls, 1);

    await tester.pump();

    expect(find.text('Wird gespeichert…'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);

    final savingButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Wird gespeichert…'),
    );
    final cancelButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Abbrechen'),
    );

    expect(savingButton.onPressed, isNull);
    expect(cancelButton.onPressed, isNull);

    final inputFields = tester.widgetList<TextField>(
      find.byType(TextField),
    );

    expect(inputFields, hasLength(2));
    for (final field in inputFields) {
      expect(field.enabled, isFalse);
    }

    pendingSave.complete(7);
    await tester.pumpAndSettle();

    expect(addCalls, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('Milch'), findsOneWidget);
    expect(find.text('Menge: 3'), findsOneWidget);
  });

  testWidgets('Failed purchase update preserves state and allows retry',
          (tester) async {
        var updateCalls = 0;
        final requestedIds = <int>[];
        final requestedValues = <bool>[];

        final repository = PurchaseTestRepository(
          items: [
            ShoppingItem(id: 7, name: 'Milch', quantity: 3),
          ],
          onSetBought: (id, isBought) async {
            updateCalls++;
            requestedIds.add(id);
            requestedValues.add(isBought);

            if (updateCalls == 1) {
              throw StateError('Simulated purchase update failure');
            }

            return 1;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<Checkbox>(find.byType(Checkbox)).value,
          isFalse,
        );

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        expect(updateCalls, 1);
        expect(
          find.text(
            'Änderung konnte nicht gespeichert werden. Bitte erneut versuchen.',
          ),
          findsOneWidget,
        );

        final checkboxAfterFailure = tester.widget<Checkbox>(
          find.byType(Checkbox),
        );

        expect(checkboxAfterFailure.value, isFalse);
        expect(checkboxAfterFailure.onChanged, isNotNull);

        final deleteButton = tester.widget<IconButton>(
          find.byWidgetPredicate(
                (widget) =>
            widget is IconButton &&
                widget.tooltip == 'Produkt löschen',
          ),
        );
        expect(deleteButton.onPressed, isNotNull);

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        expect(updateCalls, 2);
        expect(requestedIds, [7, 7]);
        expect(requestedValues, [true, true]);

        final checkboxAfterSuccess = tester.widget<Checkbox>(
          find.byType(Checkbox),
        );

        expect(checkboxAfterSuccess.value, isTrue);
        expect(checkboxAfterSuccess.onChanged, isNotNull);

        final productText = tester.widget<Text>(find.text('Milch'));
        expect(
          productText.style?.decoration,
          TextDecoration.lineThrough,
        );
      });

  testWidgets('Failed deletion preserves item and allows retry',
          (tester) async {
        var deleteCalls = 0;
        final requestedIds = <int>[];

        final repository = DeleteTestRepository(
          items: [
            ShoppingItem(id: 7, name: 'Milch', quantity: 3),
          ],
          onDelete: (id) async {
            deleteCalls++;
            requestedIds.add(id);

            if (deleteCalls == 1) {
              throw StateError('Simulated deletion failure');
            }

            return 1;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        final deleteButtonFinder = find.byWidgetPredicate(
              (widget) =>
          widget is IconButton &&
              widget.tooltip == 'Produkt löschen',
        );

        await tester.tap(deleteButtonFinder);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(deleteCalls, 0);

        await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
        await tester.pumpAndSettle();

        expect(deleteCalls, 1);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Milch'), findsOneWidget);
        expect(find.text('Menge: 3'), findsOneWidget);
        expect(
          find.text('Löschen fehlgeschlagen. Bitte erneut versuchen.'),
          findsOneWidget,
        );

        final deleteButton = tester.widget<IconButton>(
          deleteButtonFinder,
        );
        expect(deleteButton.onPressed, isNotNull);

        final checkbox = tester.widget<Checkbox>(
          find.byType(Checkbox),
        );
        expect(checkbox.onChanged, isNotNull);

        await tester.tap(deleteButtonFinder);
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
        await tester.pumpAndSettle();

        expect(deleteCalls, 2);
        expect(requestedIds, [7, 7]);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(ListTile), findsNothing);
        expect(find.text('Milch'), findsNothing);
        expect(find.text('Die Einkaufsliste ist leer.'), findsOneWidget);
      });

  testWidgets('Cancelling deletion keeps item and restores controls',
          (tester) async {
        var deleteCalls = 0;

        final repository = DeleteTestRepository(
          items: [
            ShoppingItem(id: 7, name: 'Milch', quantity: 3),
          ],
          onDelete: (id) async {
            deleteCalls++;
            return 1;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        final deleteButtonFinder = find.byWidgetPredicate(
              (widget) =>
          widget is IconButton &&
              widget.tooltip == 'Produkt löschen',
        );

        await tester.tap(deleteButtonFinder);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(deleteCalls, 0);

        await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
        await tester.pumpAndSettle();

        expect(deleteCalls, 0);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Milch'), findsOneWidget);
        expect(find.text('Menge: 3'), findsOneWidget);

        final checkbox = tester.widget<Checkbox>(
          find.byType(Checkbox),
        );
        expect(checkbox.value, isFalse);
        expect(checkbox.onChanged, isNotNull);

        final deleteButton = tester.widget<IconButton>(
          deleteButtonFinder,
        );
        expect(deleteButton.onPressed, isNotNull);
      });
}