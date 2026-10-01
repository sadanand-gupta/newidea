import 'package:flutter/painting.dart';

import 'package:kryptox/core/theme/app_theme.dart';

/// Colours for assets in market-wide charts: brand colours for well-known
/// assets, the neon palette for everything else.
abstract final class AssetColors {
  static const btc = Color(0xFFF7931A);
  static const eth = Color(0xFF627EEA);

  static const _brand = <String, Color>{
    'BTC': btc,
    'ETH': eth,
    'USDT': Color(0xFF26A17B),
    'BNB': Color(0xFFF3BA2F),
    'SOL': Color(0xFF9945FF),
    'USDC': Color(0xFF2775CA),
    'XRP': Color(0xFF8FA3BF),
    'STETH': Color(0xFF00A3FF),
  };

  static const _fallback = [
    KxColors.cyan,
    KxColors.violet,
    KxColors.magenta,
    KxColors.up,
    KxColors.warn,
    Color(0xFF3B82F6),
  ];

  /// Brand colour of [symbol] (upper case), or the palette colour for
  /// position [index] when the asset has none.
  static Color of(String symbol, int index) => _brand[symbol] ?? _fallback[index % _fallback.length];
}
