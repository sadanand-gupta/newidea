import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/data/models/coin.dart';

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
