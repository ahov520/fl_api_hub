import 'package:flutter/material.dart';

import '../../../app/theme/design_tokens.dart';

/// Shared search text field with a leading search icon and an inline clear
/// button that appears once text is entered.
///
/// Replaces the duplicated search `TextField` implementations on the
/// accounts and keys pages.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    this.hintText = '搜索',
    this.onChanged,
    this.onClear,
  });

  /// Controls the text being edited.
  final TextEditingController controller;

  /// Placeholder shown when the field is empty.
  final String hintText;

  /// Called on every text change.
  final ValueChanged<String>? onChanged;

  /// Called when the clear button is tapped.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: colorScheme.surfaceContainerHigh,
            contentPadding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide.none,
            ),
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      controller.clear();
                      onClear?.call();
                    },
                  )
                : null,
          ),
        );
      },
    );
  }
}
