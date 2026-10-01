import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/shared/shared.dart';

/// Top bar of the detail page: back button, logo, name with symbol / rank /
/// data-source tags, and the watchlist star.
///
/// [coin] is null until either the list row or the details have arrived.
class DetailHeader extends StatelessWidget {
  const DetailHeader({super.key, required this.coin, required this.coinId, this.heroTag, this.source});

  final Coin? coin;
  final String coinId;

  /// Hero tag of the list avatar so the logo flies into the header.
  final String? heroTag;

  /// Data source of the details (e.g. "live" / "cache"), shown as a badge.
  final String? source;

  @override
  Widget build(BuildContext context) {
    final coin = this.coin;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          KxIconButton(
            style: KxIconButtonStyle.circle,
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 12),
          if (coin != null) ...[CoinAvatar(coin: coin, size: 40, heroTag: heroTag), const SizedBox(width: 12)],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(coin?.name ?? 'Loading…', maxLines: 1, overflow: TextOverflow.ellipsis, style: KxText.display(18)),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (coin != null && coin.symbol.isNotEmpty) _TagChip(text: coin.symbol, accent: true),
                    if (coin != null && coin.rank != null) _TagChip(text: '#${coin.rank}'),
                    if (source != null) SourceBadge(source: source),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          WatchlistStar(coinId: coinId, coinName: coin?.name, size: 26, tapTarget: 48),
        ],
      ),
    );
  }
}

/// Small mono tag next to the coin name; [accent] gives it the brand tint.
class _TagChip extends StatelessWidget {
  const _TagChip({required this.text, this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: accent
            ? LinearGradient(colors: [KxColors.cyan.withValues(alpha: 0.18), KxColors.violet.withValues(alpha: 0.18)])
            : null,
        color: accent ? null : Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: accent ? KxColors.cyan.withValues(alpha: 0.35) : KxColors.border),
      ),
      child: Text(
        text,
        style: KxText.mono(11, weight: FontWeight.w700, color: accent ? KxColors.cyan : KxColors.textDim),
      ),
    );
  }
}
