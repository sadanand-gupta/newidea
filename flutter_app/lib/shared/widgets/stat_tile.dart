import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/shared/widgets/glass_card.dart';
import 'package:kryptox/shared/widgets/icon_badge.dart';

/// A labelled figure: small uppercase [label] over a mono [value], with an
/// optional [caption] below and an optional [icon] badge beside the label.
///
/// By default it is framed in a [GlassCard]; set [framed] to false to place
/// it inside another card (e.g. a row of stats in a hero card). Long values
/// scale down instead of overflowing. When stretched (e.g. in an
/// `IntrinsicHeight` row) the value sticks to the bottom, so values in a row
/// line up regardless of label length.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
    this.caption,
    this.icon,
    this.iconColor = KxColors.cyan,
    this.valueColor,
    this.valueSize = 15,
    this.framed = true,
    this.semanticLabel,
  }) : assert(value != null || valueWidget != null, 'Provide value or valueWidget');

  final String label;

  /// Plain text value; ignored when [valueWidget] is set.
  final String? value;

  /// Custom value (e.g. a `CountUp` or `AnimatedPrice`). Wrapped in a
  /// scale-down FittedBox like [value].
  final Widget? valueWidget;
  final String? caption;
  final IconData? icon;
  final Color iconColor;

  /// Colour of a text [value] (e.g. [KxColors.change]); defaults to text.
  final Color? valueColor;
  final double valueSize;
  final bool framed;

  /// Replaces the merged semantics of the tile (e.g. to spell out a value).
  final String? semanticLabel;

  /// Style for a custom [valueWidget] so it matches a text value.
  static TextStyle valueStyle({double size = 15, Color? color}) =>
      KxText.mono(size, weight: size >= 18 ? FontWeight.w700 : FontWeight.w600, color: color ?? KxColors.text);

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label.toUpperCase(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: KxText.label(10, color: KxColors.textMuted),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (icon != null)
          Row(
            children: [
              IconBadge(icon: icon!, color: iconColor, size: 30),
              const SizedBox(width: 10),
              Expanded(child: labelText),
            ],
          )
        else
          labelText,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: icon != null ? 12 : 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child:
                  valueWidget ??
                  Text(
                    value!,
                    maxLines: 1,
                    style: valueStyle(size: valueSize, color: valueColor),
                  ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KxText.body(11, color: KxColors.textDim),
              ),
            ],
          ],
        ),
      ],
    );

    Widget tile = framed
        ? GlassCard(
            radius: icon != null ? KxLayout.radiusRow : KxLayout.radiusTile,
            padding: EdgeInsets.all(icon != null ? 14 : 12),
            child: content,
          )
        : content;
    if (semanticLabel != null) {
      tile = Semantics(container: true, label: semanticLabel, excludeSemantics: true, child: tile);
    }
    return tile;
  }
}
