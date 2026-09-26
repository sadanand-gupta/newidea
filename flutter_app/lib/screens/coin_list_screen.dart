import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

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
    if (!TickerMode.getNotifier(context).value) return;
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
      child: ListenableBuilder(
        listenable: _coins,
        builder: (context, _) {
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
                    SliverToBoxAdapter(key: const ValueKey('header'), child: _buildHeader()),
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
                            ? _TrendingSection(coins: _trending)
                            : const SizedBox(width: double.infinity, height: 6),
                      ),
                    ),
                    SliverPersistentHeader(
                      key: const ValueKey('filters'),
                      pinned: true,
                      delegate: _FilterBarDelegate(
                        extent: 72 + searchHeight,
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
                  left: 16,
                  right: 16,
                  bottom: navPad + 10,
                  child: RefreshErrorBanner(message: '${_coins.error}', onRetry: _reload),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final isDefaultSort = _sort == CoinSort.marketCap && _descending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
          child: Row(
            children: [
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
              const SizedBox(width: 10),
              _GlassIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Sort',
                showDot: !isDefaultSort,
                onTap: _showSortSheet,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 12, color: KxColors.textMuted),
              const SizedBox(width: 5),
              _UpdatedAgo(time: _coins.updatedAt),
              Text('  ·  ', style: KxText.mono(11, color: KxColors.textMuted)),
              Flexible(
                child: GestureDetector(
                  onTap: _showSortSheet,
                  child: Text(
                    'Sorted by ${_sort.label.toLowerCase()} ${_descending ? '↓' : '↑'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KxText.body(11, weight: FontWeight.w500, color: KxColors.textDim),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.15, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  List<Widget> _buildBody(List<Coin>? coins) {
    if (coins == null) {
      if (_coins.error != null) {
        return [
          SliverToBoxAdapter(
            key: const ValueKey('error'),
            child: SizedBox(height: 440, child: ErrorView(message: '${_coins.error}', onRetry: _reload)),
          ),
        ];
      }
      return const [
        SliverToBoxAdapter(
          key: ValueKey('loading'),
          child: SizedBox(height: 600, child: LoadingView()),
        ),
      ];
    }

    if (coins.isEmpty) {
      final query = _searchController.text.trim();
      return [
        SliverToBoxAdapter(
          key: const ValueKey('empty'),
          child: SizedBox(
            height: 420,
            child: EmptyView(
              icon: Icons.search_off_rounded,
              title: query.isEmpty ? 'No coins match this filter' : 'No coins found for "$query"',
              subtitle: 'Try a different search term or filter.',
              actionLabel: 'Clear search & filters',
              onAction: _clearAll,
            ),
          ),
        ),
      ];
    }

    // Replay the staggered entrance only when the list identity changes.
    final listKey = _paramsOf[coins] ?? '';
    if (listKey != _animatedKey) {
      _animatedKey = listKey;
      _animateUntil = DateTime.now().add(_kEntranceWindow);
    }
    final animate = DateTime.now().isBefore(_animateUntil);

    return [
      const SliverToBoxAdapter(key: ValueKey('columns'), child: _ColumnHeader()),
      SliverList.builder(
        key: const ValueKey('list'),
        itemCount: coins.length,
        findChildIndexCallback: (key) {
          if (key is! ValueKey<String> || !key.value.startsWith('$listKey#')) return null;
          final id = key.value.substring(listKey.length + 1);
          final i = coins.indexWhere((c) => c.id == id);
          return i < 0 ? null : i;
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
    ];
  }
}

// -----------------------------------------------------------------------------
// Pieces
// -----------------------------------------------------------------------------

/// Pinned search + filter chips; frosts over the list once content scrolls under.
class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  _FilterBarDelegate({required this.extent, required this.loading, required this.search, required this.filters});

  final double extent;
  final bool loading;
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
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: search),
            const SizedBox(height: 10),
            filters,
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

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader();

  @override
  Widget build(BuildContext context) {
    final style = KxText.label(10, color: KxColors.textMuted);
    // Mirrors CoinTile: 16 outer + 12 inner padding on the left; 16 + 4 + star on the right.
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 20, 6),
      child: Row(
        children: [
          SizedBox(width: 22, child: Text('#', style: style, textAlign: TextAlign.center)),
          const SizedBox(width: 8),
          Expanded(flex: 5, child: Text('ASSET', style: style)),
          Expanded(flex: 4, child: Text('7D', style: style, textAlign: TextAlign.center)),
          const SizedBox(width: 10),
          Text('PRICE · 24H', style: style),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _TrendingSection extends StatelessWidget {
  const _TrendingSection({required this.coins});

  final List<Coin> coins;

  @override
  Widget build(BuildContext context) {
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
                Text('24h movers', style: KxText.body(11, weight: FontWeight.w500, color: KxColors.textDim)),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 164,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
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
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: delayMs + runMs));
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
  const _GlassIconButton({required this.icon, required this.tooltip, required this.onTap, this.showDot = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GlassCard(
            radius: 14,
            padding: const EdgeInsets.all(10),
            onTap: onTap,
            child: Icon(icon, size: 20, color: KxColors.text),
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
      if (mounted && TickerMode.getNotifier(context).value) setState(() {});
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
          colors: [
            Color.lerp(KxColors.bgElevated, KxColors.violet, 0.06)!,
            KxColors.bgElevated,
          ],
        ),
        boxShadow: [BoxShadow(color: KxColors.cyan.withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, -8))],
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
                        Text('Sort markets', style: KxText.display(20)),
                        const SizedBox(height: 2),
                        Text('Choose how the list is ordered',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: KxText.body(12, color: KxColors.textDim)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 128,
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
              style: KxText.body(15,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? KxColors.text : KxColors.textDim),
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
