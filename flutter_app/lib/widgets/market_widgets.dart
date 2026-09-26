import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/coin.dart';
import '../state/watchlist_provider.dart';
import '../theme/app_theme.dart';
import 'formatters.dart';

/// Price that rolls smoothly to its new value and flashes green/red when it
/// changes, the way exchange terminals do.
class AnimatedPrice extends StatefulWidget {
  const AnimatedPrice({
    super.key,
    required this.value,
    required this.style,
    this.compact = false,
    this.flash = true,
  });

  final double? value;
  final TextStyle style;
  final bool compact;

  /// Set false for rapid changes (e.g. chart scrubbing) to skip the tint.
  final bool flash;

  @override
  State<AnimatedPrice> createState() => _AnimatedPriceState();
}

class _AnimatedPriceState extends State<AnimatedPrice> with SingleTickerProviderStateMixin {
  late final _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  Color _flashColor = KxColors.up;
  late double _from = widget.value ?? 0;

  @override
  void didUpdateWidget(AnimatedPrice old) {
    super.didUpdateWidget(old);
    final prev = old.value, next = widget.value;
    if (prev != null && next != null && prev != next) {
      _from = prev;
      // Skip the tint while scrubbing and on the jump back when it ends.
      if (widget.flash && old.flash) {
        _flashColor = next > prev ? KxColors.up : KxColors.down;
        _flash.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.value;
    if (target == null) return Text('—', style: widget.style);
    final decimals = priceDecimals(target);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from, end: target),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => AnimatedBuilder(
        animation: _flash,
        builder: (context, _) {
          final k = _flash.isAnimating ? 1 - Curves.easeOut.transform(_flash.value) : 0.0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: _flashColor.withValues(alpha: 0.18 * k),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.compact ? formatCompact(v) : formatPrice(v, decimals: decimals),
              style: widget.style.copyWith(color: Color.lerp(widget.style.color, _flashColor, k)),
            ),
          );
        },
      ),
    );
  }
}

/// Coloured pill with arrow: ▲ 2.31%
class ChangePill extends StatelessWidget {
  const ChangePill(this.value, {super.key, this.size = 12, this.filled = true});

  final double? value;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = KxColors.change(value);
    final text = value == null ? '—' : '${value!.abs().toStringAsFixed(2)}%';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(horizontal: filled ? 7 : 0, vertical: filled ? 3 : 0),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Icon(value! >= 0 ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                color: color, size: size + 6),
          Text(text, style: KxText.mono(size, weight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// Coin logo with a soft neon ring; a Hero so it flies into the detail page.
class CoinAvatar extends StatelessWidget {
  const CoinAvatar({super.key, required this.coin, this.size = 36, this.heroTag});

  final Coin coin;
  final double size;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: KxColors.brandGradient),
      child: Text(
        coin.symbol.isEmpty ? '?' : coin.symbol[0],
        style: KxText.display(size * 0.42, color: Colors.black),
      ),
    );
    Widget avatar = Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: KxColors.border),
      ),
      child: ClipOval(
        child: coin.image == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: coin.image!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => const ColoredBox(color: KxColors.surface),
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
    if (heroTag != null) avatar = Hero(tag: heroTag!, child: avatar);
    return avatar;
  }
}

/// Star toggle with a bouncy pop + haptic feedback.
class WatchlistStar extends StatelessWidget {
  const WatchlistStar({super.key, required this.coinId, this.size = 22});

  final String coinId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final watched = context.select<WatchlistProvider, bool>((w) => w.contains(coinId));
    return IconButton(
      tooltip: watched ? 'Remove from watchlist' : 'Add to watchlist',
      visualDensity: VisualDensity.compact,
      onPressed: () async {
        HapticFeedback.lightImpact();
        final messenger = ScaffoldMessenger.of(context);
        final error = await context.read<WatchlistProvider>().toggle(coinId);
        if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
          child: child,
        ),
        child: watched
            ? Icon(Icons.star_rounded, key: const ValueKey(true), color: KxColors.warn, size: size)
                .animate(key: const ValueKey('glow'))
                .shimmer(duration: 900.ms, color: Colors.white)
            : Icon(Icons.star_outline_rounded, key: const ValueKey(false), color: KxColors.textMuted, size: size),
      ),
    );
  }
}

/// Pulsing status dot + label: LIVE / CACHED / MOCK.
class SourceBadge extends StatelessWidget {
  const SourceBadge({super.key, required this.source});

  final String? source;

  @override
  Widget build(BuildContext context) {
    if (source == null) return const SizedBox.shrink();
    final (label, color, tip) = switch (source) {
      'live' => ('LIVE', KxColors.up, 'Streaming live data from CoinGecko'),
      'cache' => ('CACHED', KxColors.warn, 'CoinGecko unavailable: showing last cached data'),
      _ => ('DEMO', KxColors.violet, 'Live API unavailable: showing demo data'),
    };
    return Tooltip(
      message: tip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color, blurRadius: 6)],
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fade(begin: 1, end: 0.25, duration: 900.ms, curve: Curves.easeInOut),
            const SizedBox(width: 6),
            Text(label, style: KxText.label(10, color: color)),
          ],
        ),
      ),
    );
  }
}
