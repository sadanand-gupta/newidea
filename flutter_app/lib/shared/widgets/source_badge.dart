import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:kryptox/core/theme/app_theme.dart';

/// Pulsing status dot + label: LIVE / CACHED / MOCK.
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source});

  final String? source;

  @override
  Widget build(BuildContext context) {
    if (source == null) return const SizedBox.shrink();
    final (label, color, tip) = switch (source) {
      'live' => ('LIVE', KxColors.up, 'Streaming live data from CoinGecko'),
      'cache' => ('CACHED', KxColors.warn, 'CoinGecko unavailable: showing last cached data'),
      _ => ('DEMO', KxColors.violet, 'Live API unavailable: showing demo data'),
    };
    return Tooltip(
      message: tip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color, blurRadius: 6)],
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fade(begin: 1, end: 0.25, duration: 900.ms, curve: Curves.easeInOut),
            const SizedBox(width: 6),
            Text(label, maxLines: 1, softWrap: false, style: KxText.label(10, color: color)),
          ],
        ),
      ),
    );
  }
}
