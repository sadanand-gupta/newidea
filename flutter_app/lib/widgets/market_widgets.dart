import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  const AnimatedPrice({super.key, required this.value, required this.style, this.compact = false, this.flash = true});

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
    if (prev == null && next != null) {
      // First real value (e.g. data arrived): show it directly instead of
      // rolling up from zero.
      _from = next;
    } else if (prev != null && next != null && prev != next) {
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
    if (target == null) return Text('—', maxLines: 1, style: widget.style);
    final decimals = priceDecimals(target);
    // Announce the settled value, not the intermediate rolling digits.
    final semantic = widget.compact ? formatCompact(target) : formatPrice(target, decimals: decimals);
    final rolling = TweenAnimationBuilder<double>(
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
              maxLines: 1,
              softWrap: false,
              style: widget.style.copyWith(color: Color.lerp(widget.style.color, _flashColor, k)),
            ),
          );
        },
      ),
    );
    return Semantics(label: semantic, excludeSemantics: true, child: rolling);
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
    // The arrow carries the sign visually; spell it out for screen readers.
    final semantic = value == null
        ? 'No change data'
        : value! >= 0
        ? 'Up $text'
        : 'Down $text';
    final pill = AnimatedContainer(
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
            Icon(
              value! >= 0 ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
              color: color,
              size: size + 6,
            ),
          Text(
            text,
            maxLines: 1,
            softWrap: false,
            style: KxText.mono(size, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
    return Semantics(label: semantic, excludeSemantics: true, child: pill);
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
        coin.symbol.isEmpty ? '?' : coin.symbol[0].toUpperCase(),
        // The glyph is sized to the circle, so it must not grow with the
        // system text scale (it would overflow the avatar).
        textScaler: TextScaler.noScaling,
        style: KxText.display(size * 0.42, color: Colors.black),
      ),
    );
    // Decode logos at display size instead of full resolution: big win for
    // memory and jank in long lists.
    final cacheSize = (size * MediaQuery.devicePixelRatioOf(context)).round();
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
            : kIsWeb
                // On web the browser's HTTP cache does the disk caching, and
                // Image.network shares one load between widgets showing the same
                // logo (CachedNetworkImage left some concurrent copies blank).
                ? Image.network(
                    coin.image!,
                    fit: BoxFit.cover,
                    cacheWidth: cacheSize,
                    frameBuilder: (_, child, frame, sync) => sync
                        ? child
                        : AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: const Duration(milliseconds: 200),
                            child: child,
                          ),
                    errorBuilder: (_, __, ___) => fallback,
                  )
                : CachedNetworkImage(
                    imageUrl: coin.image!,
                    fit: BoxFit.cover,
                    memCacheWidth: cacheSize,
                    fadeInDuration: const Duration(milliseconds: 200),
                    placeholder: (_, __) => const ColoredBox(color: KxColors.surface),
                    errorWidget: (_, __, ___) => fallback,
                  ),
      ),
    );
    if (heroTag != null) avatar = Hero(tag: heroTag!, child: avatar);
    // Decorative: the coin name is always shown/announced next to it.
    return ExcludeSemantics(child: avatar);
  }
}

/// Star toggle with a bouncy pop + haptic feedback.
class WatchlistStar extends StatefulWidget {
  const WatchlistStar({super.key, required this.coinId, this.size = 22, this.coinName});

  final String coinId;
  final double size;

  /// Used in the confirmation message and screen-reader label
  /// ("Add Bitcoin to watchlist"). Optional for backward compatibility.
  final String? coinName;

  @override
  State<WatchlistStar> createState() => _WatchlistStarState();
}

class _WatchlistStarState extends State<WatchlistStar> {
  /// True while a toggle request is in flight; further taps are ignored so a
  /// double tap can't fire add + remove against the server.
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    // Capture before the await: the row may be gone (e.g. removed from the
    // watchlist screen) by the time the request completes.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final provider = context.read<WatchlistProvider>();
    final id = widget.coinId;
    final name = widget.coinName ?? 'Coin';
    final adding = !provider.contains(id);

    setState(() => _busy = true);
    final error = await provider.toggle(id);
    if (mounted) setState(() => _busy = false);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(adding ? '$name added to watchlist' : '$name removed from watchlist'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: KxColors.cyan,
          onPressed: () async {
            // Only undo if the state is still what this action produced.
            if (provider.contains(id) != adding) return;
            final undoError = await provider.toggle(id);
            if (undoError != null) messenger.showSnackBar(SnackBar(content: Text(undoError)));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final watched = context.select<WatchlistProvider, bool>((w) => w.contains(widget.coinId));
    final name = widget.coinName;
    final tooltip = watched
        ? (name == null ? 'Remove from watchlist' : 'Remove $name from watchlist')
        : (name == null ? 'Add to watchlist' : 'Add $name to watchlist');
    return Semantics(
      button: true,
      toggled: watched,
      enabled: !_busy,
      label: tooltip,
      onTap: _busy ? null : _toggle,
      excludeSemantics: true,
      child: IconButton(
        tooltip: tooltip,
        // 44x44 minimum touch target (compact density alone gives only 40).
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        onPressed: _busy ? null : _toggle,
        icon: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _busy ? 0.6 : 1,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
              child: child,
            ),
            child: watched
                ? Icon(
                    Icons.star_rounded,
                    key: const ValueKey(true),
                    color: KxColors.warn,
                    size: widget.size,
                  ).animate(key: const ValueKey('glow')).shimmer(duration: 900.ms, color: Colors.white)
                : Icon(
                    Icons.star_outline_rounded,
                    key: const ValueKey(false),
                    color: KxColors.textDim,
                    size: widget.size,
                  ),
          ),
        ),
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
            Text(label, maxLines: 1, softWrap: false, style: KxText.label(10, color: color)),
          ],
        ),
      ),
    );
  }
}
