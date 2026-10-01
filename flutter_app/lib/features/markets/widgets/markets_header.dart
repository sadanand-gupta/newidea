import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/data/api_service.dart';
import 'package:kryptox/shared/shared.dart';

/// Page header of the Markets tab: menu · "MARKETS / KryptoX" · data source,
/// refresh (wide layouts only) and sort buttons, with an
/// "Updated 12s ago · Sorted by market cap ↓" status line underneath.
class MarketsHeader extends StatelessWidget {
  const MarketsHeader({
    super.key,
    required this.source,
    required this.updatedAt,
    required this.loading,
    required this.sort,
    required this.descending,
    required this.showRefreshButton,
    required this.onRefresh,
    required this.onSortPressed,
  });

  final String? source;
  final DateTime? updatedAt;

  /// A refresh is in flight; turns the refresh button into a spinner.
  final bool loading;
  final CoinSort sort;
  final bool descending;

  /// Mice can't pull-to-refresh, so wide layouts get an explicit button.
  final bool showRefreshButton;
  final VoidCallback onRefresh;
  final VoidCallback onSortPressed;

  bool get _isDefaultSort => sort == CoinSort.marketCap && descending;

  @override
  Widget build(BuildContext context) {
    return Entrance(
      duration: const Duration(milliseconds: 500),
      offset: const Offset(0, -0.15),
      child: KxPageHeader(
        eyebrow: 'MARKETS',
        title: 'KryptoX',
        titleSize: 32,
        padding: KxLayout.headerPadding.copyWith(bottom: 0),
        actions: [
          SourceBadge(source: source),
          if (showRefreshButton)
            KxIconButton(
              icon: Icons.refresh_rounded,
              tooltip: loading ? 'Refreshing…' : 'Refresh prices',
              busy: loading,
              onPressed: onRefresh,
            ),
          KxIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Sort markets',
            showBadge: !_isDefaultSort,
            onPressed: onSortPressed,
          ),
        ],
        bottom: Padding(
          // Lines the status up with the menu button's glyph.
          padding: const EdgeInsets.only(left: 4, top: 2),
          child: Row(
            children: [
              const ExcludeSemantics(child: Icon(Icons.schedule_rounded, size: 12, color: KxColors.textMuted)),
              const SizedBox(width: 5),
              Flexible(child: UpdatedAgo(time: updatedAt)),
              ExcludeSemantics(
                child: Text('  ·  ', style: KxText.mono(11, color: KxColors.textMuted)),
              ),
              Flexible(
                child: _SortStatus(sort: sort, descending: descending, onPressed: onSortPressed),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tappable "Sorted by market cap ↓" label that opens the sort sheet.
class _SortStatus extends StatelessWidget {
  const _SortStatus({required this.sort, required this.descending, required this.onPressed});

  final CoinSort sort;
  final bool descending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = 'Sorted by ${sort.label.toLowerCase()}';
    return Semantics(
      button: true,
      label: '$label, ${descending ? 'descending' : 'ascending'}. Change sort order',
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          // Vertical padding gives the small label a comfortable tap target.
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KxText.body(11, weight: FontWeight.w500, color: KxColors.textDim),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                descending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                size: 12,
                color: KxColors.textDim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
