import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/shared/shared.dart';

/// Empty state of the dashboard's watchlist preview: explains the star and
/// offers a way to the markets tab via [onExplore].
class EmptyWatchlistCard extends StatelessWidget {
  const EmptyWatchlistCard({super.key, required this.onExplore});

  final VoidCallback onExplore;

  static const double _iconSize = 52;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: KxLayout.radiusRow,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Container(
            width: _iconSize,
            height: _iconSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: KxColors.warn.withValues(alpha: 0.1),
              border: Border.all(color: KxColors.warn.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.star_outline_rounded, color: KxColors.warn, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            'Track the coins you care about',
            textAlign: TextAlign.center,
            style: KxText.body(15, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap the star on any coin and it will show up here with its live price and 24h move.',
            textAlign: TextAlign.center,
            style: KxText.body(13, color: KxColors.textDim),
          ),
          const SizedBox(height: 16),
          // GradientButton's label can't wrap; scale it down rather than overflow
          // on very narrow screens with large text.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: KxLayout.minTapTarget),
              child: GradientButton(label: 'Explore markets', icon: Icons.search_rounded, onPressed: onExplore),
            ),
          ),
        ],
      ),
    );
  }
}
