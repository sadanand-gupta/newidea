import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/data/api_service.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/features/stats/widgets/dominance_card.dart';
import 'package:kryptox/features/stats/widgets/kpi_grid.dart';
import 'package:kryptox/features/stats/widgets/market_cap_hero_card.dart';
import 'package:kryptox/features/stats/widgets/sentiment_card.dart';
import 'package:kryptox/features/stats/widgets/top_movers_card.dart';
import 'package:kryptox/shared/shared.dart';
import 'package:kryptox/state/loadable.dart';
import 'package:kryptox/state/visible_polling.dart';

/// "Global Market" tab: total market cap, key metrics, dominance, an
/// estimated sentiment gauge and the top movers. Refreshes every minute while
/// on screen.
class MarketStatsScreen extends StatefulWidget {
  const MarketStatsScreen({super.key});

  @override
  State<MarketStatsScreen> createState() => _MarketStatsScreenState();
}

class _MarketStatsScreenState extends State<MarketStatsScreen> with VisiblePolling<MarketStatsScreen> {
  /// Distance of the refresh-error banner from the bottom, above the nav bar.

  final _stats = Loadable<GlobalStats>();
  DateTime? _lastFetch;

  @override
  Duration get pollInterval => const Duration(seconds: 60);

  @override
  bool get isStale => isOlderThanPollInterval(_lastFetch);

  @override
  Future<void> onPoll() => _reload();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _stats.dispose();
    super.dispose();
  }

  Future<void> _reload() {
    final api = context.read<ApiService>();
    return _stats.load(() async {
      final result = await api.getGlobalStats();
      _lastFetch = DateTime.now();
      return result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: _stats,
        builder: (context, _) {
          final stats = _stats.data;
          final error = _stats.error;
          return Column(
            children: [
              ContentWidth(
                child: KxPageHeader(
                  eyebrow: 'OVERVIEW',
                  title: 'Global Market',
                  actions: [
                    HeaderStatus(source: _stats.source, updatedAt: _stats.updatedAt),
                    KxIconButton(
                      style: KxIconButtonStyle.plain,
                      icon: Icons.refresh_rounded,
                      tooltip: 'Refresh',
                      busy: _stats.loading,
                      onPressed: _reload,
                    ),
                  ],
                ),
              ),
              ContentWidth(child: LoadingLine(visible: _stats.loading && stats != null)),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: KxSwitcher(
                        expand: true,
                        duration: const Duration(milliseconds: 300),
                        child: switch ((stats, error)) {
                          (final GlobalStats stats, _) => KeyedSubtree(
                            key: const ValueKey('data'),
                            child: _Dashboard(stats: stats, onRefresh: _reload),
                          ),
                          (null, final Object error) => ContentWidth(
                            key: const ValueKey('error'),
                            padding: const EdgeInsets.only(bottom: KxLayout.stateViewBottomInset),
                            child: ErrorView(message: '$error', onRetry: _reload),
                          ),
                          (null, null) => const ContentWidth(key: ValueKey('loading'), child: LoadingView(rows: 6)),
                        },
                      ),
                    ),
                    if (stats != null && error != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: KxLayout.floatingBannerBottom(context),
                        child: ContentWidth(
                          padding: KxLayout.pagePadding,
                          child: RefreshErrorBanner(message: '$error', onRetry: _reload),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The loaded dashboard: pull-to-refresh scroll view of all sections, which
/// fade in one after another on the first load only.
class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.stats, required this.onRefresh});

  final GlobalStats stats;
  final Future<void> Function() onRefresh;

  /// Above this content width, dominance and sentiment sit side by side.
  static const _twoColumnBreakpoint = 720.0;

  static Widget _reveal(int index, Widget child) => Entrance(
    key: ValueKey('reveal-$index'),
    index: index,
    stagger: const Duration(milliseconds: 90),
    duration: const Duration(milliseconds: 500),
    child: child,
  );

  static Widget _pad(Widget child) => Padding(padding: KxLayout.pagePadding, child: child);

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: KxLayout.sectionGap);
    final dominance = stats.dominance.isEmpty
        ? null
        : _Section(
            title: 'Market-cap dominance',
            child: DominanceCard(dominance: stats.dominance),
          );
    final sentiment = _Section(
      title: 'Sentiment',
      trailing: const SentimentEstimateTag(),
      child: SentimentCard(stats: stats),
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: KxColors.cyan,
      backgroundColor: KxColors.bgElevated,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 6, bottom: KxLayout.navBarClearance + 10),
        child: ContentWidth(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn = constraints.maxWidth >= _twoColumnBreakpoint;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _reveal(0, _pad(MarketCapHeroCard(stats: stats))),
                  gap,
                  _reveal(
                    1,
                    _pad(
                      _Section(
                        title: 'Key metrics',
                        child: KpiGrid(stats: stats),
                      ),
                    ),
                  ),
                  gap,
                  if (twoColumn && dominance != null)
                    _reveal(
                      2,
                      _pad(
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: dominance),
                            const SizedBox(width: KxLayout.gutter),
                            Expanded(child: sentiment),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    if (dominance != null) ...[_reveal(2, _pad(dominance)), gap],
                    _reveal(3, _pad(sentiment)),
                  ],
                  gap,
                  _reveal(4, TopMoversCard(stats: stats)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A [SectionHeader] over its content.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title, trailing: trailing),
        child,
      ],
    );
  }
}
