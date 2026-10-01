import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kryptox/core/theme/app_theme.dart';

/// Segmented control with a sliding gradient thumb (used for chart ranges).
class KxSegmented<T> extends StatelessWidget {
  const KxSegmented({
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
    final index = options.indexOf(selected);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KxColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                left: segmentWidth * index,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: KxColors.brandGradient,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [BoxShadow(color: KxColors.cyan.withValues(alpha: 0.35), blurRadius: 12)],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: option == selected,
                        label: labelOf(option),
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onSelected(option);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 250),
                              style: KxText.mono(
                                12,
                                weight: FontWeight.w700,
                                color: option == selected ? Colors.black : KxColors.textDim,
                              ),
                              child: Text(labelOf(option), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
