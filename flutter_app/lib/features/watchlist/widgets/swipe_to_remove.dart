import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'package:kryptox/core/theme/app_theme.dart';

/// Swipe-left-to-remove wrapper for a watchlist row.
///
/// Reveals a red "REMOVE" card behind [child] that grows with the drag, ticks
/// a haptic when the threshold is crossed, and exposes the removal as a
/// custom semantics action, since swiping isn't discoverable by screen readers.
class SwipeToRemove extends StatefulWidget {
  const SwipeToRemove({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.onRemove,
    required this.child,
  });

  /// Identifies the row for the underlying [Dismissible].
  final String itemId;

  /// Used in the accessibility action ("Remove Bitcoin from watchlist").
  final String itemName;
  final VoidCallback onRemove;
  final Widget child;

  @override
  State<SwipeToRemove> createState() => _SwipeToRemoveState();
}

class _SwipeToRemoveState extends State<SwipeToRemove> {
  static const _threshold = 0.35;
  final _progress = ValueNotifier<double>(0);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: 'Remove ${widget.itemName} from watchlist'): widget.onRemove,
      },
      child: Dismissible(
        key: ValueKey(widget.itemId),
        direction: DismissDirection.endToStart,
        dismissThresholds: const {DismissDirection.endToStart: _threshold},
        onUpdate: (details) {
          _progress.value = details.progress;
          if (details.reached && !details.previousReached) HapticFeedback.selectionClick();
        },
        onDismissed: (_) => widget.onRemove(),
        background: _RemoveBackground(progress: _progress, threshold: _threshold),
        child: widget.child,
      ),
    );
  }
}

/// Red card behind the row; its label and icon fade and grow as [progress]
/// approaches [threshold].
class _RemoveBackground extends StatelessWidget {
  const _RemoveBackground({required this.progress, required this.threshold});

  final ValueListenable<double> progress;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Matches CoinTile's outer inset so the red card sits exactly behind it.
      padding: const EdgeInsets.symmetric(horizontal: KxLayout.gutter, vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KxLayout.radiusRow),
          gradient: LinearGradient(
            colors: [KxColors.down.withValues(alpha: 0.04), KxColors.down.withValues(alpha: 0.42)],
          ),
          border: Border.all(color: KxColors.down.withValues(alpha: 0.45)),
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 22),
            child: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (context, p, _) {
                final k = (p / threshold).clamp(0.0, 1.0).toDouble();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: k,
                      child: Text('REMOVE', style: KxText.label(11, color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    Transform.scale(
                      scale: 0.7 + 0.55 * k,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: KxColors.down.withValues(alpha: 0.25 + 0.5 * k),
                          boxShadow: [BoxShadow(color: KxColors.down.withValues(alpha: 0.5 * k), blurRadius: 14)],
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
