import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';

/// Centred one-line note inside a dashboard section ("No mover data…").
///
/// With [onTap] it becomes a full-width cyan text button ("+3 more in your
/// watchlist") with a 44px tap target.
class MutedNote extends StatelessWidget {
  const MutedNote({super.key, required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tappable = onTap != null;
    final label = Text(
      text,
      textAlign: TextAlign.center,
      style: KxText.body(
        13,
        weight: tappable ? FontWeight.w600 : FontWeight.w400,
        color: tappable ? KxColors.cyan : KxColors.textMuted,
      ),
    );
    if (!tappable) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: label);
    }
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(minimumSize: const Size.fromHeight(KxLayout.minTapTarget)),
      child: label,
    );
  }
}
