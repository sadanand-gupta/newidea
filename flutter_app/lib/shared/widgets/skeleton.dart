import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/shared/widgets/glass_card.dart';

/// Repeating cyan shimmer sweep over [child], used for loading placeholders.
///
/// [index] staggers the sweep between sibling placeholders. Renders [child]
/// statically when the OS asks to reduce motion.
class Shimmer extends StatelessWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 1400),
    this.intensity = 0.12,
  });

  final Widget child;
  final int index;
  final Duration duration;

  /// Opacity of the cyan highlight.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return child
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: duration,
          delay: (index * 80).ms,
          color: KxColors.cyan.withValues(alpha: intensity),
        );
  }
}

/// Placeholder block standing in for text, a number or a logo while loading.
///
/// Wrap a group of these in a [Shimmer] (usually the card around them).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 6, this.outlined = false})
    : circle = false;

  /// Round placeholder (e.g. a coin logo) of the given [size].
  const SkeletonBox.circle({super.key, required double size})
    : width = size,
      height = size,
      radius = 0,
      outlined = false,
      circle = true;

  /// Null stretches to the available width.
  final double? width;
  final double height;
  final double radius;

  /// Fainter fill with a hairline border: stands in for a whole tile/card.
  final bool outlined;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: outlined ? 0.05 : 0.07),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
        border: outlined ? Border.all(color: KxColors.border) : null,
      ),
    );
  }
}

/// One shimmering placeholder row with the same card shape as `CoinTile`,
/// so nothing jumps when the data lands.
class SkeletonTile extends StatelessWidget {
  const SkeletonTile({super.key, this.index = 0, this.showSparkline = true});

  /// Staggers the shimmer relative to sibling rows.
  final int index;

  /// Reserve room for the 7-day sparkline, like a full-width `CoinTile`.
  final bool showSparkline;

  static Widget _lines(CrossAxisAlignment align, double top, double bottom) => Column(
    crossAxisAlignment: align,
    mainAxisSize: MainAxisSize.min,
    children: [
      SkeletonBox(width: top, height: 12),
      const SizedBox(height: 6),
      SkeletonBox(width: bottom, height: 10),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final name = _lines(CrossAxisAlignment.start, 60, 90);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KxLayout.gutter, vertical: 4),
      child: Shimmer(
        index: index,
        child: GlassCard(
          radius: KxLayout.radiusRow,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const SkeletonBox.circle(size: 36),
              const SizedBox(width: 12),
              if (showSparkline) ...[
                name,
                const Spacer(),
                const SkeletonBox(width: 60, height: 22),
                const SizedBox(width: 16),
              ] else
                Expanded(child: name),
              _lines(CrossAxisAlignment.end, 70, 46),
            ],
          ),
        ),
      ),
    );
  }
}

/// [count] [SkeletonTile]s in a non-scrolling column, for placeholders inside
/// an existing scroll view. Announced once as "Loading" to screen readers.
class SkeletonTileList extends StatelessWidget {
  const SkeletonTileList({super.key, required this.count, this.showSparkline = true, this.semanticLabel = 'Loading'});

  final int count;
  final bool showSparkline;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Column(
          children: [for (var i = 0; i < count; i++) SkeletonTile(index: i, showSparkline: showSparkline)],
        ),
      ),
    );
  }
}
