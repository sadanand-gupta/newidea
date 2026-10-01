import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/core/utils/formatters.dart';
import 'package:kryptox/data/api_service.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/features/home/widgets/market_snapshot_card.dart';
import 'package:kryptox/features/home/widgets/shortcut_card.dart';
import 'package:kryptox/features/home/widgets/top_movers_section.dart';
import 'package:kryptox/features/home/widgets/watchlist_preview_section.dart';
import 'package:kryptox/features/shell/home_shell.dart';
import 'package:kryptox/shared/shared.dart';
import 'package:kryptox/state/loadable.dart';
import 'package:kryptox/state/visible_polling.dart';
import 'package:kryptox/state/watchlist_provider.dart';

/// First tab of the shell: a dashboard with the global market snapshot, the
/// day's top movers and a preview of the user's watchlist.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onNavigate});

  /// Switches the shell to another tab (see [ShellTab]).
  final ValueChanged<int> onNavigate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with VisiblePolling<HomeScreen> {
  final _stats = Loadable<GlobalStats>();
  final _watch = Loadable<List<Coin>>();
  late final _data = Listenable.merge([_stats, _watch]);
  late final WatchlistProvider _watchlist;
  late final ApiService _api;

  DateTime? _lastStatsFetch;
  DateTime? _lastWatchFetch;

  /// Ids the last watchlist fetch covered; an id outside it needs a refetch.
  Set<String> _loadedWatchIds = {};

  /// The watchlist changed while this tab was hidden; refetch when shown.
  bool _watchStale = false;

  /// Whether the WatchlistProvider has resolved its ids at least once, so an
  /// empty id set really means "empty" rather than "not loaded yet".
  bool _idsSettled = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _watchlist = context.read<WatchlistProvider>();
    _idsSettled = _watchlist.ids.isNotEmpty || _watchlist.error != null;
    _watchlist.addListener(_onWatchlistChanged);
    _loadStats();
    _loadWatchlist();
  }

  @override
  void dispose() {
    _watchlist.removeListener(_onWatchlistChanged);
    _stats.dispose();
    _watch.dispose();
    super.dispose();
  }

  // --- Data -------------------------------------------------------------------

  /// Slower than the Markets tab: this is an overview.
  @override
  Duration get pollInterval => const Duration(seconds: 60);

  @override
  Future<void> onPoll() =>
      Future.wait([if (!_stats.loading) _loadStats(), if (!_watch.loading && !_watchlistEmpty) _loadWatchlist()]);

  bool get _statsNeedRefresh => !_stats.loading && isOlderThanPollInterval(_lastStatsFetch);

  bool get _watchNeedsRefresh =>
      !_watch.loading && (_watchStale || (!_watchlistEmpty && isOlderThanPollInterval(_lastWatchFetch)));

  @override
  bool get isStale => _statsNeedRefresh || _watchNeedsRefresh;

  /// Refreshes each resource on its own staleness, not both at once.
  @override
  void onVisible() {
    if (_statsNeedRefresh) _loadStats();
    if (_watchNeedsRefresh) _loadWatchlist();
  }

  Future<void> _loadStats() {
    _lastStatsFetch = DateTime.now();
    return _stats.load(_api.getGlobalStats);
  }

  Future<void> _loadWatchlist() {
    final requested = _watchlist.ids;
    _watchStale = false;
    _lastWatchFetch = DateTime.now();
    return _watch.load(() async {
      final result = await _api.getWatchlist();
      _loadedWatchIds = {...requested, for (final c in result.data) c.id};
      return result;
    });
  }

  Future<void> _refreshAll() => Future.wait([_loadStats(), _loadWatchlist()]);

  Future<void> _retryWatchlist() async {
    if (_watchlist.error != null) await _watchlist.load();
    if (mounted) await _loadWatchlist();
  }

  bool get _watchlistEmpty => _idsSettled && _watchlist.error == null && _watchlist.ids.isEmpty;

  /// Removals are applied locally (instant); additions need fresh coin data.
  void _onWatchlistChanged() {
    if (!mounted) return;
    _idsSettled = true;
    if (!_loadedWatchIds.containsAll(_watchlist.ids)) {
      if (isVisible) {
        _loadWatchlist();
      } else {
        _watchStale = true;
      }
    }
    setState(() {});
  }

  /// Watchlist coins to show. Filtered by the provider's ids so a removal
  /// elsewhere disappears immediately, unless the ids themselves failed to load.
  List<Coin>? get _watchCoins {
    final data = _watch.data;
    if (data == null) return null;
    if (!_idsSettled || _watchlist.error != null) return data;
    final ids = _watchlist.ids;
    return data.where((c) => ids.contains(c.id)).toList();
  }

  static bool _failed(Loadable<Object> resource) => resource.error != null && !resource.loading;

  // --- UI ---------------------------------------------------------------------

  static String _greeting(int hour) => switch (hour) {
    >= 5 && < 12 => 'GOOD MORNING',
    >= 12 && < 17 => 'GOOD AFTERNOON',
    _ => 'GOOD EVENING',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refreshAll,
        color: KxColors.cyan,
        backgroundColor: KxColors.bgElevated,
        child: ListenableBuilder(
          listenable: _data,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final inset = ContentWidth.insetFor(constraints.maxWidth);
              final sections = _buildSections();
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(inset, 12, inset, KxLayout.navBarClearance),
                children: [
                  for (final (i, (id, section)) in sections.indexed)
                    Entrance(
                      key: ValueKey('home-$id'),
                      index: i,
                      stagger: const Duration(milliseconds: 60),
                      duration: const Duration(milliseconds: 360),
                      child: section,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// A fixed list of named slots: nothing is ever inserted, so the entrance
  /// animations don't replay when a section changes state.
  List<(String, Widget)> _buildSections() {
    final stats = _stats.data;
    return [
      (
        'header',
        KxPageHeader(
          eyebrow: _greeting(DateTime.now().hour),
          title: 'KryptoX',
          titleSize: 32,
          padding: const EdgeInsets.fromLTRB(KxLayout.gutter, 2, KxLayout.gutter, 18),
          actions: [SourceBadge(source: _stats.source)],
        ),
      ),
      (
        'stale',
        stats != null && _stats.error != null
            ? Padding(
                padding: KxLayout.pagePadding.copyWith(bottom: 12),
                child: RefreshErrorBanner(message: '${_stats.error}', onRetry: _refreshAll),
              )
            : const SizedBox.shrink(),
      ),
      ('snapshot', Padding(padding: KxLayout.pagePadding, child: _buildSnapshot(stats))),
      (
        'movers',
        TopMoversSection(stats: stats, failed: _failed(_stats), onSeeAll: () => widget.onNavigate(ShellTab.stats)),
      ),
      (
        'watchlist',
        WatchlistPreviewSection(
          coins: _watchCoins,
          error: _failed(_watch) ? '${_watch.error}' : null,
          onRetry: _retryWatchlist,
          onSeeAll: () => widget.onNavigate(ShellTab.watchlist),
          onExplore: () => widget.onNavigate(ShellTab.markets),
        ),
      ),
      (
        'explore',
        Padding(
          padding: KxLayout.pagePadding,
          child: ShortcutCard(
            icon: Icons.candlestick_chart_rounded,
            title: 'Explore all markets',
            subtitle: 'Search, filter and sort the top 100 coins',
            onTap: () => widget.onNavigate(ShellTab.markets),
          ),
        ),
      ),
      ('footer', _buildFooter()),
    ];
  }

  Widget _buildSnapshot(GlobalStats? stats) {
    final Widget child;
    if (stats != null) {
      child = MarketSnapshotCard(
        key: const ValueKey('snapshot'),
        stats: stats,
        onTap: () => widget.onNavigate(ShellTab.stats),
      );
    } else if (_failed(_stats)) {
      child = InlineError(
        key: const ValueKey('snapshot-error'),
        title: 'Market data unavailable',
        message: '${_stats.error}',
        onRetry: _loadStats,
      );
    } else {
      child = const MarketSnapshotSkeleton(key: ValueKey('snapshot-loading'));
    }
    return KxSwitcher(child: child);
  }

  Widget _buildFooter() {
    final updated = _stats.updatedAt;
    return Padding(
      padding: KxLayout.pagePadding.copyWith(top: 20),
      child: Text(
        updated == null ? 'Market data by CoinGecko' : 'Market data by CoinGecko · Updated ${formatTime(updated)}',
        textAlign: TextAlign.center,
        style: KxText.body(11, color: KxColors.textMuted),
      ),
    );
  }
}
