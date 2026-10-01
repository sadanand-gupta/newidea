import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/data/api_service.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/features/coin_detail/chart_range_controller.dart';
import 'package:kryptox/features/coin_detail/widgets/about_card.dart';
import 'package:kryptox/features/coin_detail/widgets/chart_section.dart';
import 'package:kryptox/features/coin_detail/widgets/detail_header.dart';
import 'package:kryptox/features/coin_detail/widgets/detail_skeleton.dart';
import 'package:kryptox/features/coin_detail/widgets/market_stats_grid.dart';
import 'package:kryptox/features/coin_detail/widgets/performance_row.dart';
import 'package:kryptox/features/coin_detail/widgets/price_block.dart';
import 'package:kryptox/features/coin_detail/widgets/range_bar.dart';
import 'package:kryptox/features/coin_detail/widgets/supply_card.dart';
import 'package:kryptox/shared/shared.dart';
import 'package:kryptox/state/loadable.dart';

/// Full page for one coin: price, interactive chart, 24h range, performance,
/// market stats, supply and project info.
///
/// Opens instantly with the list row's data ([initial]) while the full
/// details and the chart load independently.
class CoinDetailScreen extends StatefulWidget {
  const CoinDetailScreen({super.key, required this.coinId, this.initial, this.heroTag});

  final String coinId;

  /// Row data from the list, shown immediately while details load.
  final Coin? initial;

  /// Hero tag of the list avatar so the logo flies into the header.
  final String? heroTag;

  @override
  State<CoinDetailScreen> createState() => _CoinDetailScreenState();
}

class _CoinDetailScreenState extends State<CoinDetailScreen> {
  final _detail = Loadable<CoinDetail>();
  late final ChartRangeController _chart;
  late final ApiService _api;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _chart = ChartRangeController(fetch: (days) => _api.getChart(widget.coinId, days));
    _loadDetail();
    _chart.load();
  }

  @override
  void dispose() {
    _detail.dispose();
    _chart.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() => _detail.load(() => _api.getCoinDetail(widget.coinId));

  Future<void> _refresh() => Future.wait([_loadDetail(), _chart.load()]);

  @override
  Widget build(BuildContext context) {
    return KxBackground(
      intensity: 0.7,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: _detail,
            builder: (context, _) {
              final detail = _detail.data;
              final coin = detail?.coin ?? widget.initial;
              return Column(
                children: [
                  ContentWidth(
                    child: DetailHeader(
                      coin: coin,
                      coinId: widget.coinId,
                      heroTag: widget.heroTag,
                      source: _detail.source,
                    ),
                  ),
                  Expanded(child: _buildBody(coin, detail)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Coin? coin, CoinDetail? detail) {
    final error = _detail.error;
    if (coin == null) {
      return error != null ? ErrorView(message: '$error', onRetry: _loadDetail) : const DetailPageLoader();
    }

    final low = coin.low24h, high = coin.high24h, price = coin.price;
    final sections = <Widget>[
      if (detail != null && error != null)
        KeyedSubtree(
          key: const ValueKey('section-banner'),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: RefreshErrorBanner(message: '$error', onRetry: _loadDetail),
          ),
        ),
      _Section(
        id: 'price',
        index: 0,
        gap: 14,
        child: PriceBlock(coin: coin, detail: detail, chart: _chart, updatedAt: _detail.updatedAt),
      ),
      _Section(
        id: 'chart',
        index: 1,
        child: ChartSection(controller: _chart),
      ),
      if (low != null && high != null && price != null)
        _Section(
          id: 'range',
          index: 2,
          child: GlassCard(
            child: DayRangeBar(low: low, high: high, current: price),
          ),
        ),
      if (detail != null) ...[
        _Section(
          id: 'performance',
          index: 0,
          title: 'Performance',
          child: PerformanceRow(detail: detail),
        ),
        _Section(
          id: 'stats',
          index: 1,
          title: 'Market stats',
          child: MarketStatsGrid(detail: detail),
        ),
        _Section(
          id: 'supply',
          index: 2,
          title: 'Supply',
          child: SupplyCard(coin: detail.coin),
        ),
        if (AboutCard.hasContent(detail))
          _Section(
            id: 'about',
            index: 3,
            title: 'About ${coin.name}',
            child: AboutCard(detail: detail),
          ),
      ] else if (error != null)
        _Section(
          id: 'details-error',
          index: 3,
          child: GlassCard(
            glow: KxColors.down,
            child: InlineError.centered(title: 'Could not load full details', message: '$error', onRetry: _loadDetail),
          ),
        )
      else
        _Section(id: 'details-loading', index: 3, child: const DetailsSkeleton()),
    ];

    return RefreshIndicator(
      color: KxColors.cyan,
      backgroundColor: KxColors.bgElevated,
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(KxLayout.gutter, 6, KxLayout.gutter, 32 + MediaQuery.paddingOf(context).bottom),
        child: ContentWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sections),
        ),
      ),
    );
  }
}

/// One page section with an optional [title], entering with a staggered
/// fade-and-rise.
///
/// Sections are keyed by `id` and live in a non-lazy Column, so each one
/// animates only the first time it appears, not on rebuilds.
class _Section extends StatelessWidget {
  _Section({required String id, required this.index, required this.child, this.title, this.gap = KxLayout.sectionGap})
    : super(key: ValueKey('section-$id'));

  final int index;
  final Widget child;
  final String? title;

  /// Space below the section.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Entrance(
        index: index,
        stagger: const Duration(milliseconds: 90),
        duration: const Duration(milliseconds: 500),
        child: title == null
            ? child
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [SectionHeader(title), child]),
      ),
    );
  }
}
