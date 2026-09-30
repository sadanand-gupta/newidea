import 'package:flutter/material.dart';

import '../models/coin.dart';
import '../theme/app_theme.dart';
import 'formatters.dart';
import 'glass.dart';
import 'market_widgets.dart';
import 'sparkline.dart';

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

String _changePhrase(double? v) =>
    v == null ? 'no data' : '${v >= 0 ? 'up' : 'down'} ${v.abs().toStringAsFixed(2)} percent';

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
      '24 hour change ${_changePhrase(coin.change24h)}',
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

/// Compact card for the horizontal "trending" carousel.
class TrendingCard extends StatelessWidget {
  const TrendingCard({super.key, required this.coin, required this.onTap, required this.heroPrefix});

  final Coin coin;
  final VoidCallback onTap;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    final color = KxColors.change(coin.change24h);
    return Semantics(
      container: true,
      button: true,
      label:
          '${coin.name}, ${coin.symbol}, price ${formatPrice(coin.price)}, '
          '24 hour change ${_changePhrase(coin.change24h)}',
      child: SizedBox(
        width: 168,
        child: GlassCard(
          onTap: onTap,
          padding: const EdgeInsets.all(14),
          glow: color.withValues(alpha: 0.6),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CoinAvatar(coin: coin, size: 28, heroTag: '$heroPrefix-${coin.id}'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        coin.symbol,
                        style: KxText.display(14, weight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    ChangePill(coin.change24h, size: 10, filled: false),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  height: 36,
                  child: coin.sparkline.length > 1
                      ? RepaintBoundary(
                          child: Sparkline(values: coin.sparkline, color: color),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedPrice(
                    value: coin.price,
                    style: KxText.mono(15, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Endless scrolling price ticker, like a trading-floor tape.
class TickerTape extends StatefulWidget {
  const TickerTape({super.key, required this.coins});

  final List<Coin> coins;

  @override
  State<TickerTape> createState() => _TickerTapeState();
}

class _TickerTapeState extends State<TickerTape> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 40));
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the OS "reduce motion" setting: show a static, swipeable tape.
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _item(Coin c) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(c.symbol, maxLines: 1, style: KxText.label(11, color: KxColors.text)),
        const SizedBox(width: 6),
        Text(formatPrice(c.price), maxLines: 1, style: KxText.mono(11, color: KxColors.textDim)),
        const SizedBox(width: 4),
        Text(formatPercent(c.change24h), maxLines: 1, style: KxText.mono(11, color: KxColors.change(c.change24h))),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.coins.isEmpty) return const SizedBox.shrink();
    final row = Row(mainAxisSize: MainAxisSize.min, children: [for (final c in widget.coins) _item(c)]);
    // Grow with the text scale so large accessibility fonts aren't clipped.
    final height = MediaQuery.textScalerOf(context).scale(11) * 1.4 + 14;
    // RepaintBoundary: the tape repaints every frame; without it each frame
    // would also repaint the surrounding scroll view (glass cards, blur header).
    // The tape duplicates the list below, so it's hidden from screen readers.
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: Container(
          height: height < 30 ? 30 : height,
          decoration: const BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: KxColors.border)),
            color: Color(0x08FFFFFF),
          ),
          child: _reduceMotion
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Center(child: row),
                )
              : ClipRect(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => _Marquee(progress: _controller.value, child: child!),
                    child: row,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Lays out two copies of [child] side by side and slides them left by
/// [progress] of one copy's width, so the loop is seamless.
class _Marquee extends StatelessWidget {
  const _Marquee({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OverflowBox(
      alignment: Alignment.centerLeft,
      maxWidth: double.infinity,
      child: _MarqueeRow(progress: progress, child: child),
    );
  }
}

class _MarqueeRow extends StatefulWidget {
  const _MarqueeRow({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  State<_MarqueeRow> createState() => _MarqueeRowState();
}

class _MarqueeRowState extends State<_MarqueeRow> {
  final _key = GlobalKey();
  double _width = 0;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(_MarqueeRow old) {
    super.didUpdateWidget(old);
    // The animation ticks pass the same child instance; only re-measure when
    // the ticker content itself changed.
    if (!identical(old.child, widget.child)) _scheduleMeasure();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final w = (_key.currentContext?.findRenderObject() as RenderBox?)?.size.width ?? 0;
      if (w != _width && mounted) setState(() => _width = w);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(-_width * widget.progress, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KeyedSubtree(key: _key, child: widget.child),
          widget.child,
        ],
      ),
    );
  }
}
