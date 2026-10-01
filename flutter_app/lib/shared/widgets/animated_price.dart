import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/core/utils/formatters.dart';

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
