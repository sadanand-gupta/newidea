import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/data/api_service.dart';
import 'package:kryptox/shared/shared.dart';

/// Called whenever the user picks a different sort key or direction.
typedef SortChanged = void Function(CoinSort sort, bool descending);

/// Opens the [SortSheet] as a modal bottom sheet. Changes are applied live via
/// [onChanged]; the sheet stays open so several can be tried in a row.
Future<void> showSortSheet(
  BuildContext context, {
  required CoinSort sort,
  required bool descending,
  required SortChanged onChanged,
}) {
  HapticFeedback.selectionClick();
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => SortSheet(initialSort: sort, initialDescending: descending, onChanged: onChanged),
  );
}

/// Bottom sheet for choosing the Markets list's sort key and direction.
class SortSheet extends StatefulWidget {
  const SortSheet({super.key, required this.initialSort, required this.initialDescending, required this.onChanged});

  final CoinSort initialSort;
  final bool initialDescending;
  final SortChanged onChanged;

  @override
  State<SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<SortSheet> {
  late CoinSort _sort = widget.initialSort;
  late bool _descending = widget.initialDescending;

  static IconData _iconOf(CoinSort s) => switch (s) {
    CoinSort.marketCap => Icons.pie_chart_outline_rounded,
    CoinSort.price => Icons.attach_money_rounded,
    CoinSort.volume => Icons.bar_chart_rounded,
    CoinSort.change24h => Icons.show_chart_rounded,
    CoinSort.change7d => Icons.timeline_rounded,
    CoinSort.name => Icons.sort_by_alpha_rounded,
  };

  void _update({CoinSort? sort, bool? descending}) {
    final nextSort = sort ?? _sort;
    final nextDescending = descending ?? _descending;
    if (nextSort == _sort && nextDescending == _descending) return;
    HapticFeedback.selectionClick();
    setState(() {
      _sort = nextSort;
      _descending = nextDescending;
    });
    widget.onChanged(nextSort, nextDescending);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: KxColors.borderStrong),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(KxColors.bgElevated, KxColors.violet, 0.06)!, KxColors.bgElevated],
        ),
        boxShadow: [
          BoxShadow(color: KxColors.cyan.withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, -8)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(KxLayout.gutter, 10, KxLayout.gutter, KxLayout.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: KxColors.borderStrong, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: KxLayout.sectionGap),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(header: true, child: Text('Sort markets', style: KxText.display(20))),
                        const SizedBox(height: 2),
                        Text(
                          'Choose how the list is ordered',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KxText.body(12, color: KxColors.textDim),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: MediaQuery.textScalerOf(context).scale(128).clamp(128.0, 176.0),
                    child: KxSegmented<bool>(
                      options: const [true, false],
                      selected: _descending,
                      labelOf: (d) => d ? '↓ DESC' : '↑ ASC',
                      onSelected: (d) => _update(descending: d),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KxLayout.sectionGap),
              for (final (i, sort) in CoinSort.values.indexed)
                Entrance(
                  index: i,
                  stagger: const Duration(milliseconds: 35),
                  maxStaggered: CoinSort.values.length,
                  duration: const Duration(milliseconds: 320),
                  offset: const Offset(0, 0.2),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SortOption(
                      label: sort.label,
                      icon: _iconOf(sort),
                      selected: sort == _sort,
                      onTap: () => _update(sort: sort),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One selectable sort key: icon tile, label and a check mark when selected.
class _SortOption extends StatelessWidget {
  const _SortOption({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Sort by $label',
      excludeSemantics: true,
      child: GlassCard(
        radius: KxLayout.radiusTile,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: onTap,
        glow: selected ? KxColors.cyan : null,
        gradient: selected
            ? LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [KxColors.cyan.withValues(alpha: 0.16), KxColors.violet.withValues(alpha: 0.10)],
              )
            : null,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: selected ? KxColors.brandGradient : null,
                color: selected ? null : KxColors.surface,
              ),
              child: Icon(icon, size: 18, color: selected ? Colors.black : KxColors.textDim),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KxText.body(
                  15,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? KxColors.text : KxColors.textDim,
                ),
              ),
            ),
            AnimatedScale(
              scale: selected ? 1 : 0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: KxColors.brandGradient,
                  boxShadow: [BoxShadow(color: KxColors.cyan.withValues(alpha: 0.5), blurRadius: 10)],
                ),
                child: const Icon(Icons.check_rounded, size: 16, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
