import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/features/home/widgets/coin_preview_list.dart';
import 'package:kryptox/features/home/widgets/empty_watchlist_card.dart';
import 'package:kryptox/features/home/widgets/muted_note.dart';
import 'package:kryptox/shared/shared.dart';

/// "Your watchlist": the first few watched coins, a link to the rest, and an
/// empty state that points to the markets.
class WatchlistPreviewSection extends StatelessWidget {
  const WatchlistPreviewSection({
    super.key,
    required this.coins,
    required this.error,
    required this.onRetry,
    required this.onSeeAll,
    required this.onExplore,
  });

  /// Watched coins; null while loading or after a failed first load.
  final List<Coin>? coins;

  /// Why the watchlist failed to load; shown only when [coins] is null.
  final String? error;
  final VoidCallback onRetry;

  /// Opens the full watchlist tab.
  final VoidCallback onSeeAll;

  /// Opens the markets tab (from the empty state).
  final VoidCallback onExplore;

  /// Number of coins listed before the "+N more" link.
  static const previewCount = 4;

  Widget _buildBody() {
    final coins = this.coins;
    if (coins == null) {
      return error != null
          ? Padding(
              key: const ValueKey('watch-error'),
              padding: KxLayout.pagePadding,
              child: InlineError(title: 'Watchlist unavailable', message: error, onRetry: onRetry),
            )
          : const SkeletonTileList(key: ValueKey('watch-loading'), count: 2, showSparkline: false);
    }
    if (coins.isEmpty) {
      return Padding(
        key: const ValueKey('watch-empty'),
        padding: KxLayout.pagePadding,
        child: EmptyWatchlistCard(onExplore: onExplore),
      );
    }
    final hidden = coins.length - previewCount;
    return Column(
      key: const ValueKey('watch-list'),
      children: [
        CoinPreviewList(coins: coins.take(previewCount), heroPrefix: 'home-watch'),
        if (hidden > 0)
          Padding(
            padding: KxLayout.pagePadding.copyWith(top: 4),
            child: MutedNote(text: '+$hidden more in your watchlist', onTap: onSeeAll),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = coins?.length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: KxLayout.pagePadding,
          child: SectionHeader(
            count > 0 ? 'Your watchlist · $count' : 'Your watchlist',
            onAction: count > 0 ? onSeeAll : null,
            actionSemanticLabel: 'See your full watchlist',
            padding: _sectionTitlePadding,
            reserveActionSpace: true,
          ),
        ),
        KxSwitcher(child: _buildBody()),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// Spacing above the section titles of the Home dashboard.
const _sectionTitlePadding = EdgeInsets.fromLTRB(4, 24, 0, 8);
