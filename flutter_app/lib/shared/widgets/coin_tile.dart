import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/core/utils/formatters.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/shared/widgets/animated_price.dart';
import 'package:kryptox/shared/widgets/change_pill.dart';
import 'package:kryptox/shared/widgets/coin_avatar.dart';
import 'package:kryptox/shared/widgets/glass_card.dart';
import 'package:kryptox/shared/widgets/sparkline.dart';
import 'package:kryptox/shared/widgets/watchlist_star.dart';

/// Column geometry shared by [CoinTile] and [CoinTileHeader] so the header
/// labels line up with the row content at every width and text scale.
class _TileMetrics {
  const _TileMetrics({required this.rankWidth, required this.priceWidth, required this.showSparkline});

  /// Outer (list) padding around the card and inner card padding.
  static const outer = EdgeInsets.symmetric(horizontal: 16, vertical: 4);
  static const innerLeft = 12.0;
  static const innerRight = 4.0;
  static const avatar = 36.0;
  static const avatarGap = 12.0;
  static const rankGap = 8.0;
  static const priceGap = 10.0;
  static const star = 44.0;

  /// Name + sparkline need at least this much room before the sparkline is
  /// worth showing; below it (320px phones, big text) the chart is dropped so
  /// the name and price never get squeezed.
  static const minFlexibleForSparkline = 96.0;

  final double rankWidth;
  final double priceWidth;
  final bool showSparkline;

  /// [maxWidth] is the full row width including [outer] padding.
  static _TileMetrics of(BuildContext context, double maxWidth, {required bool sparklineWanted}) {
    final scaler = MediaQuery.textScalerOf(context);
    final rankWidth = scaler.scale(24).clamp(24.0, 36.0);
    // Fixed column: fits "$104,532.12" in 14px mono at 1.0x; larger values are
    // scaled down to fit (never overflow), and it grows with the text scale.
    final content = maxWidth - outer.horizontal - innerLeft - innerRight;
    // On very narrow rows the price column gives way (its text scales down)
    // so the name always keeps at least [minName] px.
    const minName = 56.0;
    final priceRoom = content - (rankWidth + rankGap + avatar + avatarGap + priceGap + star + minName);
    final priceWidth = scaler.scale(100).clamp(100.0, 136.0).clamp(64.0, priceRoom < 64 ? 64.0 : priceRoom).toDouble();
    final fixed = rankWidth + rankGap + avatar + avatarGap + priceGap + priceWidth + star;
    final flexible = content - fixed;
    return _TileMetrics(
      rankWidth: rankWidth,
      priceWidth: priceWidth,
      showSparkline: sparklineWanted && flexible >= minFlexibleForSparkline,
    );
  }
}

/// Market row: rank · logo · name · sparkline · animated price · change · star.
class CoinTile extends StatelessWidget {
  const CoinTile({
    super.key,
    required this.coin,
    required this.onTap,
    required this.heroPrefix,
    this.showSparkline = true,
  });

  final Coin coin;
  final VoidCallback onTap;

  /// Hero tags must be unique per screen; the same coin can be on several tabs.
  final String heroPrefix;
  final bool showSparkline;

  @override
  Widget build(BuildContext context) {
    final semanticLabel = [
      '${coin.name}, ${coin.symbol}',
      if (coin.rank != null) 'rank ${coin.rank}',
      'price ${formatPrice(coin.price)}',
      '24 hour change ${spokenChange(coin.change24h)}',
    ].join(', ');

    return Padding(
      padding: _TileMetrics.outer,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final m = _TileMetrics.of(
            context,
            constraints.maxWidth + _TileMetrics.outer.horizontal,
            sparklineWanted: showSparkline && coin.sparkline.length > 1,
          );
          return Semantics(
            container: true,
            button: true,
            label: semanticLabel,
            child: GlassCard(
              onTap: onTap,
              radius: 18,
              padding: const EdgeInsets.fromLTRB(_TileMetrics.innerLeft, 10, _TileMetrics.innerRight, 10),
              child: Row(
                children: [
                  // Everything but the star is summarised by [semanticLabel].
                  Expanded(
                    child: ExcludeSemantics(
                      child: Row(
                        children: [
                          SizedBox(
                            width: m.rankWidth,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                coin.rank?.toString() ?? '–',
                                maxLines: 1,
                                style: KxText.mono(11, color: KxColors.textMuted),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(width: _TileMetrics.rankGap),
                          CoinAvatar(coin: coin, heroTag: '$heroPrefix-${coin.id}'),
                          const SizedBox(width: _TileMetrics.avatarGap),
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  coin.symbol,
                                  style: KxText.display(15, weight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  coin.name,
                                  style: KxText.body(12, color: KxColors.textDim),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (m.showSparkline)
                            Expanded(
                              flex: 4,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: SizedBox(
                                  height: 34,
                                  child: RepaintBoundary(
                                    child: Sparkline(values: coin.sparkline, color: KxColors.change(coin.change7d)),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: _TileMetrics.priceGap),
                          SizedBox(
                            width: m.priceWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: AnimatedPrice(
                                    value: coin.price,
                                    style: KxText.mono(14, weight: FontWeight.w600),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: ChangePill(coin.change24h, size: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  WatchlistStar(coinId: coin.id, coinName: coin.name, size: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Column labels (# · ASSET · 7D · PRICE · 24H) aligned with [CoinTile] rows.
class CoinTileHeader extends StatelessWidget {
  const CoinTileHeader({
    super.key,
    this.showSparkline = true,
    this.padding = const EdgeInsets.only(top: 12, bottom: 2),
  });

  final bool showSparkline;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final style = KxText.label(10, color: KxColors.textMuted);
    Text label(String text, {TextAlign align = TextAlign.start}) =>
        Text(text, style: style, textAlign: align, maxLines: 1, softWrap: false, overflow: TextOverflow.visible);

    return ExcludeSemantics(
      child: Padding(
        padding: padding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final m = _TileMetrics.of(context, constraints.maxWidth, sparklineWanted: showSparkline);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                _TileMetrics.outer.left + _TileMetrics.innerLeft,
                0,
                _TileMetrics.outer.right + _TileMetrics.innerRight,
                0,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: m.rankWidth,
                    child: label('#', align: TextAlign.center),
                  ),
                  const SizedBox(width: _TileMetrics.rankGap),
                  // "ASSET" starts at the logo; it may paint past the logo's width.
                  SizedBox(width: _TileMetrics.avatar + _TileMetrics.avatarGap, child: label('ASSET')),
                  const Spacer(flex: 5),
                  if (m.showSparkline)
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: label('7D', align: TextAlign.center),
                      ),
                    ),
                  const SizedBox(width: _TileMetrics.priceGap),
                  SizedBox(
                    width: m.priceWidth,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: label('PRICE · 24H', align: TextAlign.end),
                    ),
                  ),
                  const SizedBox(width: _TileMetrics.star),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
