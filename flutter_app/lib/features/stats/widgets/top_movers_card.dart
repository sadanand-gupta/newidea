import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/features/coin_detail/open_coin.dart';
import 'package:kryptox/shared/shared.dart';

/// The lists [TopMoversCard] can switch between.
enum MoversList {
  gainers('Gainers', 'gain', 'Biggest 24h price gains', Icons.trending_up_rounded),
  losers('Losers', 'lose', 'Biggest 24h price drops', Icons.trending_down_rounded),
  volume('Volume', 'vol', 'Most traded by 24h volume', Icons.bar_chart_rounded);

  const MoversList(this.label, this.heroPrefix, this.description, this.emptyIcon);

  /// Segment label.
  final String label;

  /// Hero-tag prefix, unique per list so the same coin can appear in several.
  final String heroPrefix;
  final String description;
  final IconData emptyIcon;

  List<Coin> coinsOf(GlobalStats stats) => switch (this) {
    gainers => stats.topGainers,
    losers => stats.topLosers,
    volume => stats.topVolume,
  };
}

/// "Top movers" section: a segmented switch between the top gainers, losers
/// and most-traded coins, each row opening the coin's detail page.
///
/// Laid out edge to edge (coin rows bring their own inset); the header and
/// switch are padded to the page gutter.
class TopMoversCard extends StatefulWidget {
  const TopMoversCard({super.key, required this.stats});

  final GlobalStats stats;

  @override
  State<TopMoversCard> createState() => _TopMoversCardState();
}

class _TopMoversCardState extends State<TopMoversCard> {
  MoversList _list = MoversList.gainers;

  @override
  Widget build(BuildContext context) {
    final coins = _list.coinsOf(widget.stats);
    final blurb = '${_list.description} · tap a coin for details';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(padding: KxLayout.pagePadding, child: SectionHeader('Top movers · 24h')),
        Padding(
          padding: KxLayout.pagePadding,
          child: KxSegmented<MoversList>(
            options: MoversList.values,
            selected: _list,
            labelOf: (list) => list.label,
            onSelected: (list) {
              if (list != _list) setState(() => _list = list);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              blurb,
              key: ValueKey(blurb),
              style: KxText.body(12, color: KxColors.textDim),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) =>
              Stack(alignment: Alignment.topCenter, children: [...previous, if (current != null) current]),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: coins.isEmpty
              ? _EmptyList(key: ValueKey('empty-$_list'), icon: _list.emptyIcon)
              : Column(
                  key: ValueKey(_list),
                  children: [
                    for (final coin in coins)
                      CoinTile(
                        coin: coin,
                        heroPrefix: _list.heroPrefix,
                        showSparkline: false,
                        onTap: () => openCoin(context, coin, heroPrefix: _list.heroPrefix),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: KxColors.textMuted),
          const SizedBox(height: 8),
          Text(
            'No coins in this list right now.',
            textAlign: TextAlign.center,
            style: KxText.body(13, color: KxColors.textDim),
          ),
          const SizedBox(height: 2),
          Text(
            'Pull down or tap refresh to try again.',
            textAlign: TextAlign.center,
            style: KxText.body(11, color: KxColors.textDim),
          ),
        ],
      ),
    );
  }
}
