import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';

/// Coloured pill with arrow: ▲ 2.31%
class ChangePill extends StatelessWidget {
  const ChangePill(this.value, {super.key, this.size = 12, this.filled = true});

  final double? value;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = KxColors.change(value);
    final text = value == null ? '—' : '${value!.abs().toStringAsFixed(2)}%';
    // The arrow carries the sign visually; spell it out for screen readers.
    final semantic = value == null
        ? 'No change data'
        : value! >= 0
        ? 'Up $text'
        : 'Down $text';
    final pill = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(horizontal: filled ? 7 : 0, vertical: filled ? 3 : 0),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Icon(
              value! >= 0 ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
              color: color,
              size: size + 6,
            ),
          Text(
            text,
            maxLines: 1,
            softWrap: false,
            style: KxText.mono(size, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
    return Semantics(label: semantic, excludeSemantics: true, child: pill);
  }
}
