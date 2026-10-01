import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:kryptox/core/theme/app_theme.dart';

/// Centres [child] horizontally and caps it at [maxWidth], so pages stay a
/// readable column on tablets, desktop and web. Phones use the full width.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = KxLayout.maxContentWidth,
    this.alignment = Alignment.topCenter,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  /// Applied inside the width cap (e.g. [KxLayout.pagePadding]).
  final EdgeInsetsGeometry padding;

  /// Horizontal inset on each side that centres a [maxWidth] column in
  /// [availableWidth] (0 on narrow screens). Useful for positioned overlays.
  static double insetFor(double availableWidth, {double maxWidth = KxLayout.maxContentWidth}) =>
      math.max(0.0, (availableWidth - maxWidth) / 2);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Sliver counterpart of [ContentWidth]: insets [sliver] horizontally so its
/// content is centred and at most [maxWidth] wide.
class SliverContentWidth extends StatelessWidget {
  const SliverContentWidth({super.key, required this.sliver, this.maxWidth = KxLayout.maxContentWidth});

  final Widget sliver;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, SliverConstraints constraints) {
        final inset = ContentWidth.insetFor(constraints.crossAxisExtent, maxWidth: maxWidth);
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          sliver: sliver,
        );
      },
    );
  }
}
