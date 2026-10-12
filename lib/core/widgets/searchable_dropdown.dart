import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';

class SearchableDropdown<T> extends StatelessWidget {
  final String label;
  final String? hint;
  final List<T> items;
  final T? selectedItem;
  final String Function(T)? itemAsString;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final bool Function(T, String)? filterFn;
  final bool Function(T, T)? compareFn;

  const SearchableDropdown({
    super.key,
    required this.label,
    this.hint,
    required this.items,
    this.selectedItem,
    this.itemAsString,
    this.onChanged,
    this.validator,
    this.filterFn,
    this.compareFn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownSearch<T>(
          items: (filter, infiniteScrollProps) => items,
          selectedItem: selectedItem,
          itemAsString: itemAsString,
          onChanged: onChanged,
          validator: validator,
          filterFn: filterFn,
          compareFn: compareFn,
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            menuProps: const MenuProps(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
            ),
          ),
          decoratorProps: DropDownDecoratorProps(
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
          ),
        ),
      ],
    );
  }
}
