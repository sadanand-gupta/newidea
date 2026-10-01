import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/core/utils/formatters.dart';
import 'package:kryptox/shared/widgets/gradient_text.dart';
import 'package:kryptox/shared/widgets/kx_icon_button.dart';
import 'package:kryptox/shared/widgets/source_badge.dart';

/// Top-of-tab header: optional menu button, cyan eyebrow, gradient title and
/// trailing [actions], with an optional [bottom] line (e.g. "Updated 12s ago ·
/// Sorted by market cap") underneath.
///
/// The title scales down instead of wrapping on narrow phones / large text.
/// Pushed pages with a back button (coin detail) build their own header.
class KxPageHeader extends StatelessWidget {
  const KxPageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.showMenuButton = true,
    this.titleSize = 28,
    this.actions = const [],
    this.bottom,
    this.padding = KxLayout.headerPadding,
  });

  final String title;

  /// Small tracked label above the title ("MARKETS", "OVERVIEW").
  final String? eyebrow;

  /// Leading [KxMenuButton] that opens the shell's drawer.
  final bool showMenuButton;
  final double titleSize;

  /// Trailing widgets (source badge, [HeaderStatus], [KxIconButton]s),
  /// separated by 10px.
  final List<Widget> actions;

  /// Full-width line below the title row.
  final Widget? bottom;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final row = LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          if (showMenuButton) ...[const KxMenuButton(), const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!, maxLines: 1, overflow: TextOverflow.ellipsis, style: KxText.eyebrow()),
                  const SizedBox(height: 2),
                ],
                Semantics(
                  header: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: GradientText(title, style: KxText.display(titleSize).copyWith(letterSpacing: -1)),
                  ),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty)
            // Actions stay flush right at full size until they'd take over half
            // the row (narrow phones, large text), then shrink together.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(width: 10), actions[i]],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return Padding(
      padding: padding,
      child: bottom == null
          ? row
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [row, bottom!],
            ),
    );
  }
}

/// Glass "hamburger" button that opens the nearest ancestor Scaffold drawer.
///
/// Walks up past Scaffolds without a drawer (e.g. a tab's own transparent
/// Scaffold) to the shell Scaffold that hosts `KxDrawer`.
class KxMenuButton extends StatelessWidget {
  const KxMenuButton({super.key, this.tooltip = 'Open menu'});

  final String tooltip;

  /// Opens the closest drawer above [context]; no-op when there is none.
  static void openDrawer(BuildContext context) {
    var scaffold = Scaffold.maybeOf(context);
    while (scaffold != null && !scaffold.hasDrawer) {
      scaffold = scaffold.context.findAncestorStateOfType<ScaffoldState>();
    }
    scaffold?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return KxIconButton(icon: Icons.menu_rounded, tooltip: tooltip, onPressed: () => openDrawer(context));
  }
}

/// Right-aligned data status for headers: [SourceBadge] with the time of the
/// last update ("Updated 22:39") underneath.
class HeaderStatus extends StatelessWidget {
  const HeaderStatus({super.key, required this.source, this.updatedAt});

  final String? source;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        SourceBadge(source: source),
        if (updatedAt != null) ...[
          const SizedBox(height: 6),
          Text(
            'Updated ${formatTime(updatedAt!)}',
            maxLines: 1,
            softWrap: false,
            style: KxText.mono(10, color: KxColors.textMuted),
          ),
        ],
      ],
    );
  }
}
