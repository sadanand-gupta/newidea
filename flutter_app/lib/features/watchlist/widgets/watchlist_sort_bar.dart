import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/features/watchlist/watchlist_sort.dart';

/// Horizontal row of [WatchlistSort] chips with tap targets of at least
/// [KxLayout.minTapTarget] and selected-state semantics.
///
/// Unlike the shared `KxChipBar`, the bar grows with the text scale so
/// large-text chips never clip.
class WatchlistSortBar extends StatelessWidget {
  const WatchlistSortBar({super.key, required this.selected, required this.onSelected});

  final WatchlistSort selected;

  /// Called with a newly chosen order; tapping the active chip does nothing.
  final ValueChanged<WatchlistSort> onSelected;

  static const _duration = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    final height = math.max(KxLayout.minTapTarget, MediaQuery.textScalerOf(context).scale(13) * 1.3 + 22);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: KxLayout.pagePadding,
        itemCount: WatchlistSort.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final option = WatchlistSort.values[i];
          final active = option == selected;
          return Semantics(
            button: true,
            selected: active,
            label: 'Sort by ${option.label}',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (active) return;
                HapticFeedback.selectionClick();
                onSelected(option);
              },
              child: Center(
                child: AnimatedContainer(
                  duration: _duration,
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: active ? KxColors.brandGradient : null,
                    color: active ? null : KxColors.surface,
                    borderRadius: BorderRadius.circular(KxLayout.radiusControl),
                    border: Border.all(color: active ? Colors.transparent : KxColors.border),
                    boxShadow: [
                      if (active)
                        BoxShadow(color: KxColors.cyan.withValues(alpha: 0.3), blurRadius: 14, spreadRadius: -4),
                    ],
                  ),
                  child: Text(
                    option.label,
                    maxLines: 1,
                    style: KxText.body(
                      13,
                      weight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? Colors.black : KxColors.textDim,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
