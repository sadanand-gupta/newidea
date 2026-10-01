import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';

/// Uppercase tracked section label with a gradient tick.
///
/// The title ellipsizes rather than overflowing on narrow screens with large
/// text. Pass [onAction] to add a "See all"-style [SectionAction] on the right
/// (the row then keeps a 44px minimum height), or any custom [trailing] widget.
/// Set [reserveActionSpace] when the action comes and goes, so the layout
/// below doesn't jump.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, 8, 4, 12),
    this.onAction,
    this.actionLabel = 'See all',
    this.actionSemanticLabel,
    this.reserveActionSpace = false,
  });

  final String title;

  /// Custom widget shown at the end of the row (e.g. a tag or hint).
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  /// Adds a [SectionAction] after [trailing] when non-null.
  final VoidCallback? onAction;
  final String actionLabel;

  /// Screen-reader label for the action, e.g. "See all market stats".
  final String? actionSemanticLabel;

  /// Keeps the action's 44px row height even while [onAction] is null.
  final bool reserveActionSpace;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(gradient: KxColors.brandGradient, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title.toUpperCase(), style: KxText.label(12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        if (onAction != null)
          SectionAction(label: actionLabel, semanticLabel: actionSemanticLabel, onPressed: onAction!),
      ],
    );
    return Padding(
      padding: padding,
      child: onAction == null && !reserveActionSpace
          ? row
          : ConstrainedBox(
              constraints: const BoxConstraints(minHeight: KxLayout.minTapTarget),
              child: row,
            ),
    );
  }
}

/// Compact cyan text button with a chevron ("See all ›") for section headers.
class SectionAction extends StatelessWidget {
  const SectionAction({super.key, required this.onPressed, this.label = 'See all', this.semanticLabel});

  final VoidCallback onPressed;
  final String label;

  /// Defaults to [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size.square(KxLayout.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          foregroundColor: KxColors.cyan,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KxLayout.radiusControl)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: KxText.body(13, weight: FontWeight.w600, color: KxColors.cyan),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded, size: 18, color: KxColors.cyan),
          ],
        ),
      ),
    );
  }
}
