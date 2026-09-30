import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/coin.dart';
import '../services/api_service.dart';
import '../state/loadable.dart';
import '../theme/app_theme.dart';
import '../widgets/coin_tile.dart';
import '../widgets/controls.dart';
import '../widgets/formatters.dart';
import '../widgets/glass.dart';
import '../widgets/market_widgets.dart';
import '../widgets/state_views.dart';
import 'navigation.dart';

/// Space kept free at the bottom so content clears the floating nav bar.
const double _kBottomClearance = 110;
const Duration _kAutoRefresh = Duration(seconds: 30);
const Duration _kEntranceWindow = Duration(milliseconds: 1200);
const String _kListHero = 'mkt';
const String _kTrendHero = 'trend';

/// Readable column width on tablets/desktop/web; phones use the full width.
const double _kMaxContentWidth = 820;

/// Width above which a pointer-friendly refresh button is shown (mouse users
/// can't pull-to-refresh).
const double _kShowRefreshButtonWidth = 600;

/// Centers [child] and caps it at [_kMaxContentWidth].
Widget _readable(Widget child) => Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
    child: child,
  ),
);

/// Markets home: live coin list with search, filters, sorting, a price tape
/// and a trending carousel. Auto-refreshes every 30s while visible.
class CoinListScreen extends StatefulWidget {
  const CoinListScreen({super.key});

  @override
  State<CoinListScreen> createState() => _CoinListScreenState();
}

class _CoinListScreenState extends State<CoinListScreen> with WidgetsBindingObserver {
  final _coins = Loadable<List<Coin>>();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  /// Remembers which query produced each result list, so the entrance
  /// animation replays only when the list identity (query/filter/sort)
  /// changes, not on every background refresh.
  final _paramsOf = Expando<String>('coinListParams');

  Timer? _debounce;
  Timer? _autoRefresh;
  DateTime? _lastFetch;

  CoinFilter _filter = CoinFilter.all;
  CoinSort _sort = CoinSort.marketCap;
  bool _descending = true;

  /// Latest unfiltered market list, used for the ticker tape and trending.
  List<Coin>? _snapshot;
  List<Coin>? _derivedFrom;
  List<Coin> _tape = const [];
  List<Coin> _trending = const [];

  String? _animatedKey;
  DateTime _animateUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// id -> index for the current list, so findChildIndexCallback is O(1)
  /// instead of a linear scan per row on every refresh.
  List<Coin>? _indexedList;
  Map<String, int> _indexOf = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _autoRefresh?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _coins.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  Future<void> _reload() {
    final api = context.read<ApiService>();
    final search = _searchController.text.trim();
    final filter = _filter;
    final sort = _sort;
    final descending = _descending;
    final params = '$search|${filter.name}|${sort.name}|$descending';
    return _coins.load(() async {
      final result = await api.getCoins(search: search, filter: filter, sort: sort, descending: descending);
      // Runs before Loadable publishes the data, so the next build sees it.
      _paramsOf[result.data] = params;
      if (search.isEmpty && filter == CoinFilter.all) _snapshot = result.data;
      _lastFetch = DateTime.now();
      return result;
    });
  }

  void _startAutoRefresh() {
    _autoRefresh?.cancel();
    _autoRefresh = Timer.periodic(_kAutoRefresh, (_) => _onAutoRefresh());
  }

  void _stopAutoRefresh() {
    _autoRefresh?.cancel();
    _autoRefresh = null;
  }

  void _onAutoRefresh() {
    if (!mounted || _coins.loading || (_debounce?.isActive ?? false)) return;
    // Skip while this tab is hidden (IndexedStack) or covered by another route.
    if (!TickerMode.getValuesNotifier(context).value.enabled) return;
    _reload();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startAutoRefresh();
      final last = _lastFetch;
      if (last == null || DateTime.now().difference(last) >= _kAutoRefresh) {
        if (!_coins.loading) _reload();
      }
    } else if (state != AppLifecycleState.inactive) {
      // paused / hidden / detached: no point polling in the background.
      _stopAutoRefresh();
    }
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

  /// Ticker tape (top 15 by rank) and trending (top 5 by |24h change|),
  /// derived client-side from the latest unfiltered list.
  void _deriveFromSnapshot() {
    final src = _snapshot;
    if (identical(src, _derivedFrom)) return;
    _derivedFrom = src;
    if (src == null || src.isEmpty) {
      _tape = const [];
      _trending = const [];
      return;
    }
    const noRank = 1 << 30;
    final byRank = [...src]..sort((a, b) => (a.rank ?? noRank).compareTo(b.rank ?? noRank));
    _tape = byRank.take(15).toList();
    final movers = src.where((c) => c.change24h != null).toList()
      ..sort((a, b) => b.change24h!.abs().compareTo(a.change24h!.abs()));
    _trending = movers.take(5).toList();
  }

  // ---------------------------------------------------------------------------
  // Sort sheet
  // ---------------------------------------------------------------------------

  Future<void> _showSortSheet() async {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void apply(VoidCallback change) {
            HapticFeedback.selectionClick();
            setState(change);
            setSheetState(() {});
            _reload();
          }

          return _SortSheet(
            sort: _sort,
            descending: _descending,
            onSort: (s) {
              if (s != _sort) apply(() => _sort = s);
            },
            onDirection: (d) {
              if (d != _descending) apply(() => _descending = d);
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Inside HomeShell (extendBody) the bottom padding equals the nav bar height.
    final navPad = MediaQuery.paddingOf(context).bottom;
    final bottomClearance = math.max(_kBottomClearance, navPad + 20);
    final textScale = MediaQuery.textScalerOf(context).scale(15) / 15;
    final searchHeight = math.max(48.0, 28 + 15 * 1.25 * textScale);

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) => ListenableBuilder(
          listenable: _coins,
          builder: (context, _) {
            final width = constraints.maxWidth;
            final inset = math.max(0.0, (width - _kMaxContentWidth) / 2);
            final showRefreshButton = width >= _kShowRefreshButtonWidth;
            final coins = _coins.data;
            _deriveFromSnapshot();
            final showTrending =
                _searchController.text.trim().isEmpty && _filter == CoinFilter.all && _trending.isNotEmpty;

            return Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _pullToRefresh,
                  color: KxColors.cyan,
                  backgroundColor: KxColors.bgElevated,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverToBoxAdapter(
                        key: const ValueKey('header'),
                        child: _readable(_buildHeader(showRefreshButton: showRefreshButton)),
                      ),
                      SliverToBoxAdapter(
                        key: const ValueKey('tape'),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: _tape.isEmpty
                              ? const SizedBox(width: double.infinity)
                              : Padding(
                                  key: const ValueKey('tape-on'),
                                  padding: const EdgeInsets.only(top: 14),
                                  child: TickerTape(coins: _tape),
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
                              ? _readable(_TrendingSection(coins: _trending, clip: inset > 0))
                              : const SizedBox(width: double.infinity, height: 6),
                        ),
                      ),
                      SliverPersistentHeader(
                        key: const ValueKey('filters'),
                        pinned: true,
                        delegate: _FilterBarDelegate(
                          extent: 72 + searchHeight,
                          loading: _coins.loading && coins != null,
                          maxContentWidth: _kMaxContentWidth,
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
                      ..._buildBody(coins, inset),
                      SliverToBoxAdapter(
                        key: const ValueKey('bottom'),
                        child: SizedBox(height: bottomClearance),
                      ),
                    ],
                  ),
                ),
                if (_coins.error != null && coins != null)
                  Positioned(
                    left: 16 + inset,
                    right: 16 + inset,
                    bottom: navPad + 10,
                    child: RefreshErrorBanner(message: '${_coins.error}', onRetry: _reload),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader({required bool showRefreshButton}) {
    final isDefaultSort = _sort == CoinSort.marketCap && _descending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
          child: Row(
            children: [
              _GlassIconButton(
                icon: Icons.menu_rounded,
                tooltip: 'Menu',
                onTap: () => Scaffold.of(context).openDrawer(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MARKETS', style: KxText.label(11, color: KxColors.cyan).copyWith(letterSpacing: 2.4)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: GradientText('KryptoX', style: KxText.display(32).copyWith(letterSpacing: -1)),
                    ),
                  ],
                ),
              ),
              SourceBadge(source: _coins.source),
              if (showRefreshButton) ...[
                const SizedBox(width: 10),
                _GlassIconButton(
                  icon: Icons.refresh_rounded,
                  tooltip: _coins.loading ? 'Refreshing…' : 'Refresh prices',
                  busy: _coins.loading,
                  onTap: _coins.loading ? null : _reload,
                ),
              ],
              const SizedBox(width: 10),
              _GlassIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Sort markets',
                showDot: !isDefaultSort,
                onTap: _showSortSheet,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 12, 0),
          child: Row(
            children: [
              const ExcludeSemantics(child: Icon(Icons.schedule_rounded, size: 12, color: KxColors.textMuted)),
              const SizedBox(width: 5),
              _UpdatedAgo(time: _coins.updatedAt),
              ExcludeSemantics(
                child: Text('  ·  ', style: KxText.mono(11, color: KxColors.textMuted)),
              ),
              Flexible(
                child: Semantics(
                  button: true,
                  label:
                      'Sorted by ${_sort.label.toLowerCase()}, '
                      '${_descending ? 'descending' : 'ascending'}. Change sort order',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: _showSortSheet,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      // Vertical padding gives the small label a comfortable tap target.
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Sorted by ${_sort.label.toLowerCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KxText.body(11, weight: FontWeight.w500, color: KxColors.textDim),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            _descending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            size: 12,
                            color: KxColors.textDim,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.15, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  List<Widget> _buildBody(List<Coin>? coins, double inset) {
    if (coins == null) {
      if (_coins.error != null) {
        return [
          SliverToBoxAdapter(
            key: const ValueKey('error'),
            child: _readable(
              SizedBox(
                height: 440,
                child: ErrorView(message: '${_coins.error}', onRetry: _reload),
              ),
            ),
          ),
        ];
      }
      return [
        SliverToBoxAdapter(
          key: const ValueKey('loading'),
          child: _readable(
            const Column(
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
      final query = _searchController.text.trim();
      final filtered = _filter != CoinFilter.all;
      final String title;
      final String subtitle;
      final String actionLabel;
      if (query.isNotEmpty) {
        title = 'No results for “$query”';
        subtitle = filtered
            ? 'Nothing matches in “${_filter.label}”. Check the spelling or search all coins.'
            : 'Check the spelling, or try a coin name or ticker like “BTC”.';
        actionLabel = filtered ? 'Clear search & filter' : 'Clear search';
      } else {
        title = 'No coins in “${_filter.label}”';
        subtitle = 'Nothing matches this filter right now. Try another one.';
        actionLabel = 'Show all coins';
      }
      return [
        SliverToBoxAdapter(
          key: const ValueKey('empty'),
          child: _readable(
            SizedBox(
              height: 420,
              child: EmptyView(
                icon: Icons.search_off_rounded,
                title: title,
                subtitle: subtitle,
                actionLabel: actionLabel,
                onAction: _clearAll,
              ),
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
      SliverToBoxAdapter(key: const ValueKey('columns'), child: _readable(const CoinTileHeader())),
      SliverPadding(
        key: const ValueKey('list'),
        padding: EdgeInsets.symmetric(horizontal: inset),
        sliver: SliverList.builder(
          itemCount: coins.length,
          findChildIndexCallback: (key) {
            if (key is! ValueKey<String> || !key.value.startsWith('$listKey#')) return null;
            return indexOf[key.value.substring(listKey.length + 1)];
          },
          itemBuilder: (context, i) {
            final coin = coins[i];
            return _Entrance(
              key: ValueKey<String>('$listKey#${coin.id}'),
              play: animate,
              index: i,
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

// -----------------------------------------------------------------------------
// Pieces
// -----------------------------------------------------------------------------

/// Pinned search + filter chips; frosts over the list once content scrolls under.
class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  _FilterBarDelegate({
    required this.extent,
    required this.loading,
    required this.maxContentWidth,
    required this.search,
    required this.filters,
  });

  final double extent;
  final bool loading;

  /// The frosted backdrop spans the window; the controls stay readable width.
  final double maxContentWidth;
  final Widget search;
  final Widget filters;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final pinned = shrinkOffset > 0 || overlapsContent;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          opacity: pinned ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [KxColors.bg.withValues(alpha: 0.88), KxColors.bg.withValues(alpha: 0.62)],
                  ),
                  border: const Border(bottom: BorderSide(color: KxColors.border)),
                ),
              ),
            ),
          ),
        ),
        Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: search),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: filters,
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 2,
              child: AnimatedOpacity(
                opacity: loading ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: loading
                    ? LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        color: KxColors.cyan.withValues(alpha: 0.8),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_FilterBarDelegate oldDelegate) => true;
}

class _TrendingSection extends StatelessWidget {
  const _TrendingSection({required this.coins, this.clip = false});

  final List<Coin> coins;

  /// Clip the carousel at its own edges (needed when it's narrower than the
  /// window, otherwise pre-built cards would paint beyond the column).
  final bool clip;

  @override
  Widget build(BuildContext context) {
    // Card content grows with the text scale; give the carousel room for it.
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final height = 164 + math.max(0.0, textScale - 1) * 48;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SectionHeader(
            'Trending',
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded, size: 14, color: KxColors.warn),
                const SizedBox(width: 4),
                Text(
                  'Top 24h movers',
                  style: KxText.body(11, weight: FontWeight.w500, color: KxColors.textDim),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: height,
          // Let mouse/trackpad users drag the carousel too (web & desktop).
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: clip ? Clip.hardEdge : Clip.none,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              itemCount: coins.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final coin = coins[i];
                return TrendingCard(
                      key: ValueKey(coin.id),
                      coin: coin,
                      heroPrefix: _kTrendHero,
                      onTap: () => openCoin(context, coin, heroPrefix: _kTrendHero),
                    )
                    .animate(delay: (80 + i * 70).ms)
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: 0.25, end: 0, duration: 480.ms, curve: Curves.easeOutCubic);
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Staggered fade/slide-in for list rows. The widget tree is identical whether
/// or not it plays, so toggling [play] never tears down the row's state
/// (which would kill the AnimatedPrice flash on refresh).
class _Entrance extends StatefulWidget {
  const _Entrance({super.key, required this.play, required this.index, required this.child});

  final bool play;
  final int index;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final delayMs = math.min(widget.index, 12) * 40;
    const runMs = 420;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: delayMs + runMs),
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(delayMs / (delayMs + runMs), 1, curve: Curves.easeOutCubic),
    );
    _fade = curved;
    _slide = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(curved);
    if (widget.play) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.showDot = false,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;

  /// Null disables the button.
  final VoidCallback? onTap;
  final bool showDot;

  /// Shows a small spinner in place of the icon.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GlassCard(
              radius: 14,
              // 12 + 20 + 12 = 44px: minimum comfortable touch target.
              padding: const EdgeInsets.all(12),
              onTap: onTap,
              child: SizedBox.square(
                dimension: 20,
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(2),
                        child: CircularProgressIndicator(strokeWidth: 2, color: KxColors.cyan),
                      )
                    : Icon(icon, size: 20, color: KxColors.text),
              ),
            ),
            if (showDot)
              Positioned(
                top: -2,
                right: -2,
                child: IgnorePointer(
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: KxColors.brandGradient,
                      border: Border.all(color: KxColors.bg, width: 1.5),
                      boxShadow: [BoxShadow(color: KxColors.cyan.withValues(alpha: 0.6), blurRadius: 6)],
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

/// "Updated 12s ago", ticking every second.
class _UpdatedAgo extends StatefulWidget {
  const _UpdatedAgo({required this.time});

  final DateTime? time;

  @override
  State<_UpdatedAgo> createState() => _UpdatedAgoState();
}

class _UpdatedAgoState extends State<_UpdatedAgo> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && TickerMode.getValuesNotifier(context).value.enabled) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.time;
    return Text(
      t == null ? 'Syncing…' : 'Updated ${timeAgo(t)}',
      maxLines: 1,
      style: KxText.mono(11, color: KxColors.textMuted),
    );
  }
}

class _SortSheet extends StatelessWidget {
  const _SortSheet({required this.sort, required this.descending, required this.onSort, required this.onDirection});

  final CoinSort sort;
  final bool descending;
  final ValueChanged<CoinSort> onSort;
  final ValueChanged<bool> onDirection;

  static IconData _iconOf(CoinSort s) => switch (s) {
    CoinSort.marketCap => Icons.pie_chart_outline_rounded,
    CoinSort.price => Icons.attach_money_rounded,
    CoinSort.volume => Icons.bar_chart_rounded,
    CoinSort.change24h => Icons.show_chart_rounded,
    CoinSort.change7d => Icons.timeline_rounded,
    CoinSort.name => Icons.sort_by_alpha_rounded,
  };

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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
              const SizedBox(height: 18),
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
                      selected: descending,
                      labelOf: (d) => d ? '↓ DESC' : '↑ ASC',
                      onSelected: onDirection,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              for (var i = 0; i < CoinSort.values.length; i++)
                Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SortRow(
                        label: CoinSort.values[i].label,
                        icon: _iconOf(CoinSort.values[i]),
                        selected: CoinSort.values[i] == sort,
                        onTap: () => onSort(CoinSort.values[i]),
                      ),
                    )
                    .animate(delay: (i * 35).ms)
                    .fadeIn(duration: 260.ms)
                    .slideY(begin: 0.2, end: 0, duration: 320.ms, curve: Curves.easeOutCubic),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({required this.label, required this.icon, required this.selected, required this.onTap});

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
      child: _sortCard(),
    );
  }

  Widget _sortCard() {
    return GlassCard(
      radius: 16,
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
    );
  }
}
