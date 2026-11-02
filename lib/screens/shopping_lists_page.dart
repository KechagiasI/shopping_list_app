import 'package:flutter/material.dart';

import '../models/shopping_list.dart';
import '../repositories/shopping_list_repository.dart';
import 'shopping_list_page.dart';
import '../repositories/shopping_repository.dart';

class ShoppingListsPage extends StatefulWidget {
  final ShoppingListRepository? repository;
  final ShoppingRepository Function(int listId)? itemRepositoryFactory;

  const ShoppingListsPage({
    super.key,
    this.repository,
    this.itemRepositoryFactory,
  });

  @override
  State<ShoppingListsPage> createState() => _ShoppingListsPageState();
}

class _ShoppingListsPageState extends State<ShoppingListsPage> {
  late final ShoppingListRepository _repository;

  final List<ShoppingList> _lists = [];
  final Set<int> _deletingListIds = {};
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ShoppingListRepository();
    _loadLists();
  }

  Future<void> _loadLists() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final lists = await _repository.loadLists();

      if (!mounted) return;

      setState(() {
        _lists
          ..clear()
          ..addAll(lists);
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load shopping lists: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = 'Die Einkaufslisten konnten nicht geladen werden.';
      });
    }
  }

  void _openList(ShoppingList list) {
    final id = list.id;

    if (id == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ShoppingListPage(
          repository: widget.itemRepositoryFactory?.call(id),
          listId: id,
          listName: list.name,
        ),
      ),
    );
  }

  Future<void> _showAddListDialog() async {
    String newName = '';
    String? errorMessage;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return PopScope(
              canPop: !isSaving,
              child: AlertDialog(
                title: const Text('Neue Einkaufsliste'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        enabled: !isSaving,
                        onChanged: (value) {
                          newName = value;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Name der Liste',
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text('Abbrechen'),
                  ),
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                      if (isSaving) return;

                      final name = newName.trim();

                      if (name.isEmpty) {
                        setDialogState(() {
                          errorMessage =
                          'Bitte einen Namen eingeben.';
                        });
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                        errorMessage = null;
                      });

                      try {
                        final id = await _repository.addList(name);

                        if (!mounted) return;

                        setState(() {
                          _lists.add(
                            ShoppingList(id: id, name: name),
                          );
                        });
                      } catch (error, stackTrace) {
                        debugPrint(
                          'Failed to add shopping list: $error',
                        );
                        debugPrintStack(stackTrace: stackTrace);

                        if (!dialogContext.mounted) return;

                        setDialogState(() {
                          isSaving = false;
                          errorMessage =
                          'Speichern fehlgeschlagen. Bitte erneut versuchen.';
                        });
                        return;
                      }

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
                    child: Text(
                      isSaving ? 'Wird gespeichert…' : 'Hinzufügen',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showRenameListDialog(ShoppingList list) async {
    final id = list.id;
    if (id == null) return;

    String editedName = list.name;
    String? errorMessage;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return PopScope(
              canPop: !isSaving,
              child: AlertDialog(
                title: const Text('Liste umbenennen'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        initialValue: list.name,
                        enabled: !isSaving,
                        onChanged: (value) {
                          editedName = value;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Name der Liste',
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text('Abbrechen'),
                  ),
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                      if (isSaving) return;

                      final name = editedName.trim();

                      if (name.isEmpty) {
                        setDialogState(() {
                          errorMessage =
                          'Bitte einen Namen eingeben.';
                        });
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                        errorMessage = null;
                      });

                      try {
                        final updatedRows =
                        await _repository.renameList(
                          id: id,
                          name: name,
                        );

                        if (updatedRows != 1) {
                          throw StateError(
                            'Expected to rename one shopping list.',
                          );
                        }

                        if (!mounted) return;

                        final index = _lists.indexWhere(
                              (existingList) => existingList.id == id,
                        );

                        if (index != -1) {
                          setState(() {
                            _lists[index] = ShoppingList(
                              id: id,
                              name: name,
                            );
                          });
                        }
                      } catch (error, stackTrace) {
                        debugPrint(
                          'Failed to rename shopping list: $error',
                        );
                        debugPrintStack(stackTrace: stackTrace);

                        if (!dialogContext.mounted) return;

                        setDialogState(() {
                          isSaving = false;
                          errorMessage =
                          'Speichern fehlgeschlagen. Bitte erneut versuchen.';
                        });
                        return;
                      }

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
                    child: Text(
                      isSaving ? 'Wird gespeichert…' : 'Speichern',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteList(ShoppingList list) async {
    final id = list.id;

    if (id == null || _deletingListIds.contains(id)) return;

    setState(() {
      _deletingListIds.add(id);
    });

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Liste löschen'),
            content: Text(
              'Die Liste „${list.name}“ und alle ihre Produkte '
                  'werden dauerhaft gelöscht. Fortfahren?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Abbrechen'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Löschen'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !mounted) return;

      final deletedRows = await _repository.deleteList(id);

      if (deletedRows != 1) {
        throw StateError('Expected to delete one shopping list.');
      }

      if (!mounted) return;

      setState(() {
        _lists.removeWhere((existingList) => existingList.id == id);
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to delete shopping list: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Löschen fehlgeschlagen. Bitte erneut versuchen.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingListIds.remove(id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading || _loadError != null
            ? null
            : _showAddListDialog,
        tooltip: 'Neue Einkaufsliste',
        child: const Icon(Icons.add),
      ),
      appBar: AppBar(
        title: const Text('Meine Einkaufslisten'),
        backgroundColor: Colors.lightBlue,
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _loadError != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadLists,
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      )
          : _lists.isEmpty
          ? const Center(
        child: Text('Noch keine Einkaufslisten vorhanden.'),
      )
          : ListView.builder(
        itemCount: _lists.length,
        itemBuilder: (context, index) {
          final list = _lists[index];

          return ListTile(
            leading: const Icon(Icons.shopping_basket_outlined),
            title: Text(list.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Liste umbenennen',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _deletingListIds.contains(list.id)
                      ? null
                      : () => _showRenameListDialog(list),
                ),
                IconButton(
                  tooltip: 'Liste löschen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _deletingListIds.contains(list.id)
                      ? null
                      : () => _deleteList(list),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: _deletingListIds.contains(list.id)
                ? null
                : () => _openList(list),
          );
        },
      ),
    );
  }
}