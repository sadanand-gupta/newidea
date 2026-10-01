import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/features/home/widgets/coin_preview_list.dart';
import 'package:kryptox/features/home/widgets/muted_note.dart';
import 'package:kryptox/shared/shared.dart';

enum _Movers { gainers, losers }

/// "Top movers · 24h": the day's biggest gainers or losers (user's choice)
/// from [stats], with a "See all" link to the stats tab.
class TopMoversSection extends StatefulWidget {
  const TopMoversSection({super.key, required this.stats, required this.failed, required this.onSeeAll});

  /// Null while the market data is loading or failed to load.
  final GlobalStats? stats;

  /// The market data failed to load; shows a note instead of placeholders.
  final bool failed;
  final VoidCallback onSeeAll;

  /// Number of coins listed.
  static const previewCount = 5;

  @override
  State<TopMoversSection> createState() => _TopMoversSectionState();
}

class _TopMoversSectionState extends State<TopMoversSection> {
  _Movers _movers = _Movers.gainers;

  Widget _buildBody() {
    final stats = widget.stats;
    if (stats == null) {
      return widget.failed
          ? const Padding(
              key: ValueKey('movers-error'),
              padding: KxLayout.pagePadding,
              child: MutedNote(text: 'Top movers will appear once market data loads.'),
            )
          : const SkeletonTileList(key: ValueKey('movers-loading'), count: 3, showSparkline: false);
    }
    final coins = (_movers == _Movers.gainers ? stats.topGainers : stats.topLosers).take(TopMoversSection.previewCount);
    if (coins.isEmpty) {
      return Padding(
        key: ValueKey('movers-empty-$_movers'),
        padding: KxLayout.pagePadding,
        child: const MutedNote(text: 'No mover data available right now.'),
      );
    }
    return CoinPreviewList(key: ValueKey('movers-$_movers'), coins: coins, heroPrefix: 'home-movers');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: KxLayout.pagePadding,
          child: SectionHeader(
            'Top movers · 24h',
            onAction: widget.onSeeAll,
            actionSemanticLabel: 'See all market stats',
            padding: _sectionTitlePadding,
            reserveActionSpace: true,
          ),
        ),
        Padding(
          padding: KxLayout.pagePadding,
          child: Semantics(
            label: 'Show top gainers or top losers',
            child: KxSegmented<_Movers>(
              options: _Movers.values,
              selected: _movers,
              labelOf: (m) => m == _Movers.gainers ? 'GAINERS' : 'LOSERS',
              onSelected: (m) => setState(() => _movers = m),
            ),
          ),
        ),
        const SizedBox(height: 8),
        KxSwitcher(child: _buildBody()),
      ],
    );
  }
}

/// Spacing above the section titles of the Home dashboard.
const _sectionTitlePadding = EdgeInsets.fromLTRB(4, 24, 0, 8);
