import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/core/utils/formatters.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/shared/shared.dart';

/// Two-column grid of market figures: cap, volume, FDV, all-time high/low.
class MarketStatsGrid extends StatelessWidget {
  const MarketStatsGrid({super.key, required this.detail});

  final CoinDetail detail;

  static const double _gap = 10;

  @override
  Widget build(BuildContext context) {
    final coin = detail.coin;
    final volume = coin.volume, marketCap = coin.marketCap, price = coin.price, atl = detail.atl;
    final volToCap = (volume != null && marketCap != null && marketCap > 0)
        ? (volume / marketCap).toStringAsFixed(4)
        : '—';
    final fromAtl = (price != null && atl != null && atl > 0) ? (price / atl - 1) * 100 : null;
    final items = <(String, String, Color?)>[
      ('Market cap', formatCompact(marketCap), null),
      ('24h volume', formatCompact(volume), null),
      ('Fully diluted val.', formatCompact(detail.fullyDilutedValuation), null),
      ('Vol / Mkt cap', volToCap, null),
      ('All-time high', formatChartPrice(detail.ath), null),
      ('From ATH', formatPercent(detail.athChange), KxColors.change(detail.athChange)),
      ('ATH date', formatDate(detail.athDate), null),
      ('All-time low', formatChartPrice(atl), null),
      ('From ATL', formatPercent(fromAtl), KxColors.change(fromAtl)),
      ('ATL date', formatDate(detail.atlDate), null),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = ((constraints.maxWidth - _gap) / 2).floorToDouble();
        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (final (i, (label, value, color)) in items.indexed)
              SizedBox(
                width: width,
                child: Entrance(
                  index: i,
                  delay: const Duration(milliseconds: 150),
                  stagger: const Duration(milliseconds: 40),
                  duration: const Duration(milliseconds: 400),
                  offset: const Offset(0, 0.15),
                  child: StatTile(label: label, value: value, valueColor: color, valueSize: 14),
                ),
              ),
          ],
        );
      },
    );
  }
}
