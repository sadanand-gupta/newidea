import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/features/coin_detail/chart_range_controller.dart';
import 'package:kryptox/shared/shared.dart';

/// Price-history card: the chart (or its loading / empty / error state) above
/// the range selector.
///
/// Switching to an uncached range keeps the previous series on screen,
/// dimmed, until the new one arrives; a failed refresh of a series already
/// shown keeps it and offers a small retry chip.
class ChartSection extends StatelessWidget {
  const ChartSection({super.key, required this.controller});

  final ChartRangeController controller;

  static const double _chartHeight = 260;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: _chartHeight, child: _buildChart()),
            const SizedBox(height: 14),
            Semantics(
              label: 'Chart range, ${controller.range.longLabel} selected',
              child: KxSegmented<ChartRange>(
                options: ChartRange.values,
                selected: controller.range,
                labelOf: (r) => r.label,
                onSelected: controller.select,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    final range = controller.range;
    final series = controller.visible;
    final error = controller.error;
    final stale = series == null || series.range != range;

    if (error != null && stale) {
      return InlineError.centered(
        title: "Couldn't load the ${range.label} chart",
        message: '$error',
        onRetry: controller.load,
      );
    }
    if (series == null) return const _ChartSkeleton();

    return Stack(
      children: [
        Positioned.fill(
          child: series.points.length < 2
              ? const EmptyView(icon: Icons.show_chart_rounded, title: 'No price history for this range')
              : PriceChart(points: series.points, days: series.range.days, onScrub: controller.onScrub),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              // Only dim the chart when it shows another range; refreshing a
              // range we already have (cached) happens silently.
              child: controller.loading && stale
                  ? _ChartLoadingOverlay(key: const ValueKey('loading'), label: range.label)
                  : const SizedBox.shrink(key: ValueKey('idle')),
            ),
          ),
        ),
        if (error != null && !controller.loading)
          Positioned(
            top: 0,
            left: 0,
            child: RetryChip(onRetry: controller.load, semanticLabel: 'Chart update failed. Retry'),
          ),
      ],
    );
  }
}

/// First load: a shimmering gradient plate with a spinner.
class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Shimmer(
            intensity: 0.18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0.02), KxColors.cyan.withValues(alpha: 0.06)],
                ),
              ),
            ),
          ),
        ),
        const Center(
          child: SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 2, color: KxColors.cyan)),
        ),
      ],
    );
  }
}

/// Dims the previous range's chart and labels which range is loading.
class _ChartLoadingOverlay extends StatelessWidget {
  const _ChartLoadingOverlay({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Shimmer(
            duration: const Duration(milliseconds: 1200),
            intensity: 0.22,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: KxColors.bg.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: KxColors.bgElevated.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: KxColors.cyan.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(
                  dimension: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: KxColors.cyan),
                ),
                const SizedBox(width: 6),
                Text('Loading $label', style: KxText.mono(10, color: KxColors.textDim)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
