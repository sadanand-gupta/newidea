import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/features/stats/asset_colors.dart';
import 'package:kryptox/shared/shared.dart';

/// One segment of the dominance donut.
typedef _Slice = ({String label, double pct, Color color});

/// Market-cap dominance donut with a tappable legend. The centre shows the
/// selected asset's share, or the leader's when nothing is selected.
///
/// The legend sits beside the donut when there is room, below it otherwise.
class DominanceCard extends StatefulWidget {
  const DominanceCard({super.key, required this.dominance});

  /// Symbol (upper case) → share of total market cap in percent, largest first.
  final Map<String, double> dominance;

  @override
  State<DominanceCard> createState() => _DominanceCardState();
}

class _DominanceCardState extends State<DominanceCard> {
  static const _maxSlices = 5;
  static const _donutSize = 150.0;
  static const _ringWidth = 20.0;
  static const _selectedRingWidth = 26.0;

  /// Selected slice, or -1 for none.
  int _selected = -1;

  List<_Slice> _slices() {
    final top = widget.dominance.entries.take(_maxSlices).toList();
    final others = (100 - top.fold<double>(0, (s, e) => s + e.value)).clamp(0.0, 100.0);
    return [
      for (final (i, e) in top.indexed) (label: e.key, pct: e.value, color: AssetColors.of(e.key, i)),
      if (others > 0.05) (label: 'Others', pct: others, color: KxColors.textMuted),
    ];
  }

  /// Selects slice [i], or clears the selection if it is already selected.
  void _toggle(int i) => setState(() => _selected = i == _selected ? -1 : i);

  @override
  Widget build(BuildContext context) {
    final slices = _slices();
    if (slices.isEmpty) return const SizedBox.shrink();
    final selected = _selected < slices.length ? _selected : -1;

    final donut = _buildDonut(slices, selected);
    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, s) in slices.indexed)
          DominanceLegendRow(
            label: s.label,
            percent: s.pct,
            color: s.color,
            active: selected == i,
            dimmed: selected >= 0 && selected != i,
            onTap: () => _toggle(i),
          ),
      ],
    );

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Side-by-side needs room for "SYMBOL  12.3%" next to the donut;
          // otherwise (narrow phones, large text) stack the legend underneath.
          final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
          final legendRoom = constraints.maxWidth - _donutSize - 16;
          if (legendRoom >= 120 * textScale) {
            return Row(
              children: [
                donut,
                const SizedBox(width: 16),
                Expanded(child: legend),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: donut),
              const SizedBox(height: 12),
              legend,
            ],
          );
        },
      ),
    );
  }

  Widget _buildDonut(List<_Slice> slices, int selected) {
    final focus = slices[math.max(selected, 0)];
    final total = slices.fold<double>(0, (s, e) => s + e.pct);
    return Semantics(
      label: 'Market-cap dominance chart. ${focus.label} ${focus.pct.toStringAsFixed(1)} percent',
      child: SizedBox.square(
        dimension: _donutSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ExcludeSemantics(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) {
                  final k = math.max(t, 0.001);
                  return PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      sectionsSpace: 2,
                      centerSpaceRadius: 46,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (event is! FlTapUpEvent) return;
                          final i = response?.touchedSection?.touchedSectionIndex ?? -1;
                          if (i >= 0 && i < slices.length) {
                            _toggle(i);
                          } else if (_selected != -1) {
                            setState(() => _selected = -1);
                          }
                        },
                      ),
                      sections: [
                        for (final (i, s) in slices.indexed)
                          PieChartSectionData(
                            value: s.pct * k,
                            color: selected < 0 || selected == i ? s.color : s.color.withValues(alpha: 0.3),
                            radius: selected == i ? _selectedRingWidth : _ringWidth,
                            showTitle: false,
                          ),
                        // Transparent remainder makes the ring sweep in clockwise.
                        if (t < 1)
                          PieChartSectionData(
                            value: total * (1 - k),
                            color: Colors.transparent,
                            radius: _ringWidth,
                            showTitle: false,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            ExcludeSemantics(
              child: IgnorePointer(
                // Keep the centre readout inside the donut hole at any text scale.
                child: SizedBox(
                  width: 78,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(scale: Tween<double>(begin: 0.85, end: 1).animate(anim), child: child),
                      ),
                      child: Column(
                        key: ValueKey(focus.label),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(focus.label.toUpperCase(), style: KxText.label(10, color: focus.color)),
                          const SizedBox(height: 2),
                          CountUp(
                            value: focus.pct,
                            format: (v) => '${v.toStringAsFixed(1)}%',
                            style: KxText.mono(17, weight: FontWeight.w700),
                          ),
                          Text(selected < 0 ? 'leader' : 'share', style: KxText.body(9, color: KxColors.textDim)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable legend entry: colour dot, symbol and share. Highlighted when
/// [active], faded when another entry is selected ([dimmed]).
class DominanceLegendRow extends StatelessWidget {
  const DominanceLegendRow({
    super.key,
    required this.label,
    required this.percent,
    required this.color,
    required this.onTap,
    this.active = false,
    this.dimmed = false,
  });

  final String label;
  final double percent;
  final Color color;
  final VoidCallback onTap;
  final bool active;
  final bool dimmed;

  static const _margin = 2.0;
  static const _animation = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final share = '${percent.toStringAsFixed(1)}%';
    return Semantics(
      button: true,
      selected: active,
      label: '$label, ${percent.toStringAsFixed(1)} percent of total market cap',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // The margin is inside the detector, so the hit target is a full minTapTarget.
        child: AnimatedContainer(
          duration: _animation,
          margin: const EdgeInsets.symmetric(vertical: _margin),
          constraints: const BoxConstraints(minHeight: KxLayout.minTapTarget - 2 * _margin),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: AnimatedOpacity(
            duration: _animation,
            opacity: dimmed ? 0.45 : 1,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: KxText.body(12, weight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(share, style: KxText.mono(12, color: KxColors.textDim)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
