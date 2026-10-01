import 'package:flutter/material.dart';

import 'package:kryptox/data/api_service.dart';
import 'package:kryptox/shared/shared.dart';

/// "No results" state of the Markets list, worded for the active search
/// [query] and [filter], with an action that clears them.
class MarketsEmptyView extends StatelessWidget {
  const MarketsEmptyView({super.key, required this.query, required this.filter, required this.onClear});

  /// The trimmed search text; empty when only a filter is active.
  final String query;
  final CoinFilter filter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final filtered = filter != CoinFilter.all;
    final String title;
    final String subtitle;
    final String actionLabel;
    if (query.isEmpty) {
      title = 'No coins in “${filter.label}”';
      subtitle = 'Nothing matches this filter right now. Try another one.';
      actionLabel = 'Show all coins';
    } else {
      title = 'No results for “$query”';
      subtitle = filtered
          ? 'Nothing matches in “${filter.label}”. Check the spelling or search all coins.'
          : 'Check the spelling, or try a coin name or ticker like “BTC”.';
      actionLabel = filtered ? 'Clear search & filter' : 'Clear search';
    }
    return EmptyView(
      icon: Icons.search_off_rounded,
      title: title,
      subtitle: subtitle,
      actionLabel: actionLabel,
      onAction: onClear,
    );
  }
}
