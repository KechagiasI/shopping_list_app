import 'package:flutter/material.dart';

import '../models/shopping_category.dart';

class ShoppingCategoryField extends StatelessWidget {
  final ShoppingCategory category;
  final ValueChanged<ShoppingCategory>? onChanged;

  const ShoppingCategoryField({
    super.key,
    required this.category,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Kategorie',
        enabled: onChanged != null,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ShoppingCategory>(
          value: category,
          isExpanded: true,
          isDense: true,
          items: ShoppingCategory.values.map((option) {
            return DropdownMenuItem<ShoppingCategory>(
              value: option,
              child: Text(option.label),
            );
          }).toList(),
          onChanged: onChanged == null
              ? null
              : (value) {
            if (value != null) {
              onChanged!(value);
            }
          },
        ),
      ),
    );
  }
}