import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/core/utils/formatters.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/features/stats/asset_colors.dart';
import 'package:kryptox/shared/shared.dart';

typedef _Kpi = ({
  IconData icon,
  String label,
  String caption,
  double? value,
  String Function(double) format,
  Color color,
});

/// Grid of key market metrics (volume, turnover, dominance, counts): three
/// columns on wide layouts, two on phones. Values count up on first show.
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.stats});

  final GlobalStats stats;

  static const _spacing = 12.0;
  static const _threeColumnWidth = 560.0;

  static String _pct1(double v) => '${v.toStringAsFixed(1)}%';
  static String _pct2(double v) => '${v.toStringAsFixed(2)}%';

  List<_Kpi> get _kpis {
    final mcap = stats.totalMarketCap, vol = stats.totalVolume;
    final turnover = (mcap != null && vol != null && mcap > 0) ? vol / mcap * 100 : null;
    return [
      (
        icon: Icons.bar_chart_rounded,
        label: '24h volume',
        caption: 'Traded in 24h',
        value: vol,
        format: formatCompact,
        color: KxColors.cyan,
      ),
      (
        icon: Icons.speed_rounded,
        label: 'Vol / M.cap',
        caption: 'Liquidity turnover',
        value: turnover,
        format: _pct2,
        color: KxColors.magenta,
      ),
      (
        icon: Icons.currency_bitcoin,
        label: 'BTC dominance',
        caption: 'Share of total cap',
        value: stats.dominance['BTC'],
        format: _pct1,
        color: AssetColors.btc,
      ),
      (
        icon: Icons.diamond_outlined,
        label: 'ETH dominance',
        caption: 'Share of total cap',
        value: stats.dominance['ETH'],
        format: _pct1,
        color: AssetColors.eth,
      ),
      (
        icon: Icons.hub_outlined,
        label: 'Active coins',
        caption: 'Tracked assets',
        value: stats.activeCryptocurrencies?.toDouble(),
        format: formatNumber,
        color: KxColors.up,
      ),
      (
        icon: Icons.storefront_outlined,
        label: 'Exchanges',
        caption: 'Trading venues',
        value: stats.markets?.toDouble(),
        format: formatNumber,
        color: KxColors.warn,
      ),
    ];
  }

  Widget _tile(_Kpi kpi, int index) {
    final value = kpi.value;
    return StatTile(
          icon: kpi.icon,
          iconColor: kpi.color,
          label: kpi.label,
          caption: kpi.caption,
          valueWidget: CountUp(value: value, format: kpi.format, style: StatTile.valueStyle(size: 19)),
          semanticLabel: '${kpi.label}: ${value == null ? 'unavailable' : kpi.format(value)}. ${kpi.caption}',
        )
        .animate(delay: (140 + index * 60).ms)
        .fadeIn(duration: 400.ms)
        .scaleXY(begin: 0.96, end: 1, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final kpis = _kpis;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= _threeColumnWidth ? 3 : 2;
        // Explicit rows (not a Wrap) so tiles in a row share one height even
        // when one label wraps to two lines at large text sizes.
        return Column(
          children: [
            for (var r = 0; r < kpis.length; r += columns) ...[
              if (r > 0) const SizedBox(height: _spacing),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = r; i < r + columns; i++) ...[
                      if (i > r) const SizedBox(width: _spacing),
                      Expanded(child: i < kpis.length ? _tile(kpis[i], i) : const SizedBox.shrink()),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
