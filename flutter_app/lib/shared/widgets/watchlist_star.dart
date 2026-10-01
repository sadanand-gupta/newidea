import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/state/watchlist_provider.dart';

/// Watchlist toggle: a star with a bouncy pop, haptics and a confirmation
/// snackbar with Undo (or the error when the request fails).
///
/// Taps are ignored while a toggle is in flight so a double tap can't fire
/// add + remove against the server. Used in list rows (default size) and in
/// the coin detail header (`size: 26, tapTarget: 48`).
class WatchlistStar extends StatefulWidget {
  const WatchlistStar({
    super.key,
    required this.coinId,
    this.size = 22,
    this.coinName,
    this.tapTarget = KxLayout.minTapTarget,
  });

  final String coinId;

  /// Icon size.
  final double size;

  /// Square hit area around the icon; never below [KxLayout.minTapTarget].
  final double tapTarget;

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
    final tapTarget = widget.tapTarget < KxLayout.minTapTarget ? KxLayout.minTapTarget : widget.tapTarget;
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
        // Explicit square target (compact density alone gives only 40).
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(width: tapTarget, height: tapTarget),
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
