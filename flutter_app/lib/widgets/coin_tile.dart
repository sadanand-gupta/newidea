import 'package:flutter/material.dart';

import '../models/coin.dart';
import '../theme/app_theme.dart';
import 'formatters.dart';
import 'glass.dart';
import 'market_widgets.dart';
import 'sparkline.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GlassCard(
        onTap: onTap,
        radius: 18,
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                coin.rank?.toString() ?? '-',
                style: KxText.mono(11, color: KxColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            CoinAvatar(coin: coin, heroTag: '$heroPrefix-${coin.id}'),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coin.symbol,
                      style: KxText.display(15, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(coin.name,
                      style: KxText.body(12, color: KxColors.textDim), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (showSparkline && coin.sparkline.length > 1)
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 34,
                  child: Sparkline(values: coin.sparkline, color: KxColors.change(coin.change7d)),
                ),
              ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedPrice(value: coin.price, style: KxText.mono(14, weight: FontWeight.w600)),
                const SizedBox(height: 3),
                ChangePill(coin.change24h, size: 11),
              ],
            ),
            WatchlistStar(coinId: coin.id, size: 20),
          ],
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
    return SizedBox(
      width: 168,
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        glow: color.withValues(alpha: 0.6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CoinAvatar(coin: coin, size: 28, heroTag: '$heroPrefix-${coin.id}'),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(coin.symbol, style: KxText.display(14, weight: FontWeight.w600), maxLines: 1),
                ),
                ChangePill(coin.change24h, size: 10, filled: false),
              ],
            ),
            const Spacer(),
            SizedBox(height: 36, child: Sparkline(values: coin.sparkline, color: color)),
            const SizedBox(height: 8),
            AnimatedPrice(value: coin.price, style: KxText.mono(15, weight: FontWeight.w700)),
          ],
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
  late final _controller = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();

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
            Text(c.symbol, style: KxText.label(11, color: KxColors.text)),
            const SizedBox(width: 6),
            Text(formatPrice(c.price), style: KxText.mono(11, color: KxColors.textDim)),
            const SizedBox(width: 4),
            Text(formatPercent(c.change24h), style: KxText.mono(11, color: KxColors.change(c.change24h))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.coins.isEmpty) return const SizedBox.shrink();
    final row = Row(mainAxisSize: MainAxisSize.min, children: [for (final c in widget.coins) _item(c)]);
    // RepaintBoundary: the tape repaints every frame; without it each frame
    // would also repaint the surrounding scroll view (glass cards, blur header).
    return RepaintBoundary(
      child: Container(
        height: 30,
        decoration: const BoxDecoration(
          border: Border.symmetric(horizontal: BorderSide(color: KxColors.border)),
          color: Color(0x08FFFFFF),
        ),
        child: ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => _Marquee(progress: _controller.value, child: child!),
            child: row,
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
        children: [KeyedSubtree(key: _key, child: widget.child), widget.child],
      ),
    );
  }
}
