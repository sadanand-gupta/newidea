import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/shared/shared.dart';

/// Description (collapsible), category pills and the project's website.
///
/// Only build it when [hasContent] is true for the detail.
class AboutCard extends StatelessWidget {
  const AboutCard({super.key, required this.detail});

  final CoinDetail detail;

  /// Whether [detail] has anything for this card to show.
  static bool hasContent(CoinDetail detail) =>
      detail.description.isNotEmpty || detail.categories.isNotEmpty || detail.homepage != null;

  @override
  Widget build(BuildContext context) {
    final homepage = detail.homepage;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.description.isNotEmpty) _ExpandableText(text: detail.description),
          if (detail.categories.isNotEmpty) ...[
            if (detail.description.isNotEmpty) const SizedBox(height: 16),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final c in detail.categories) _CategoryPill(label: c)]),
          ],
          if (homepage != null) ...[const SizedBox(height: 16), _WebsiteRow(url: homepage)],
        ],
      ),
    );
  }
}

/// Selectable website link with a copy-to-clipboard button.
class _WebsiteRow extends StatelessWidget {
  const _WebsiteRow({required this.url});

  final String url;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: url));
    HapticFeedback.selectionClick();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Website link copied')));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.language_rounded, size: 16, color: KxColors.cyan),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SelectableText(url, style: KxText.mono(12, color: KxColors.cyan)),
          ),
        ),
        const SizedBox(width: 4),
        KxIconButton(
          style: KxIconButtonStyle.plain,
          icon: Icons.copy_rounded,
          iconSize: 16,
          tooltip: 'Copy website link',
          onPressed: () => _copy(context),
        ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.07), Colors.white.withValues(alpha: 0.03)]),
        border: Border.all(color: KxColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: KxColors.brandGradient),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KxText.body(12, weight: FontWeight.w500, color: KxColors.textDim),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text clamped to a few lines with a "Read more" / "Show less" toggle that
/// only appears when the text actually overflows.
class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  static const _collapsedLines = 4;
  bool _expanded = false;

  bool _overflows(TextStyle style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: _collapsedLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    final overflows = painter.didExceedMaxLines;
    painter.dispose();
    return overflows;
  }

  @override
  Widget build(BuildContext context) {
    final style = KxText.body(14, color: KxColors.textDim).copyWith(height: 1.55);
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : _collapsedLines,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ),
          if (_overflows(style, constraints.maxWidth)) ...[
            const SizedBox(height: 2),
            Semantics(
              button: true,
              expanded: _expanded,
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: KxLayout.minTapTarget),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GradientText(
                          _expanded ? 'Show less' : 'Read more',
                          style: KxText.body(13, weight: FontWeight.w700),
                        ),
                        const SizedBox(width: 2),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: KxColors.violet),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
