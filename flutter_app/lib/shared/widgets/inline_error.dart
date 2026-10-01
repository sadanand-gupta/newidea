import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/shared/widgets/glass_card.dart';
import 'package:kryptox/shared/widgets/gradient_button.dart';

/// Error state for one section of a page (as opposed to the full-screen
/// `ErrorView`), with a 44px Retry.
///
/// The default constructor is a compact red-tinted card: icon, [title],
/// [message] and a Retry text button on the right. [InlineError.centered] is
/// a stacked, card-less variant that fills a fixed slot (e.g. the chart area)
/// and scrolls rather than overflowing at large text sizes.
class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.title, this.message, required this.onRetry}) : centered = false;

  const InlineError.centered({super.key, required this.title, this.message, required this.onRetry}) : centered = true;

  /// Short headline, e.g. "Market data unavailable".
  final String title;

  /// Secondary detail, typically the error text.
  final String? message;
  final VoidCallback onRetry;
  final bool centered;

  @override
  Widget build(BuildContext context) => centered ? _buildCentered() : _buildCard();

  Widget _buildCard() {
    return GlassCard(
      radius: KxLayout.radiusRow,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      gradient: LinearGradient(colors: [KxColors.down.withValues(alpha: 0.12), KxColors.down.withValues(alpha: 0.04)]),
      child: Row(
        children: [
          const Icon(Icons.wifi_tethering_error_rounded, color: KxColors.down, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: KxText.body(14, weight: FontWeight.w600)),
                if (message != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    message!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: KxText.body(12, color: KxColors.textDim),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              minimumSize: const Size.square(KxLayout.minTapTarget),
              foregroundColor: KxColors.cyan,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildCentered() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [KxColors.down.withValues(alpha: 0.25), KxColors.down.withValues(alpha: 0)],
                ),
                border: Border.all(color: KxColors.down.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.cloud_off_rounded, color: KxColors.down, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: KxText.body(13, weight: FontWeight.w600),
            ),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: KxText.body(12, color: KxColors.textDim),
              ),
            ],
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: KxLayout.minTapTarget),
              child: GradientButton(label: 'Retry', icon: Icons.refresh_rounded, onPressed: onRetry),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill overlaid on content whose background refresh failed
/// ("Update failed · Retry"). The pill is 36px tall but its hit area is 44px.
class RetryChip extends StatelessWidget {
  const RetryChip({
    super.key,
    required this.onRetry,
    this.label = 'Update failed · Retry',
    this.semanticLabel = 'Update failed. Retry',
  });

  final VoidCallback onRetry;
  final String label;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(10);
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onRetry,
      excludeSemantics: true,
      // The transparent 4px band above/below the pill still counts as a tap.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRetry,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: (KxLayout.minTapTarget - 36) / 2),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onRetry,
              borderRadius: shape,
              child: Ink(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: KxColors.bgElevated.withValues(alpha: 0.9),
                  borderRadius: shape,
                  border: Border.all(color: KxColors.down.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded, size: 14, color: KxColors.down),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: KxText.mono(11, weight: FontWeight.w600, color: KxColors.down),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
