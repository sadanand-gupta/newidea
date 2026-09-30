import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/coin.dart';
import '../services/api_service.dart';
import '../state/loadable.dart';
import '../state/watchlist_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/coin_tile.dart';
import '../widgets/controls.dart';
import '../widgets/formatters.dart';
import '../widgets/glass.dart';
import '../widgets/market_widgets.dart';
import '../widgets/state_views.dart';
import 'home_shell.dart';
import 'navigation.dart';

/// Refresh cadence of the dashboard. Slower than the Markets tab: this is an
/// overview, and it only polls while it is the visible tab.
const _refreshEvery = Duration(seconds: 60);

/// Content never gets wider than this on desktop / web.
const _maxContentWidth = 760.0;

const _moversPreview = 5;
const _watchlistPreview = 4;

enum _Movers { gainers, losers }

/// First tab of the shell: a dashboard with the global market snapshot, the
/// day's top movers and a preview of the user's watchlist.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onNavigate});

  /// Switches the shell to another tab (see [ShellTab]).
  final ValueChanged<int> onNavigate;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _stats = Loadable<GlobalStats>();
  final _watch = Loadable<List<Coin>>();
  late final WatchlistProvider _watchlist;
  late final ApiService _api;

  Timer? _timer;
  Listenable? _tickerMode;
  DateTime? _lastStatsFetch;
  DateTime? _lastWatchFetch;

  /// Ids the last watchlist fetch covered; an id outside it needs a refetch.
  Set<String> _loadedWatchIds = {};

  /// The watchlist changed while this tab was hidden; refetch when shown.
  bool _watchStale = false;

  /// Whether the WatchlistProvider has resolved its ids at least once, so an
  /// empty id set really means "empty" rather than "not loaded yet".
  bool _idsSettled = false;

  _Movers _movers = _Movers.gainers;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiService>();
    _watchlist = context.read<WatchlistProvider>();
    _idsSettled = _watchlist.ids.isNotEmpty || _watchlist.error != null;
    _watchlist.addListener(_onWatchlistChanged);
    _loadStats();
    _loadWatchlist();
    _timer = Timer.periodic(_refreshEvery, (_) => _onTick());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hidden IndexedStack tabs (and pages covered by a route) run with
    // TickerMode off; refresh stale data the moment this tab is shown again.
    final notifier = TickerMode.getValuesNotifier(context);
    if (!identical(notifier, _tickerMode)) {
      _tickerMode?.removeListener(_onVisibilityChanged);
      _tickerMode = notifier..addListener(_onVisibilityChanged);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tickerMode?.removeListener(_onVisibilityChanged);
    _watchlist.removeListener(_onWatchlistChanged);
    _stats.dispose();
    _watch.dispose();
    super.dispose();
  }

  // --- Data -------------------------------------------------------------------

  bool get _visible {
    if (!mounted || !TickerMode.getValuesNotifier(context).value.enabled) return false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  static bool _isStale(DateTime? last) => last == null || DateTime.now().difference(last) >= _refreshEvery;

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

  bool get _watchlistEmpty => _idsSettled && _watchlist.error == null && _watchlist.ids.isEmpty;

  void _onTick() {
    if (!_visible) return;
    if (!_stats.loading) _loadStats();
    if (!_watch.loading && !_watchlistEmpty) _loadWatchlist();
  }

  void _onVisibilityChanged() {
    if (!_visible) return;
    if (!_stats.loading && _isStale(_lastStatsFetch)) _loadStats();
    if (!_watch.loading && (_watchStale || (!_watchlistEmpty && _isStale(_lastWatchFetch)))) _loadWatchlist();
  }

  /// Removals are applied locally (instant); additions need fresh coin data.
  void _onWatchlistChanged() {
    if (!mounted) return;
    _idsSettled = true;
    if (!_loadedWatchIds.containsAll(_watchlist.ids)) {
      if (_visible) {
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

  // --- UI ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refreshAll,
        color: KxColors.cyan,
        backgroundColor: KxColors.bgElevated,
        child: ListenableBuilder(
          listenable: Listenable.merge([_stats, _watch]),
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final side = math.max(0.0, (constraints.maxWidth - _maxContentWidth) / 2);
              // A fixed list of named slots: nothing is ever inserted, so the
              // entrance animations don't replay when a section changes state.
              final sections = <(String, Widget)>[
                ('header', _pad(_buildHeader())),
                (
                  'stale',
                  _stats.hasData && _stats.error != null
                      ? _pad(Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: RefreshErrorBanner(message: '${_stats.error}', onRetry: _refreshAll),
                        ))
                      : const SizedBox.shrink(),
                ),
                ('snapshot', _pad(_buildSnapshot())),
                ('movers', _buildMovers()),
                ('watchlist', _buildWatchlist()),
                (
                  'explore',
                  _pad(_ShortcutCard(
                    icon: Icons.candlestick_chart_rounded,
                    title: 'Explore all markets',
                    subtitle: 'Search, filter and sort the top 100 coins',
                    onTap: () => widget.onNavigate(ShellTab.markets),
                  )),
                ),
                ('footer', _pad(_buildFooter())),
              ];
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(side, 12, side, kNavBarClearance),
                children: [
                  for (final (i, (id, section)) in sections.indexed)
                    reduceMotion
                        ? KeyedSubtree(key: ValueKey('home-$id'), child: section)
                        : section
                            .animate(key: ValueKey('home-$id'), delay: (60 * i).ms)
                            .fadeIn(duration: 360.ms)
                            .moveY(begin: 10, end: 0, duration: 360.ms, curve: Curves.easeOutCubic),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static Widget _pad(Widget child) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour >= 5 && hour < 12
        ? 'GOOD MORNING'
        : hour >= 12 && hour < 17
            ? 'GOOD AFTERNOON'
            : 'GOOD EVENING';
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 18),
      child: Row(
        children: [
          Builder(
            builder: (context) => _GlassIconButton(
              icon: Icons.menu_rounded,
              tooltip: 'Open menu',
              onTap: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KxText.label(11, color: KxColors.cyan).copyWith(letterSpacing: 2.4),
                ),
                const SizedBox(height: 2),
                Semantics(
                  header: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: GradientText('KryptoX', style: KxText.display(32).copyWith(letterSpacing: -1)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SourceBadge(source: _stats.source),
        ],
      ),
    );
  }

  Widget _buildSnapshot() {
    final stats = _stats.data;
    final Widget child;
    if (stats != null) {
      child = _MarketSnapshotCard(
        key: const ValueKey('snapshot'),
        stats: stats,
        onTap: () => widget.onNavigate(ShellTab.stats),
      );
    } else if (_stats.error != null && !_stats.loading) {
      child = _InlineError(
        key: const ValueKey('snapshot-error'),
        title: 'Market data unavailable',
        message: '${_stats.error}',
        onRetry: _loadStats,
      );
    } else {
      child = const _SnapshotSkeleton(key: ValueKey('snapshot-loading'));
    }
    return _Switcher(child: child);
  }

  Widget _buildMovers() {
    final stats = _stats.data;
    final Widget body;
    if (stats != null) {
      final coins = (_movers == _Movers.gainers ? stats.topGainers : stats.topLosers).take(_moversPreview).toList();
      body = coins.isEmpty
          ? _pad(_MutedNote(
              key: ValueKey('movers-empty-$_movers'),
              text: 'No mover data available right now.',
            ))
          : Column(
              key: ValueKey('movers-$_movers'),
              children: [
                for (final coin in coins)
                  CoinTile(
                    coin: coin,
                    heroPrefix: 'home-movers',
                    showSparkline: false,
                    onTap: () => openCoin(context, coin, heroPrefix: 'home-movers'),
                  ),
              ],
            );
    } else if (_stats.error != null && !_stats.loading) {
      body = _pad(const _MutedNote(
        key: ValueKey('movers-error'),
        text: 'Top movers will appear once market data loads.',
      ));
    } else {
      body = const _SkeletonTiles(key: ValueKey('movers-loading'), count: 3);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pad(_SectionTitle(
          'Top movers · 24h',
          trailing: _SeeAllButton(
            semanticLabel: 'See all market stats',
            onTap: () => widget.onNavigate(ShellTab.stats),
          ),
        )),
        _pad(Semantics(
          label: 'Show top gainers or top losers',
          child: KxSegmented<_Movers>(
            options: _Movers.values,
            selected: _movers,
            labelOf: (m) => m == _Movers.gainers ? 'GAINERS' : 'LOSERS',
            onSelected: (m) => setState(() => _movers = m),
          ),
        )),
        const SizedBox(height: 8),
        _Switcher(child: body),
      ],
    );
  }

  Widget _buildWatchlist() {
    final coins = _watchCoins;
    final count = coins?.length ?? 0;
    final Widget body;
    if (coins == null) {
      body = _watch.error != null && !_watch.loading
          ? _pad(_InlineError(
              key: const ValueKey('watch-error'),
              title: 'Watchlist unavailable',
              message: '${_watch.error}',
              onRetry: () async {
                if (_watchlist.error != null) await _watchlist.load();
                if (mounted) await _loadWatchlist();
              },
            ))
          : const _SkeletonTiles(key: ValueKey('watch-loading'), count: 2);
    } else if (coins.isEmpty) {
      body = _pad(_EmptyWatchlistCard(
        key: const ValueKey('watch-empty'),
        onExplore: () => widget.onNavigate(ShellTab.markets),
      ));
    } else {
      body = Column(
        key: const ValueKey('watch-list'),
        children: [
          for (final coin in coins.take(_watchlistPreview))
            CoinTile(
              coin: coin,
              heroPrefix: 'home-watch',
              showSparkline: false,
              onTap: () => openCoin(context, coin, heroPrefix: 'home-watch'),
            ),
          if (count > _watchlistPreview)
            _pad(Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _MutedNote(
                text: '+${count - _watchlistPreview} more in your watchlist',
                onTap: () => widget.onNavigate(ShellTab.watchlist),
              ),
            )),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pad(_SectionTitle(
          count > 0 ? 'Your watchlist · $count' : 'Your watchlist',
          trailing: count > 0
              ? _SeeAllButton(
                  semanticLabel: 'See your full watchlist',
                  onTap: () => widget.onNavigate(ShellTab.watchlist),
                )
              : null,
        )),
        _Switcher(child: body),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFooter() {
    final updated = _stats.updatedAt;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Text(
        updated == null ? 'Market data by CoinGecko' : 'Market data by CoinGecko · Updated ${formatTime(updated)}',
        textAlign: TextAlign.center,
        style: KxText.body(11, color: KxColors.textMuted),
      ),
    );
  }
}

// --- Building blocks -----------------------------------------------------------

/// Cross-fades between loading / error / data states of a section.
class _Switcher extends StatelessWidget {
  const _Switcher({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        fit: StackFit.passthrough,
        children: [...previous, if (current != null) current],
      ),
      child: child,
    );
  }
}

/// Same look as [SectionHeader], but the title shrinks (ellipsis) instead of
/// overflowing on narrow screens with large text.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(gradient: KxColors.brandGradient, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KxText.label(12),
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// 44×44 frosted icon button (menu).
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: GlassCard(
          radius: 14,
          padding: const EdgeInsets.all(12),
          onTap: onTap,
          child: Icon(icon, size: 20, color: KxColors.text),
        ),
      ),
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.onTap, required this.semanticLabel});

  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          foregroundColor: KxColors.cyan,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('See all', style: KxText.body(13, weight: FontWeight.w600, color: KxColors.cyan)),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded, size: 18, color: KxColors.cyan),
          ],
        ),
      ),
    );
  }
}

class _MarketSnapshotCard extends StatelessWidget {
  const _MarketSnapshotCard({super.key, required this.stats, required this.onTap});

  final GlobalStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final change = stats.marketCapChange24h;
    final btc = stats.dominance['BTC'];
    return MergeSemantics(
      child: Semantics(
        button: true,
        hint: 'Opens market stats',
        child: GlassCard(
          onTap: onTap,
          radius: 22,
          glow: KxColors.change(change),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              KxColors.cyan.withValues(alpha: 0.12),
              KxColors.violet.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'GLOBAL MARKET CAP',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KxText.label(11),
                    ),
                  ),
                  const Icon(Icons.arrow_outward_rounded, size: 18, color: KxColors.textMuted),
                ],
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedPrice(
                  value: stats.totalMarketCap,
                  compact: true,
                  style: KxText.mono(34, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChangePill(change, size: 12),
                  Text('in the last 24h', style: KxText.body(12, color: KxColors.textDim)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _MiniStat(label: '24H VOLUME', value: formatCompact(stats.totalVolume))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStat(
                      label: 'BTC DOMINANCE',
                      value: btc == null ? '—' : '${btc.toStringAsFixed(1)}%',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _MiniStat(label: 'COINS', value: formatNumber(stats.activeCryptocurrencies))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, maxLines: 2, style: KxText.label(10, color: KxColors.textMuted)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: KxText.mono(15, weight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GlassCard(
          radius: 18,
          padding: const EdgeInsets.all(14),
          onTap: onTap,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [KxColors.violet.withValues(alpha: 0.12), KxColors.cyan.withValues(alpha: 0.06)],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: KxColors.brandGradient),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.black, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: KxText.body(15, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: KxText.body(12, color: KxColors.textDim)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: KxColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyWatchlistCard extends StatelessWidget {
  const _EmptyWatchlistCard({super.key, required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: KxColors.warn.withValues(alpha: 0.1),
              border: Border.all(color: KxColors.warn.withValues(alpha: 0.3)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.star_outline_rounded, color: KxColors.warn, size: 26),
          ),
          const SizedBox(height: 12),
          Text('Track the coins you care about',
              textAlign: TextAlign.center, style: KxText.body(15, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Tap the star on any coin and it will show up here with its live price and 24h move.',
            textAlign: TextAlign.center,
            style: KxText.body(13, color: KxColors.textDim),
          ),
          const SizedBox(height: 16),
          // GradientButton's label can't wrap; scale it down rather than overflow
          // on very narrow screens with large text.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: GradientButton(label: 'Explore markets', icon: Icons.search_rounded, onPressed: onExplore),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact in-card error with a retry, for one dashboard section.
class _InlineError extends StatelessWidget {
  const _InlineError({super.key, required this.title, required this.message, required this.onRetry});

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 18,
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
                const SizedBox(height: 2),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: KxText.body(12, color: KxColors.textDim),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: KxColors.cyan),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _MutedNote extends StatelessWidget {
  const _MutedNote({super.key, required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      textAlign: TextAlign.center,
      style: KxText.body(13, weight: onTap == null ? FontWeight.w400 : FontWeight.w600,
          color: onTap == null ? KxColors.textMuted : KxColors.cyan),
    );
    if (onTap == null) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: label);
    }
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
      child: label,
    );
  }
}

// --- Skeletons -----------------------------------------------------------------

Widget _shimmer(BuildContext context, Widget child, {int index = 0}) {
  if (MediaQuery.of(context).disableAnimations) return child;
  return child
      .animate(onPlay: (c) => c.repeat())
      .shimmer(duration: 1400.ms, delay: (index * 80).ms, color: KxColors.cyan.withValues(alpha: 0.12));
}

class _SnapshotSkeleton extends StatelessWidget {
  const _SnapshotSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading market data',
      child: ExcludeSemantics(
        child: _shimmer(
          context,
          GlassCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingView.bar(120, 10),
                const SizedBox(height: 12),
                LoadingView.bar(180, 30),
                const SizedBox(height: 10),
                LoadingView.bar(90, 18),
                const SizedBox(height: 20),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [LoadingView.bar(60, 9), const SizedBox(height: 8), LoadingView.bar(70, 14)],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder rows shaped like [CoinTile] (sized to fit inside a scroll view,
/// unlike LoadingView which is itself a list).
class _SkeletonTiles extends StatelessWidget {
  const _SkeletonTiles({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _shimmer(
                  context,
                  index: i,
                  GlassCard(
                    radius: 18,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [LoadingView.bar(60, 12), const SizedBox(height: 6), LoadingView.bar(90, 10)],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [LoadingView.bar(70, 12), const SizedBox(height: 6), LoadingView.bar(46, 10)],
                        ),
                      ],
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
