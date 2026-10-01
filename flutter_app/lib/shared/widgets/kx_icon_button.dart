import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/shared/widgets/glass_card.dart';

/// Visual treatment of a [KxIconButton].
enum KxIconButtonStyle {
  /// Frosted rounded square (page headers: menu, refresh, sort).
  glass,

  /// Translucent circle with a hairline border (back button on pushed pages).
  circle,

  /// Icon only, no chrome (secondary actions next to other controls).
  plain,
}

/// 44×44 icon button used across the app's headers.
///
/// [tooltip] doubles as the screen-reader label. A null [onPressed] disables
/// the button; [busy] swaps the icon for a spinner and disables it too.
/// [showBadge] adds a small gradient dot (e.g. "a non-default sort is on").
class KxIconButton extends StatelessWidget {
  const KxIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.style = KxIconButtonStyle.glass,
    this.busy = false,
    this.showBadge = false,
    this.iconSize,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final KxIconButtonStyle style;
  final bool busy;
  final bool showBadge;

  /// Defaults to 20 (glass), 16 (circle) or 22 (plain).
  final double? iconSize;

  /// Icon colour; defaults to [KxColors.text] ([KxColors.textDim] for plain).
  final Color? color;

  static const double _size = KxLayout.minTapTarget;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final tap = enabled ? onPressed : null;
    final size =
        iconSize ??
        switch (style) {
          KxIconButtonStyle.glass => 20.0,
          KxIconButtonStyle.circle => 16.0,
          KxIconButtonStyle.plain => 22.0,
        };
    final glyph = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: busy
          ? SizedBox.square(
              key: const ValueKey('busy'),
              dimension: size,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 2, color: KxColors.cyan),
              ),
            )
          : Icon(
              icon,
              key: const ValueKey('icon'),
              size: size,
              color: color ?? (style == KxIconButtonStyle.plain ? KxColors.textDim : KxColors.text),
            ),
    );

    Widget button = switch (style) {
      KxIconButtonStyle.glass => GlassCard(
        radius: KxLayout.radiusButton,
        padding: EdgeInsets.zero,
        onTap: tap,
        child: SizedBox.square(
          dimension: _size,
          child: Center(child: glyph),
        ),
      ),
      KxIconButtonStyle.circle => Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: tap,
          customBorder: const CircleBorder(),
          splashColor: KxColors.cyan.withValues(alpha: 0.12),
          child: Ink(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: KxColors.border),
            ),
            child: Center(child: glyph),
          ),
        ),
      ),
      KxIconButtonStyle.plain => Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: tap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: _size,
            child: Center(child: glyph),
          ),
        ),
      ),
    };

    if (showBadge) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: -2,
            right: -2,
            child: IgnorePointer(
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: KxColors.brandGradient,
                  border: Border.all(color: KxColors.bg, width: 1.5),
                  boxShadow: [BoxShadow(color: KxColors.cyan.withValues(alpha: 0.6), blurRadius: 6)],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        onTap: tap,
        excludeSemantics: true,
        child: button,
      ),
    );
  }
}
