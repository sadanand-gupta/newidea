import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/core/utils/formatters.dart';
import 'package:kryptox/data/models/coin.dart';

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
