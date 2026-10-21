import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_list_app/models/shopping_list.dart';
import 'package:shopping_list_app/repositories/shopping_list_repository.dart';
import 'package:shopping_list_app/screens/shopping_lists_page.dart';
import 'package:shopping_list_app/models/shopping_item.dart';
import 'package:shopping_list_app/repositories/shopping_repository.dart';
import 'package:shopping_list_app/screens/shopping_list_page.dart';

class ListsTestRepository implements ShoppingListRepository {
  final Future<List<ShoppingList>> Function() onLoad;

  ListsTestRepository({required this.onLoad});

  @override
  Future<List<ShoppingList>> loadLists() => onLoad();

  @override
  Future<int> addList(String name) {
    throw UnsupportedError('Not used in loading tests.');
  }

  @override
  Future<int> renameList({
    required int id,
    required String name,
  }) {
    throw UnsupportedError('Not used in loading tests.');
  }
}

class AddListTestRepository extends ListsTestRepository {
  final Future<int> Function(String name) onAdd;

  AddListTestRepository({required this.onAdd})
      : super(onLoad: () async => <ShoppingList>[]);

  @override
  Future<int> addList(String name) => onAdd(name);
}

class NavigationItemsRepository extends ShoppingRepository {
  final List<ShoppingItem> items;

  NavigationItemsRepository(this.items)
      : super(
    openDatabase: () {
      throw StateError('Navigation tests must not open a database.');
    },
  );

  @override
  Future<List<ShoppingItem>> loadItems() async => items;
}

class RenameListTestRepository extends ListsTestRepository {
  final Future<int> Function(int id, String name) onRename;

  RenameListTestRepository({
    required List<ShoppingList> lists,
    required this.onRename,
  }) : super(onLoad: () async => lists);

  @override
  Future<int> renameList({
    required int id,
    required String name,
  }) {
    return onRename(id, name);
  }
}

void main() {
  testWidgets('Shows loading until shopping lists arrive', (tester) async {
    final pendingLoad = Completer<List<ShoppingList>>();
    var loadCalls = 0;

    final repository = ListsTestRepository(
      onLoad: () {
        loadCalls++;
        return pendingLoad.future;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ShoppingListsPage(repository: repository),
      ),
    );

    expect(loadCalls, 1);
    expect(find.text('Meine Einkaufslisten'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(
      find.text('Noch keine Einkaufslisten vorhanden.'),
      findsNothing,
    );

    pendingLoad.complete([
      ShoppingList(id: 1, name: 'Einkaufsliste'),
      ShoppingList(id: 4, name: 'Wochenende'),
    ]);

    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(ListTile), findsNWidgets(2));
    expect(find.text('Einkaufsliste'), findsOneWidget);
    expect(find.text('Wochenende'), findsOneWidget);
    expect(
      find.text('Noch keine Einkaufslisten vorhanden.'),
      findsNothing,
    );
    expect(loadCalls, 1);
  });

  testWidgets('Shows an empty message when no shopping lists exist',
          (tester) async {
        final repository = ListsTestRepository(
          onLoad: () async => <ShoppingList>[],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListsPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Meine Einkaufslisten'), findsOneWidget);
        expect(
          find.text('Noch keine Einkaufslisten vorhanden.'),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(ListTile), findsNothing);
        expect(find.text('Erneut versuchen'), findsNothing);
      });

  testWidgets('Failed loading of shopping lists can be retried',
          (tester) async {
        var loadCalls = 0;
        final retryLoad = Completer<List<ShoppingList>>();

        final repository = ListsTestRepository(
          onLoad: () async {
            loadCalls++;

            if (loadCalls == 1) {
              throw StateError('Simulated shopping lists loading failure');
            }

            return retryLoad.future;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListsPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        expect(loadCalls, 1);
        expect(
          find.text('Die Einkaufslisten konnten nicht geladen werden.'),
          findsOneWidget,
        );
        expect(find.text('Erneut versuchen'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(ListTile), findsNothing);
        expect(
          find.text('Noch keine Einkaufslisten vorhanden.'),
          findsNothing,
        );

        await tester.tap(
          find.widgetWithText(FilledButton, 'Erneut versuchen'),
        );
        await tester.pump();

        expect(loadCalls, 2);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          find.text('Die Einkaufslisten konnten nicht geladen werden.'),
          findsNothing,
        );
        expect(find.text('Erneut versuchen'), findsNothing);

        retryLoad.complete([
          ShoppingList(id: 1, name: 'Einkaufsliste'),
        ]);
        await tester.pumpAndSettle();

        expect(loadCalls, 2);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(ListTile), findsOneWidget);
        expect(find.text('Einkaufsliste'), findsOneWidget);
        expect(
          find.text('Die Einkaufslisten konnten nicht geladen werden.'),
          findsNothing,
        );
      });

  testWidgets('Adding a shopping list saves and displays its trimmed name',
          (tester) async {
        String? submittedName;
        var addCalls = 0;

        final repository = AddListTestRepository(
          onAdd: (name) async {
            addCalls++;
            submittedName = name;
            return 4;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListsPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.enterText(
          find.byType(EditableText),
          '  Wochenende  ',
        );

        await tester.tap(
          find.widgetWithText(TextButton, 'Hinzufügen'),
        );
        await tester.pumpAndSettle();

        expect(addCalls, 1);
        expect(submittedName, 'Wochenende');
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(ListTile), findsOneWidget);
        expect(find.text('Wochenende'), findsOneWidget);
        expect(
          find.text('Noch keine Einkaufslisten vorhanden.'),
          findsNothing,
        );
      });

  testWidgets('Invalid list names are rejected until corrected',
          (tester) async {
        var addCalls = 0;
        String? submittedName;

        final repository = AddListTestRepository(
          onAdd: (name) async {
            addCalls++;
            submittedName = name;
            return 4;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListsPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        for (final invalidName in ['', '   ']) {
          await tester.enterText(
            find.byType(EditableText),
            invalidName,
          );

          await tester.tap(
            find.widgetWithText(TextButton, 'Hinzufügen'),
          );
          await tester.pumpAndSettle();

          expect(addCalls, 0);
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(
            find.text('Bitte einen Namen eingeben.'),
            findsOneWidget,
          );
          expect(find.byType(ListTile), findsNothing);
        }

        await tester.enterText(
          find.byType(EditableText),
          'Wochenende',
        );

        await tester.tap(
          find.widgetWithText(TextButton, 'Hinzufügen'),
        );
        await tester.pumpAndSettle();

        expect(addCalls, 1);
        expect(submittedName, 'Wochenende');
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(ListTile), findsOneWidget);
        expect(find.text('Wochenende'), findsOneWidget);
      });

  testWidgets('Cancelling list creation does not save a list',
          (tester) async {
        var addCalls = 0;

        final repository = AddListTestRepository(
          onAdd: (name) async {
            addCalls++;
            return 4;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListsPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(EditableText),
          'Wochenende',
        );

        await tester.tap(
          find.widgetWithText(TextButton, 'Abbrechen'),
        );
        await tester.pumpAndSettle();

        expect(addCalls, 0);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(ListTile), findsNothing);
        expect(
          find.text('Noch keine Einkaufslisten vorhanden.'),
          findsOneWidget,
        );

        // Opening the dialog again starts with an empty name.
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        final input = tester.widget<EditableText>(
          find.byType(EditableText),
        );

        expect(input.controller.text, isEmpty);
        expect(
          find.text('Bitte einen Namen eingeben.'),
          findsNothing,
        );

        await tester.tap(
          find.widgetWithText(TextButton, 'Abbrechen'),
        );
        await tester.pumpAndSettle();

        expect(addCalls, 0);
        expect(find.byType(AlertDialog), findsNothing);
      });

  testWidgets('Failed list creation preserves the name and allows retry',
          (tester) async {
        final submittedNames = <String>[];

        final repository = AddListTestRepository(
          onAdd: (name) async {
            submittedNames.add(name);

            if (submittedNames.length == 1) {
              throw StateError('Simulated list creation failure');
            }

            return 4;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListsPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(EditableText),
          'Wochenende',
        );

        final saveButton = find.widgetWithText(
          TextButton,
          'Hinzufügen',
        );

        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(submittedNames, ['Wochenende']);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text('Speichern fehlgeschlagen. Bitte erneut versuchen.'),
          findsOneWidget,
        );
        expect(find.byType(ListTile), findsNothing);

        final input = tester.widget<EditableText>(
          find.byType(EditableText),
        );

        expect(input.controller.text, 'Wochenende');
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isTrue,
        );
        expect(
          tester.widget<TextButton>(saveButton).onPressed,
          isNotNull,
        );

        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(submittedNames, ['Wochenende', 'Wochenende']);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(ListTile), findsOneWidget);
        expect(find.text('Wochenende'), findsOneWidget);
        expect(
          find.text('Noch keine Einkaufslisten vorhanden.'),
          findsNothing,
        );
      });

  testWidgets('Repeated save taps create only one shopping list',
          (tester) async {
        final pendingSave = Completer<int>();
        var addCalls = 0;

        final repository = AddListTestRepository(
          onAdd: (name) {
            addCalls++;
            return pendingSave.future;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListsPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(EditableText),
          'Wochenende',
        );

        final saveButton = find.widgetWithText(
          TextButton,
          'Hinzufügen',
        );

        // Both taps happen before the dialog rebuilds.
        await tester.tap(saveButton);
        await tester.tap(saveButton);
        await tester.pump();

        expect(addCalls, 1);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(ListTile), findsNothing);

        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        expect(
          tester
              .widget<TextButton>(
            find.widgetWithText(TextButton, 'Wird gespeichert…'),
          )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<TextButton>(
            find.widgetWithText(TextButton, 'Abbrechen'),
          )
              .onPressed,
          isNull,
        );

        pendingSave.complete(4);
        await tester.pumpAndSettle();

        expect(addCalls, 1);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(ListTile), findsOneWidget);
        expect(find.text('Wochenende'), findsOneWidget);
      });

  testWidgets('Opening different lists shows their own products',
          (tester) async {
        final requestedListIds = <int>[];

        final listsRepository = ListsTestRepository(
          onLoad: () async => [
            ShoppingList(id: 1, name: 'Einkaufsliste'),
            ShoppingList(id: 4, name: 'Wochenende'),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListsPage(
              repository: listsRepository,
              itemRepositoryFactory: (listId) {
                requestedListIds.add(listId);

                if (listId == 1) {
                  return NavigationItemsRepository([
                    ShoppingItem(id: 7, name: 'Milch', listId: 1),
                  ]);
                }

                if (listId == 4) {
                  return NavigationItemsRepository([
                    ShoppingItem(id: 8, name: 'Brot', listId: 4),
                  ]);
                }

                throw StateError('Unexpected list ID: $listId');
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(requestedListIds, isEmpty);

        await tester.tap(find.text('Wochenende'));
        await tester.pumpAndSettle();

        expect(requestedListIds.last, 4);
        expect(
          tester.widget<ShoppingListPage>(
            find.byType(ShoppingListPage),
          ).listId,
          4,
        );
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Wochenende'),
          ),
          findsOneWidget,
        );
        expect(find.text('Brot'), findsOneWidget);
        expect(find.text('Milch'), findsNothing);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.text('Meine Einkaufslisten'), findsOneWidget);
        expect(find.byType(ShoppingListPage), findsNothing);
        expect(find.byType(ListTile), findsNWidgets(2));

        await tester.tap(find.text('Einkaufsliste'));
        await tester.pumpAndSettle();

        expect(requestedListIds.last, 1);
        expect(
          tester.widget<ShoppingListPage>(
            find.byType(ShoppingListPage),
          ).listId,
          1,
        );
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Einkaufsliste'),
          ),
          findsOneWidget,
        );
        expect(find.text('Milch'), findsOneWidget);
        expect(find.text('Brot'), findsNothing);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.text('Meine Einkaufslisten'), findsOneWidget);
        expect(find.byType(ShoppingListPage), findsNothing);
        expect(find.byType(ListTile), findsNWidgets(2));
      });

  testWidgets('Renaming a list shows its current name and saves the change',
          (tester) async {
        var renameCalls = 0;
        int? submittedId;
        String? submittedName;

        final repository = RenameListTestRepository(
          lists: [
            ShoppingList(id: 4, name: 'Wochenende'),
          ],
          onRename: (id, name) async {
            renameCalls++;
            submittedId = id;
            submittedName = name;
            return 1;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListsPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Liste umbenennen'));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'Wochenende',
        );

        await tester.enterText(
          find.byType(EditableText),
          '  Wocheneinkauf  ',
        );

        await tester.tap(
          find.widgetWithText(TextButton, 'Speichern'),
        );
        await tester.pumpAndSettle();

        expect(renameCalls, 1);
        expect(submittedId, 4);
        expect(submittedName, 'Wocheneinkauf');
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(ListTile), findsOneWidget);
        expect(find.text('Wocheneinkauf'), findsOneWidget);
        expect(find.text('Wochenende'), findsNothing);

        // Reopening must show the updated name.
        await tester.tap(find.byTooltip('Liste umbenennen'));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'Wocheneinkauf',
        );

        await tester.tap(
          find.widgetWithText(TextButton, 'Abbrechen'),
        );
        await tester.pumpAndSettle();

        expect(renameCalls, 1);
      });

  testWidgets('Cancelling list renaming preserves the original name',
          (tester) async {
        var renameCalls = 0;

        final repository = RenameListTestRepository(
          lists: [
            ShoppingList(id: 4, name: 'Wochenende'),
          ],
          onRename: (id, name) async {
            renameCalls++;
            return 1;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListsPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Liste umbenennen'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(EditableText),
          'Wocheneinkauf',
        );

        await tester.tap(
          find.widgetWithText(TextButton, 'Abbrechen'),
        );
        await tester.pumpAndSettle();

        expect(renameCalls, 0);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(ListTile), findsOneWidget);
        expect(find.text('Wochenende'), findsOneWidget);
        expect(find.text('Wocheneinkauf'), findsNothing);

        await tester.tap(find.byTooltip('Liste umbenennen'));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'Wochenende',
        );

        await tester.tap(
          find.widgetWithText(TextButton, 'Abbrechen'),
        );
        await tester.pumpAndSettle();

        expect(renameCalls, 0);
        expect(find.byType(AlertDialog), findsNothing);
      });

  testWidgets('Invalid rename input is rejected until corrected',
          (tester) async {
        var renameCalls = 0;
        int? submittedId;
        String? submittedName;

        final repository = RenameListTestRepository(
          lists: [
            ShoppingList(id: 4, name: 'Wochenende'),
          ],
          onRename: (id, name) async {
            renameCalls++;
            submittedId = id;
            submittedName = name;
            return 1;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListsPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Liste umbenennen'));
        await tester.pumpAndSettle();

        for (final invalidName in ['', '   ']) {
          await tester.enterText(
            find.byType(EditableText),
            invalidName,
          );

          await tester.tap(
            find.widgetWithText(TextButton, 'Speichern'),
          );
          await tester.pumpAndSettle();

          expect(renameCalls, 0);
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(
            find.text('Bitte einen Namen eingeben.'),
            findsOneWidget,
          );

          expect(
            find.descendant(
              of: find.byType(ListTile),
              matching: find.text('Wochenende'),
            ),
            findsOneWidget,
          );
        }

        await tester.enterText(
          find.byType(EditableText),
          'Wocheneinkauf',
        );

        await tester.tap(
          find.widgetWithText(TextButton, 'Speichern'),
        );
        await tester.pumpAndSettle();

        expect(renameCalls, 1);
        expect(submittedId, 4);
        expect(submittedName, 'Wocheneinkauf');
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(ListTile), findsOneWidget);
        expect(find.text('Wocheneinkauf'), findsOneWidget);
        expect(find.text('Wochenende'), findsNothing);
      });

  testWidgets('Failed list renaming preserves input and allows retry',
          (tester) async {
        final submittedIds = <int>[];
        final submittedNames = <String>[];

        final repository = RenameListTestRepository(
          lists: [
            ShoppingList(id: 4, name: 'Wochenende'),
          ],
          onRename: (id, name) async {
            submittedIds.add(id);
            submittedNames.add(name);

            if (submittedNames.length == 1) {
              throw StateError('Simulated list renaming failure');
            }

            return 1;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListsPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Liste umbenennen'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(EditableText),
          'Wocheneinkauf',
        );

        final saveButton = find.widgetWithText(
          TextButton,
          'Speichern',
        );

        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(submittedIds, [4]);
        expect(submittedNames, ['Wocheneinkauf']);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.text('Speichern fehlgeschlagen. Bitte erneut versuchen.'),
          findsOneWidget,
        );

        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'Wocheneinkauf',
        );
        expect(
          tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
          isTrue,
        );
        expect(
          tester.widget<TextButton>(saveButton).onPressed,
          isNotNull,
        );

        expect(
          find.descendant(
            of: find.byType(ListTile),
            matching: find.text('Wochenende'),
          ),
          findsOneWidget,
        );

        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(submittedIds, [4, 4]);
        expect(submittedNames, ['Wocheneinkauf', 'Wocheneinkauf']);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(ListTile), findsOneWidget);
        expect(find.text('Wocheneinkauf'), findsOneWidget);
        expect(find.text('Wochenende'), findsNothing);
      });

  testWidgets('Repeated save taps rename a list only once',
          (tester) async {
        final pendingSave = Completer<int>();
        var renameCalls = 0;
        int? submittedId;
        String? submittedName;

        final repository = RenameListTestRepository(
          lists: [
            ShoppingList(id: 4, name: 'Wochenende'),
          ],
          onRename: (id, name) {
            renameCalls++;
            submittedId = id;
            submittedName = name;
            return pendingSave.future;
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ShoppingListsPage(repository: repository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Liste umbenennen'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(EditableText),
          'Wocheneinkauf',
        );

        final saveButton = find.widgetWithText(
          TextButton,
          'Speichern',
        );

        // Both taps happen before the dialog rebuilds.
        await tester.tap(saveButton);
        await tester.tap(saveButton);
        await tester.pump();

        expect(renameCalls, 1);
        expect(submittedId, 4);
        expect(submittedName, 'Wocheneinkauf');
        expect(find.byType(AlertDialog), findsOneWidget);

        expect(
          tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
          isFalse,
        );
        expect(
          tester
              .widget<TextButton>(
            find.widgetWithText(TextButton, 'Wird gespeichert…'),
          )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<TextButton>(
            find.widgetWithText(TextButton, 'Abbrechen'),
          )
              .onPressed,
          isNull,
        );
        expect(
          find.descendant(
            of: find.byType(ListTile),
            matching: find.text('Wochenende'),
          ),
          findsOneWidget,
        );

        pendingSave.complete(1);
        await tester.pumpAndSettle();

        expect(renameCalls, 1);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(ListTile), findsOneWidget);
        expect(find.text('Wocheneinkauf'), findsOneWidget);
        expect(find.text('Wochenende'), findsNothing);
      });
}