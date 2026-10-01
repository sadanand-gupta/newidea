import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kryptox/core/theme/app_theme.dart';

/// Horizontal chip bar whose selection glides between options.
class KxChipBar<T> extends StatelessWidget {
  const KxChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final option = options[i];
          final active = option == selected;
          return Semantics(
            button: true,
            selected: active,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(option);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: active ? KxColors.brandGradient : null,
                  color: active ? null : KxColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: active ? Colors.transparent : KxColors.border),
                  boxShadow: [
                    if (active)
                      BoxShadow(color: KxColors.cyan.withValues(alpha: 0.3), blurRadius: 14, spreadRadius: -4),
                  ],
                ),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 280),
                  style: KxText.body(
                    13,
                    weight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.black : KxColors.textDim,
                  ),
                  child: Text(labelOf(option)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
