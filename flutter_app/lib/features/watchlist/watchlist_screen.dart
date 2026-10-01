import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/data/api_service.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/features/coin_detail/open_coin.dart';
import 'package:kryptox/features/watchlist/watchlist_sort.dart';
import 'package:kryptox/features/watchlist/widgets/swipe_to_remove.dart';
import 'package:kryptox/features/watchlist/widgets/watchlist_sort_bar.dart';
import 'package:kryptox/features/watchlist/widgets/watchlist_summary_card.dart';
import 'package:kryptox/shared/shared.dart';
import 'package:kryptox/state/loadable.dart';
import 'package:kryptox/state/visible_polling.dart';
import 'package:kryptox/state/watchlist_provider.dart';

const _heroPrefix = 'watch';

/// Lifts centred full-area states (error, empty) above the floating nav bar.
const _centredStateInset = EdgeInsets.only(bottom: KxLayout.stateViewBottomInset);

/// Entrance id of the summary card, alongside the coin ids of the rows.
const _summaryRevealId = '__summary__';

/// The Watchlist tab: a summary of the starred coins, a sort bar and the
/// coins themselves, which can be swiped away (with Undo).
///
/// Polls every 30 seconds while visible, and refetches as soon as it is
/// shown again when coins were starred while the tab was hidden.
class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key, required this.onBrowseMarkets});

  /// Called by the empty state's "Explore markets" action.
  final VoidCallback onBrowseMarkets;

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> with VisiblePolling<WatchlistScreen> {
  final _coins = Loadable<List<Coin>>();
  late final WatchlistProvider _watchlist;
  Set<String> _loadedIds = {};
  DateTime? _lastFetch;

  /// The watchlist gained coins while this tab was hidden; refetch when shown.
  bool _stale = false;
  WatchlistSort _sort = WatchlistSort.none;

  /// Ids (rows and summary) that already played their entrance animation, so
  /// rows don't re-animate when scrolled back into view or when data refreshes.
  final _revealed = <String>{};

  @override
  Duration get pollInterval => const Duration(seconds: 30);

  @override
  bool get isStale => _stale || isOlderThanPollInterval(_lastFetch);

  @override
  Future<void> onPoll() async {
    if (_coins.loading) return;
    await _reload();
  }

  @override
  void initState() {
    super.initState();
    _watchlist = context.read<WatchlistProvider>()..addListener(_onWatchlistChanged);
    _reload();
  }

  @override
  void dispose() {
    _watchlist.removeListener(_onWatchlistChanged);
    _coins.dispose();
    super.dispose();
  }

  Future<void> _reload() {
    _loadedIds = _watchlist.ids;
    _stale = false;
    _lastFetch = DateTime.now();
    return _coins.load(() => context.read<ApiService>().getWatchlist());
  }

  /// Retry from the full-screen error: the ids may have failed too.
  Future<void> _retry() async {
    if (_watchlist.error != null) await _watchlist.load();
    if (mounted) await _reload();
  }

  /// Removals are applied locally (instant); additions need fresh coin data,
  /// fetched now if visible or else as soon as the tab is shown.
  void _onWatchlistChanged() {
    if (!mounted) return;
    final hasNewCoins = !_loadedIds.containsAll(_watchlist.ids);
    if (hasNewCoins && isVisible) {
      _reload();
    } else {
      if (hasNewCoins) _stale = true;
      setState(() {});
    }
  }

  Future<void> _remove(Coin coin) async {
    HapticFeedback.mediumImpact();
    _revealed.remove(coin.id); // so an Undo animates the row back in
    final messenger = ScaffoldMessenger.of(context);
    final error = await _watchlist.toggle(coin.id);
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? '${coin.name} removed from watchlist'),
        action: error == null
            ? SnackBarAction(
                label: 'Undo',
                textColor: KxColors.cyan,
                onPressed: () async {
                  final undoError = await _watchlist.toggle(coin.id);
                  if (undoError != null) messenger.showSnackBar(SnackBar(content: Text(undoError)));
                },
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // No Scaffold of its own: the shell's Scaffold hosts the drawer (opened
    // from the header) and snack bars, which then float above the nav bar.
    return SafeArea(
      bottom: false,
      child: ContentWidth(
        child: ListenableBuilder(
          listenable: _coins,
          builder: (context, _) {
            final all = _coins.data;
            return Column(
              children: [
                KxPageHeader(
                  eyebrow: 'PORTFOLIO',
                  title: 'Watchlist',
                  actions: [HeaderStatus(source: _coins.source, updatedAt: _coins.updatedAt)],
                ),
                LoadingLine(visible: _coins.loading && all != null),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: KxSwitcher(
                          expand: true,
                          duration: const Duration(milliseconds: 300),
                          child: _buildBody(all),
                        ),
                      ),
                      if (all != null && _coins.error != null)
                        Positioned(
                          left: KxLayout.gutter,
                          right: KxLayout.gutter,
                          bottom: KxLayout.floatingBannerBottom(context),
                          child: RefreshErrorBanner(message: '${_coins.error}', onRetry: _reload),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Loading, error, empty or list state, each keyed for the [KxSwitcher].
  Widget _buildBody(List<Coin>? all) {
    if (all == null) {
      return _coins.error != null && !_coins.loading
          ? Padding(
              key: const ValueKey('error'),
              padding: _centredStateInset,
              child: ErrorView(message: '${_coins.error}', onRetry: _retry),
            )
          : const LoadingView(key: ValueKey('loading'), rows: 4);
    }
    final ids = _watchlist.ids;
    // If the id list itself failed to load, trust the server's list rather
    // than filtering everything away into a false "empty".
    final idsKnown = _watchlist.error == null || ids.isNotEmpty;
    final coins = _sort.apply(idsKnown ? all.where((c) => ids.contains(c.id)) : all);
    if (coins.isEmpty) {
      return Padding(
        key: const ValueKey('empty'),
        padding: _centredStateInset,
        child: EmptyView(
          icon: Icons.star_outline_rounded,
          title: 'Your watchlist is empty',
          subtitle: 'Tap the star next to any coin to track its price and 24h move here.',
          actionLabel: 'Explore markets',
          onAction: widget.onBrowseMarkets,
        ),
      );
    }
    return KeyedSubtree(key: const ValueKey('list'), child: _buildList(coins));
  }

  Widget _buildList(List<Coin> coins) {
    return RefreshIndicator(
      onRefresh: _reload,
      color: KxColors.cyan,
      backgroundColor: KxColors.bgElevated,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 6, bottom: KxLayout.navBarClearance + 10),
        itemCount: coins.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _reveal(
              id: _summaryRevealId,
              index: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(KxLayout.gutter, 0, KxLayout.gutter, 16),
                child: WatchlistSummaryCard(coins: coins),
              ),
            );
          }
          if (i == 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: WatchlistSortBar(selected: _sort, onSelected: (sort) => setState(() => _sort = sort)),
            );
          }
          final coin = coins[i - 2];
          return _reveal(
            id: coin.id,
            index: i - 1,
            child: SwipeToRemove(
              key: ValueKey('swipe-${coin.id}'),
              itemId: coin.id,
              itemName: coin.name,
              onRemove: () => _remove(coin),
              child: CoinTile(
                coin: coin,
                heroPrefix: _heroPrefix,
                onTap: () => openCoin(context, coin, heroPrefix: _heroPrefix),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Staggered entrance that plays only the first time [id] is built.
  Widget _reveal({required String id, required int index, required Widget child}) {
    return Entrance(
      key: ValueKey('reveal-$id'),
      index: index,
      play: _revealed.add(id),
      stagger: const Duration(milliseconds: 55),
      duration: const Duration(milliseconds: 380),
      offset: const Offset(0, 0.12),
      child: child,
    );
  }
}
