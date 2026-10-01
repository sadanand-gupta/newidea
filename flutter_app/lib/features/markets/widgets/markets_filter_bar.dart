import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/shared/shared.dart';

/// Pinned search field + filter chips of the Markets list.
///
/// The frosted backdrop spans the window and fades in once content scrolls
/// under it; the controls stay within [maxContentWidth]. A [LoadingLine] along
/// the bottom edge shows background refreshes.
class MarketsFilterBarDelegate extends SliverPersistentHeaderDelegate {
  const MarketsFilterBarDelegate({
    required this.textScaler,
    required this.loading,
    required this.search,
    required this.filters,
    this.maxContentWidth = KxLayout.maxContentWidth,
  });

  /// The bar grows with the search field's text.
  final TextScaler textScaler;
  final bool loading;
  final Widget search;
  final Widget filters;
  final double maxContentWidth;

  static const double _searchFontSize = 15;

  double get _extent {
    final scale = textScaler.scale(_searchFontSize) / _searchFontSize;
    final searchHeight = math.max(48.0, 28 + _searchFontSize * 1.25 * scale);
    return 72 + searchHeight;
  }

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final pinned = shrinkOffset > 0 || overlapsContent;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          opacity: pinned ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [KxColors.bg.withValues(alpha: 0.88), KxColors.bg.withValues(alpha: 0.62)],
                  ),
                  border: const Border(bottom: BorderSide(color: KxColors.border)),
                ),
              ),
            ),
          ),
        ),
        Column(
          children: [
            const SizedBox(height: 10),
            ContentWidth(maxWidth: maxContentWidth, padding: KxLayout.pagePadding, child: search),
            const SizedBox(height: 10),
            ContentWidth(maxWidth: maxContentWidth, child: filters),
            const Spacer(),
            LoadingLine(visible: loading, padding: EdgeInsets.zero, color: KxColors.cyan.withValues(alpha: 0.8)),
          ],
        ),
      ],
    );
  }

  // [search], [filters] and [loading] come fresh from every parent build.
  @override
  bool shouldRebuild(MarketsFilterBarDelegate oldDelegate) => true;
}
