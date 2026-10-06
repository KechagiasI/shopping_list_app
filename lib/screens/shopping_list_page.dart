import '../repositories/shopping_repository.dart';

import 'package:flutter/material.dart';
import '../models/shopping_item.dart';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final List<ShoppingItem> _items = [];

  final ShoppingRepository _repository = ShoppingRepository();

  final Set<int> _updatingItemIds = {};

  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final loadedItems = await _repository.loadItems();

      if (!mounted) return;

      setState(() {
        _items.clear();
        _items.addAll(loadedItems);
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load shopping items: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = 'Die Einkaufsliste konnte nicht geladen werden.';
      });
    }
  }

  Future<void> _showAddProductDialog() async {
    String newProduct = '';
    String newQuantity = '1';
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
                title: const Text('Produkt hinzufügen'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        enabled: !isSaving,
                        onChanged: (value) {
                          newProduct = value;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Produkt',
                          hintText: 'z. B. Milch',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: '1',
                        enabled: !isSaving,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          newQuantity = value;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Menge',
                          hintText: 'z. B. 2',
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

                      final name = newProduct.trim();
                      final quantity =
                      int.tryParse(newQuantity.trim());

                      if (name.isEmpty ||
                          quantity == null ||
                          quantity <= 0) {
                        setDialogState(() {
                          errorMessage =
                          'Bitte Produkt und eine gültige Menge eingeben.';
                        });
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                        errorMessage = null;
                      });

                      try {
                        final item = ShoppingItem(
                          name: name,
                          quantity: quantity,
                        );

                        final id = await _repository.addItem(item);

                        if (!mounted) return;

                        setState(() {
                          _items.add(
                            ShoppingItem(
                              id: id,
                              name: name,
                              quantity: quantity,
                            ),
                          );
                        });
                      } catch (error, stackTrace) {
                        debugPrint('Failed to add shopping item: $error');
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

  Future<void> _setItemBought(
      ShoppingItem item,
      bool isBought,
      ) async {
    final id = item.id;

    if (_updatingItemIds.contains(id)) return;

    try {
      if (id == null) {
        throw StateError('Cannot update an item without an id.');
      }

      setState(() {
        _updatingItemIds.add(id);
      });

      final updatedRows = await _repository.setBought(
        id: id,
        isBought: isBought,
      );

      if (updatedRows != 1) {
        throw StateError('Expected to update one shopping item.');
      }

      if (!mounted) return;

      setState(() {
        item.isBought = isBought;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to update purchase status: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Änderung konnte nicht gespeichert werden. Bitte erneut versuchen.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingItemIds.remove(id);
        });
      }
    }
  }

  Future<void> _deleteItem(ShoppingItem item) async {
    final id = item.id;

    if (_updatingItemIds.contains(id)) return;

    try {
      if (id == null) {
        throw StateError('Cannot delete an item without an id.');
      }

      setState(() {
        _updatingItemIds.add(id);
      });

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Produkt löschen'),
            content: Text('${item.name} wirklich löschen?'),
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

      if (!mounted || confirmed != true) return;

      final deletedRows = await _repository.deleteItem(id);

      if (deletedRows != 1) {
        throw StateError('Expected to delete one shopping item.');
      }

      if (!mounted) return;

      setState(() {
        _items.removeWhere((existingItem) => existingItem.id == id);
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to delete shopping item: $error');
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
          _updatingItemIds.remove(id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
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
                onPressed: _loadItems,
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      )
          : _items.isEmpty
          ? const Center(
        child: Text('Die Einkaufsliste ist leer.'),
      )
          : ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return ListTile(
            leading: Checkbox(
              value: item.isBought,
              onChanged: _updatingItemIds.contains(item.id)
                  ? null
                  : (value) => _setItemBought(item, value ?? false),
            ),
            title: Text(
              item.name,
              style: TextStyle(
                decoration: item.isBought
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
            subtitle: Text('Menge: ${item.quantity}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Produkt löschen',
              onPressed: _updatingItemIds.contains(item.id)
                  ? null
                  : () => _deleteItem(item),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.lightBlue,
        onPressed: _isLoading || _loadError != null
            ? null
            : _showAddProductDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}