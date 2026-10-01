import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/data/api_service.dart';
import 'package:kryptox/data/models/coin.dart';
import 'package:kryptox/features/coin_detail/open_coin.dart';
import 'package:kryptox/features/markets/market_highlights.dart';
import 'package:kryptox/features/markets/widgets/markets_empty_view.dart';
import 'package:kryptox/features/markets/widgets/markets_filter_bar.dart';
import 'package:kryptox/features/markets/widgets/markets_header.dart';
import 'package:kryptox/features/markets/widgets/sort_sheet.dart';
import 'package:kryptox/features/markets/widgets/trending_section.dart';
import 'package:kryptox/shared/shared.dart';
import 'package:kryptox/state/loadable.dart';
import 'package:kryptox/state/visible_polling.dart';

const String _kListHero = 'mkt';

/// How long after a new result list (query/filter/sort) rows may still start
/// their entrance animation, e.g. when scrolled into view.
const Duration _kEntranceWindow = Duration(milliseconds: 1200);

/// Markets tab: live coin list with search, filters, sorting, a price tape
/// and a trending carousel. Auto-refreshes every 30s while visible.
class CoinListScreen extends StatefulWidget {
  const CoinListScreen({super.key});

  @override
  State<CoinListScreen> createState() => _CoinListScreenState();
}

class _CoinListScreenState extends State<CoinListScreen> with VisiblePolling<CoinListScreen> {
  final _coins = Loadable<List<Coin>>();
  final _searchController = TextEditingController();

  /// Remembers which query produced each result list, so the entrance
  /// animation replays only when the list identity (query/filter/sort)
  /// changes, not on every background refresh.
  final _paramsOf = Expando<String>('coinListParams');

  Timer? _debounce;

  CoinFilter _filter = CoinFilter.all;
  CoinSort _sort = CoinSort.marketCap;
  bool _descending = true;

  /// Tape and trending picks from the latest unfiltered market list.
  MarketHighlights _highlights = MarketHighlights.empty;

  String? _animatedKey;
  DateTime _animateUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// id -> index for the current list, so findChildIndexCallback is O(1)
  /// instead of a linear scan per row on every refresh.
  List<Coin>? _indexedList;
  Map<String, int> _indexOf = const {};

  String get _query => _searchController.text.trim();

  @override
  Duration get pollInterval => const Duration(seconds: 30);

  @override
  bool get isStale => isOlderThanPollInterval(_coins.updatedAt);

  @override
  Future<void> onPoll() async {
    // Don't race a user-initiated load or a pending search.
    if (_coins.loading || (_debounce?.isActive ?? false)) return;
    await _reload();
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _coins.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  Future<void> _reload() {
    final api = context.read<ApiService>();
    final search = _query;
    final filter = _filter;
    final sort = _sort;
    final descending = _descending;
    final params = '$search|${filter.name}|${sort.name}|$descending';
    return _coins.load(() async {
      final result = await api.getCoins(search: search, filter: filter, sort: sort, descending: descending);
      // Runs before Loadable publishes the data, so the next build sees it.
      _paramsOf[result.data] = params;
      if (search.isEmpty && filter == CoinFilter.all) _highlights = MarketHighlights.from(result.data);
      return result;
    });
  }

  void _onSearchChanged(String _) {
    setState(() {}); // trending visibility depends on the query
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _reload();
    });
  }

  void _onFilterSelected(CoinFilter f) {
    if (f == _filter) return;
    setState(() => _filter = f);
    _reload();
  }

  void _clearAll() {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _filter = CoinFilter.all);
    _reload();
  }

  Future<void> _pullToRefresh() {
    HapticFeedback.mediumImpact();
    return _reload();
  }

  void _openSortSheet() {
    showSortSheet(
      context,
      sort: _sort,
      descending: _descending,
      onChanged: (sort, descending) {
        setState(() {
          _sort = sort;
          _descending = descending;
        });
        _reload();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bottomClearance = KxLayout.bottomClearance(context);

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) => ListenableBuilder(
          listenable: _coins,
          builder: (context, _) {
            final width = constraints.maxWidth;
            final inset = ContentWidth.insetFor(width);
            final coins = _coins.data;
            final tape = _highlights.tape;
            final trending = _highlights.trending;
            final showTrending = _query.isEmpty && _filter == CoinFilter.all && trending.isNotEmpty;

            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _pullToRefresh,
                  color: KxColors.cyan,
                  backgroundColor: KxColors.bgElevated,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverToBoxAdapter(
                        key: const ValueKey('header'),
                        child: ContentWidth(
                          child: MarketsHeader(
                            source: _coins.source,
                            updatedAt: _coins.updatedAt,
                            loading: _coins.loading,
                            sort: _sort,
                            descending: _descending,
                            showRefreshButton: width >= KxLayout.wideBreakpoint,
                            onRefresh: _reload,
                            onSortPressed: _openSortSheet,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        key: const ValueKey('tape'),
                        child: KxSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: tape.isEmpty
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  key: const ValueKey('tape-on'),
                                  padding: const EdgeInsets.only(top: 14),
                                  child: TickerTape(coins: tape),
                                ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        key: const ValueKey('trending'),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: showTrending
                              ? ContentWidth(
                                  child: TrendingSection(coins: trending, clip: inset > 0),
                                )
                              : const SizedBox(width: double.infinity, height: 6),
                        ),
                      ),
                      SliverPersistentHeader(
                        key: const ValueKey('filters'),
                        pinned: true,
                        delegate: MarketsFilterBarDelegate(
                          textScaler: MediaQuery.textScalerOf(context),
                          loading: _coins.loading && coins != null,
                          search: KxSearchField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            hint: 'Search name or symbol',
                          ),
                          filters: KxChipBar<CoinFilter>(
                            options: CoinFilter.values,
                            selected: _filter,
                            labelOf: (f) => f.label,
                            onSelected: _onFilterSelected,
                          ),
                        ),
                      ),
                      ..._buildBody(coins),
                      SliverToBoxAdapter(
                        key: const ValueKey('bottom'),
                        child: SizedBox(height: bottomClearance),
                      ),
                    ],
                  ),
                ),
                if (_coins.error != null && coins != null)
                  Positioned(
                    left: KxLayout.gutter + inset,
                    right: KxLayout.gutter + inset,
                    bottom: KxLayout.floatingBannerBottom(context),
                    child: RefreshErrorBanner(message: '${_coins.error}', onRetry: _reload),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildBody(List<Coin>? coins) {
    if (coins == null) {
      if (_coins.error != null) {
        return [
          SliverToBoxAdapter(
            key: const ValueKey('error'),
            child: ContentWidth(
              child: SizedBox(
                height: 440,
                child: ErrorView(message: '${_coins.error}', onRetry: _reload),
              ),
            ),
          ),
        ];
      }
      return const [
        SliverToBoxAdapter(
          key: ValueKey('loading'),
          child: ContentWidth(
            child: Column(
              children: [
                CoinTileHeader(),
                // Same card shape/radius as CoinTile, so nothing jumps when data lands.
                SizedBox(height: 560, child: LoadingView(rows: 8)),
              ],
            ),
          ),
        ),
      ];
    }

    if (coins.isEmpty) {
      return [
        SliverToBoxAdapter(
          key: const ValueKey('empty'),
          child: ContentWidth(
            child: SizedBox(
              height: 420,
              child: MarketsEmptyView(query: _query, filter: _filter, onClear: _clearAll),
            ),
          ),
        ),
      ];
    }

    if (!identical(coins, _indexedList)) {
      _indexedList = coins;
      _indexOf = {for (var i = 0; i < coins.length; i++) coins[i].id: i};
    }
    final indexOf = _indexOf;

    // Replay the staggered entrance only when the list identity changes.
    final listKey = _paramsOf[coins] ?? '';
    if (listKey != _animatedKey) {
      _animatedKey = listKey;
      _animateUntil = DateTime.now().add(_kEntranceWindow);
    }
    final animate = DateTime.now().isBefore(_animateUntil);

    return [
      const SliverToBoxAdapter(
        key: ValueKey('columns'),
        child: ContentWidth(child: CoinTileHeader()),
      ),
      SliverContentWidth(
        key: const ValueKey('list'),
        sliver: SliverList.builder(
          itemCount: coins.length,
          findChildIndexCallback: (key) {
            if (key is! ValueKey<String> || !key.value.startsWith('$listKey#')) return null;
            return indexOf[key.value.substring(listKey.length + 1)];
          },
          itemBuilder: (context, i) {
            final coin = coins[i];
            return Entrance(
              key: ValueKey<String>('$listKey#${coin.id}'),
              play: animate,
              index: i,
              stagger: const Duration(milliseconds: 40),
              maxStaggered: 12,
              offset: const Offset(0.08, 0),
              child: CoinTile(
                coin: coin,
                heroPrefix: _kListHero,
                onTap: () => openCoin(context, coin, heroPrefix: _kListHero),
              ),
            );
          },
        ),
      ),
    ];
  }
}
