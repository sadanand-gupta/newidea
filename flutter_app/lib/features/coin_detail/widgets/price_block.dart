import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/core/utils/formatters.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/features/coin_detail/chart_range_controller.dart';
import 'package:kryptox/shared/shared.dart';

/// Big price readout with the change over the selected chart range.
///
/// While the chart is scrubbed it shows the historical price, its change
/// since the start of the series and the point's timestamp instead.
class PriceBlock extends StatelessWidget {
  const PriceBlock({super.key, required this.coin, required this.detail, required this.chart, this.updatedAt});

  final Coin coin;
  final CoinDetail? detail;
  final ChartRangeController chart;

  /// When the details were fetched; shown as "Updated 2m ago".
  final DateTime? updatedAt;

  /// The API's own change figure for [range], when it has one.
  double? _apiChange(ChartRange range) => switch (range) {
    ChartRange.day => coin.change24h,
    ChartRange.week => coin.change7d,
    ChartRange.month => detail?.change30d,
    ChartRange.year => detail?.change1y,
    ChartRange.quarter => null,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([chart, chart.scrub]),
      builder: (context, _) {
        final scrub = chart.scrub.value;
        if (scrub != null) {
          return _PriceReadout(
            symbol: coin.symbol,
            price: scrub.price,
            change: chart.visible?.changeTo(scrub),
            caption: formatDateTime(scrub.time),
            scrubbing: true,
            updatedAt: updatedAt,
          );
        }

        // Change for the selected range: chart first→last, then the matching
        // API field, then the 24h change as a last resort.
        final range = chart.range;
        final change = chart.current?.change ?? _apiChange(range);
        return _PriceReadout(
          symbol: coin.symbol,
          price: coin.price,
          change: change ?? coin.change24h,
          caption: change != null ? range.longLabel : ChartRange.day.longLabel,
          scrubbing: false,
          updatedAt: updatedAt,
        );
      },
    );
  }
}

class _PriceReadout extends StatelessWidget {
  const _PriceReadout({
    required this.symbol,
    required this.price,
    required this.change,
    required this.caption,
    required this.scrubbing,
    required this.updatedAt,
  });

  final String symbol;
  final double? price;
  final double? change;
  final String caption;
  final bool scrubbing;
  final DateTime? updatedAt;

  /// AnimatedPrice caps at 8 decimals, which would read $0.00000000.
  static bool _isMicroPrice(double? v) => v != null && v != 0 && v.abs() < 0.000001;

  @override
  Widget build(BuildContext context) {
    final priceStyle = KxText.mono(
      36,
      weight: FontWeight.w700,
    ).copyWith(height: 1.1, shadows: [Shadow(color: KxColors.cyan.withValues(alpha: 0.35), blurRadius: 18)]);
    final updatedAt = this.updatedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                symbol.isEmpty ? 'PRICE · USD' : '$symbol / USD',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KxText.label(11, color: KxColors.textMuted),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: scrubbing
                  ? const _HistoricalTag(key: ValueKey('scrub-tag'))
                  : updatedAt != null
                  ? UpdatedAgo(
                      key: const ValueKey('updated'),
                      time: updatedAt,
                      style: KxText.mono(10, color: KxColors.textDim),
                    )
                  : const SizedBox.shrink(key: ValueKey('none')),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Scales down for long prices (e.g. $0.00001780) on 360px phones.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: _isMicroPrice(price)
              ? Text(formatChartPrice(price), maxLines: 1, style: priceStyle)
              : Transform.translate(
                  offset: const Offset(-4, 0), // AnimatedPrice has 4px inner padding
                  child: AnimatedPrice(value: price, style: priceStyle, flash: !scrubbing),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ChangePill(change, size: 13),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                layoutBuilder: (current, previous) =>
                    Stack(alignment: Alignment.centerLeft, children: [...previous, if (current != null) current]),
                child: Text(
                  caption,
                  key: ValueKey(scrubbing),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KxText.mono(12, color: scrubbing ? KxColors.cyan : KxColors.textDim),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "HISTORICAL" tag shown instead of the update time while scrubbing.
class _HistoricalTag extends StatelessWidget {
  const _HistoricalTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: KxColors.cyan.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: KxColors.cyan.withValues(alpha: 0.35)),
      ),
      child: Text('HISTORICAL', style: KxText.label(9, color: KxColors.cyan)),
    );
  }
}
