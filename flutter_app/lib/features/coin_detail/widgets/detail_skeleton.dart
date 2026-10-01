import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/shared/shared.dart';

/// Placeholder for the performance and market-stats sections while the full
/// details load, shaped like the real tiles so nothing jumps.
class DetailsSkeleton extends StatelessWidget {
  const DetailsSkeleton({super.key});

  static const _tile = SkeletonBox(height: 64, radius: KxLayout.radiusTile, outlined: true);
  static const _statTile = SkeletonBox(height: 62, radius: KxLayout.radiusTile, outlined: true);

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 110, height: 12),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[if (i > 0) const SizedBox(width: 8), const Expanded(child: _tile)],
            ],
          ),
          const SizedBox(height: 22),
          const SkeletonBox(width: 90, height: 12),
          const SizedBox(height: 14),
          for (var r = 0; r < 2; r++) ...[
            if (r > 0) const SizedBox(height: 10),
            const Row(
              children: [
                Expanded(child: _statTile),
                SizedBox(width: 10),
                Expanded(child: _statTile),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-page loader, shown only when there is no list row to start from.
class DetailPageLoader extends StatelessWidget {
  const DetailPageLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Entrance(
        offset: Offset.zero,
        duration: const Duration(milliseconds: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 36,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: KxColors.cyan),
            ),
            const SizedBox(height: 16),
            Text('Loading market data…', style: KxText.body(13, color: KxColors.textDim)),
          ],
        ),
      ),
    );
  }
}
