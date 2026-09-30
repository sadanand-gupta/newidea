import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/coin.dart';
import '../services/api_service.dart';
import '../state/loadable.dart';
import '../state/watchlist_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/coin_tile.dart';
import '../widgets/formatters.dart';
import '../widgets/glass.dart';
import '../widgets/market_widgets.dart';
import '../widgets/state_views.dart';
import 'navigation.dart';

const _autoRefresh = Duration(seconds: 30);
const _heroPrefix = 'watch';

/// Content never gets wider than this on desktop / web.
const _maxContentWidth = 760.0;

enum _Sort { none, price, change, marketCap }

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key, required this.onBrowseMarkets});

  final VoidCallback onBrowseMarkets;

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  final _coins = Loadable<List<Coin>>();
  late final WatchlistProvider _watchlist;
  Set<String> _loadedIds = {};
  Timer? _timer;
  Listenable? _tickerMode;
  DateTime? _lastFetch;

  /// The watchlist changed while this tab was hidden; refetch when shown.
  bool _stale = false;
  _Sort _sort = _Sort.none;

  /// Row ids that already played their entrance animation, so rows don't
  /// re-animate when scrolled back into view or when data refreshes.
  final _revealed = <String>{};

  @override
  void initState() {
    super.initState();
    _watchlist = context.read<WatchlistProvider>();
    _watchlist.addListener(_onWatchlistChanged);
    _reload();
    _timer = Timer.periodic(_autoRefresh, (_) {
      // Only poll while this tab is on screen and the app is in the foreground.
      if (_visible && !_coins.loading) _reload();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode is off while the tab is hidden in the shell's IndexedStack or
    // covered by a pushed route; catch up as soon as it is shown again.
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
    _coins.dispose();
    super.dispose();
  }

  bool get _visible {
    if (!mounted || !TickerMode.getValuesNotifier(context).value.enabled) return false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed;
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

  void _onVisibilityChanged() {
    if (!_visible || _coins.loading) return;
    final last = _lastFetch;
    if (_stale || last == null || DateTime.now().difference(last) >= _autoRefresh) _reload();
  }

  /// Removals are applied locally (instant); additions need fresh coin data.
  void _onWatchlistChanged() {
    if (!mounted) return;
    if (!_loadedIds.containsAll(_watchlist.ids) && _visible) {
      _reload();
    } else {
      // Hidden tab: note it and fetch when the tab is next shown.
      if (!_loadedIds.containsAll(_watchlist.ids)) _stale = true;
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
    messenger.showSnackBar(SnackBar(
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
    ));
  }

  List<Coin> _sorted(List<Coin> coins) {
    // Descending, nulls last.
    int desc(double? a, double? b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return b.compareTo(a);
    }

    switch (_sort) {
      case _Sort.none:
        break;
      case _Sort.price:
        coins.sort((a, b) => desc(a.price, b.price));
      case _Sort.change:
        coins.sort((a, b) => desc(a.change24h, b.change24h));
      case _Sort.marketCap:
        coins.sort((a, b) => desc(a.marketCap, b.marketCap));
    }
    return coins;
  }

  @override
  Widget build(BuildContext context) {
    // No Scaffold of its own: the shell's Scaffold hosts the drawer (opened
    // from the header) and snack bars, which then float above the nav bar.
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: ListenableBuilder(
            listenable: _coins,
            builder: (context, _) {
              final all = _coins.data;
              final Widget body;
              if (all == null) {
                body = _coins.error != null && !_coins.loading
                    ? Padding(
                        key: const ValueKey('error'),
                        padding: const EdgeInsets.only(bottom: 90),
                        child: ErrorView(message: '${_coins.error}', onRetry: _retry),
                      )
                    : const LoadingView(key: ValueKey('loading'), rows: 4);
              } else {
                final ids = _watchlist.ids;
                // If the id list itself failed to load, trust the server's list
                // rather than filtering everything away into a false "empty".
                final idsKnown = _watchlist.error == null || ids.isNotEmpty;
                final coins = _sorted(idsKnown ? all.where((c) => ids.contains(c.id)).toList() : [...all]);
                body = coins.isEmpty
                    ? Padding(
                        key: const ValueKey('empty'),
                        padding: const EdgeInsets.only(bottom: 90),
                        child: EmptyView(
                          icon: Icons.star_outline_rounded,
                          title: 'Your watchlist is empty',
                          subtitle: 'Tap the star next to any coin to track its price and 24h move here.',
                          actionLabel: 'Explore markets',
                          onAction: widget.onBrowseMarkets,
                        ),
                      )
                    : KeyedSubtree(key: const ValueKey('list'), child: _buildList(coins));
              }
              return Column(
                children: [
                  _Header(
                    eyebrow: 'PORTFOLIO',
                    title: 'Watchlist',
                    source: _coins.source,
                    updatedAt: _coins.updatedAt,
                  ),
                  _LoadingLine(visible: _coins.loading && all != null),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            layoutBuilder: (current, previous) => Stack(
                              fit: StackFit.expand,
                              children: [...previous, if (current != null) current],
                            ),
                            child: body,
                          ),
                        ),
                        if (all != null && _coins.error != null)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 104,
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
      ),
    );
  }

  Widget _buildList(List<Coin> coins) {
    return RefreshIndicator(
      onRefresh: _reload,
      color: KxColors.cyan,
      backgroundColor: KxColors.bgElevated,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 6, bottom: 120),
        itemCount: coins.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _Reveal(
              key: const ValueKey('reveal-summary'),
              id: '__summary__',
              seen: _revealed,
              index: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _SummaryCard(coins: coins),
              ),
            );
          }
          if (i == 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SortBar(
                selected: _sort,
                onSelected: (s) => setState(() => _sort = s),
              ),
            );
          }
          final coin = coins[i - 2];
          return _Reveal(
            key: ValueKey('reveal-${coin.id}'),
            id: coin.id,
            seen: _revealed,
            index: i - 1,
            child: _SwipeToRemove(
              key: ValueKey('swipe-${coin.id}'),
              coinId: coin.id,
              coinName: coin.name,
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
}

// --- Header -----------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.eyebrow, required this.title, required this.source, required this.updatedAt});

  final String eyebrow;
  final String title;
  final String? source;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Tooltip(
            message: 'Open menu',
            child: Semantics(
              button: true,
              label: 'Open menu',
              excludeSemantics: true,
              child: GlassCard(
                radius: 14,
                padding: const EdgeInsets.all(12),
                onTap: () => Scaffold.of(context).openDrawer(),
                child: const Icon(Icons.menu_rounded, size: 20, color: KxColors.text),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KxText.label(11, color: KxColors.cyan).copyWith(letterSpacing: 2.4)),
                const SizedBox(height: 2),
                Semantics(
                  header: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: GradientText(title, style: KxText.display(28)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SourceBadge(source: source),
              if (updatedAt != null) ...[
                const SizedBox(height: 6),
                Text('Updated ${formatTime(updatedAt!)}', style: KxText.mono(10, color: KxColors.textMuted)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Hairline progress strip shown while a background refresh is in flight.
class _LoadingLine extends StatelessWidget {
  const _LoadingLine({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 2,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: visible
                ? const LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent)
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

// --- Entrance ---------------------------------------------------------------

/// Plays a staggered fade/slide the first time a row with [id] is built.
/// The decision is fixed for the State's lifetime so rebuilds never cut an
/// animation short or change the subtree shape.
class _Reveal extends StatefulWidget {
  const _Reveal({super.key, required this.id, required this.seen, required this.index, required this.child});

  final String id;
  final Set<String> seen;
  final int index;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  late final bool _animate = widget.seen.add(widget.id);

  @override
  Widget build(BuildContext context) {
    if (!_animate) return widget.child;
    // Only the first screenful staggers; rows revealed by scrolling appear promptly.
    final delay = widget.index < 10 ? widget.index * 55 : 0;
    return widget.child
        .animate(delay: delay.ms)
        .fadeIn(duration: 380.ms, curve: Curves.easeOut)
        .slideY(begin: 0.12, end: 0, duration: 380.ms, curve: Curves.easeOutCubic);
  }
}

// --- Swipe to remove --------------------------------------------------------

class _SwipeToRemove extends StatefulWidget {
  const _SwipeToRemove({
    super.key,
    required this.coinId,
    required this.coinName,
    required this.onRemove,
    required this.child,
  });

  final String coinId;
  final String coinName;
  final VoidCallback onRemove;
  final Widget child;

  @override
  State<_SwipeToRemove> createState() => _SwipeToRemoveState();
}

class _SwipeToRemoveState extends State<_SwipeToRemove> {
  static const _threshold = 0.35;
  final _progress = ValueNotifier<double>(0);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Swiping isn't discoverable by screen readers: expose it as an action.
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: 'Remove ${widget.coinName} from watchlist'): widget.onRemove,
      },
      child: Dismissible(
        key: ValueKey(widget.coinId),
        direction: DismissDirection.endToStart,
        dismissThresholds: const {DismissDirection.endToStart: _threshold},
        onUpdate: (details) {
          _progress.value = details.progress;
          if (details.reached && !details.previousReached) HapticFeedback.selectionClick();
        },
        onDismissed: (_) => widget.onRemove(),
        background: Padding(
          // Matches CoinTile's outer inset so the red card sits exactly behind it.
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [KxColors.down.withValues(alpha: 0.04), KxColors.down.withValues(alpha: 0.42)],
              ),
              border: Border.all(color: KxColors.down.withValues(alpha: 0.45)),
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 22),
                child: ValueListenableBuilder<double>(
                  valueListenable: _progress,
                  builder: (context, p, _) {
                    final k = (p / _threshold).clamp(0.0, 1.0).toDouble();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: k,
                          child: Text('REMOVE', style: KxText.label(11, color: Colors.white)),
                        ),
                        const SizedBox(width: 10),
                        Transform.scale(
                          scale: 0.7 + 0.55 * k,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: KxColors.down.withValues(alpha: 0.25 + 0.5 * k),
                              boxShadow: [
                                BoxShadow(color: KxColors.down.withValues(alpha: 0.5 * k), blurRadius: 14),
                              ],
                            ),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

// --- Sort bar ---------------------------------------------------------------

/// Sort chips with 44px tap targets and selected-state semantics.
class _SortBar extends StatelessWidget {
  const _SortBar({required this.selected, required this.onSelected});

  final _Sort selected;
  final ValueChanged<_Sort> onSelected;

  static String _label(_Sort s) => switch (s) {
        _Sort.none => 'Default',
        _Sort.price => 'Price',
        _Sort.change => '24h %',
        _Sort.marketCap => 'Market cap',
      };

  @override
  Widget build(BuildContext context) {
    // Grows with the text scale so large-text chips never clip.
    final height = math.max(44.0, MediaQuery.textScalerOf(context).scale(13) * 1.3 + 22);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _Sort.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final option = _Sort.values[i];
          final active = option == selected;
          return Semantics(
            button: true,
            selected: active,
            label: 'Sort by ${_label(option)}',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (active) return;
                HapticFeedback.selectionClick();
                onSelected(option);
              },
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: active ? KxColors.brandGradient : null,
                    color: active ? null : KxColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? Colors.transparent : KxColors.border),
                    boxShadow: [
                      if (active)
                        BoxShadow(color: KxColors.cyan.withValues(alpha: 0.3), blurRadius: 14, spreadRadius: -4),
                    ],
                  ),
                  child: Text(
                    _label(option),
                    maxLines: 1,
                    style: KxText.body(13,
                        weight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? Colors.black : KxColors.textDim),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- Summary ----------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.coins});

  final List<Coin> coins;

  @override
  Widget build(BuildContext context) {
    final ranked = coins.where((c) => c.change24h != null).toList()
      ..sort((a, b) => b.change24h!.compareTo(a.change24h!));
    final avg = ranked.isEmpty ? null : ranked.fold<double>(0, (s, c) => s + c.change24h!) / ranked.length;
    final best = ranked.isEmpty ? null : ranked.first;
    final worst = ranked.length > 1 ? ranked.last : null;

    return GlassCard(
      glow: KxColors.violet,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          KxColors.violet.withValues(alpha: 0.13),
          KxColors.cyan.withValues(alpha: 0.07),
          Colors.white.withValues(alpha: 0.02),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'ASSETS',
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: coins.length.toDouble()),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) =>
                        Text('${v.round()}', style: KxText.mono(26, weight: FontWeight.w700)),
                  ),
                ),
              ),
              Container(width: 1, height: 42, color: KxColors.border),
              const SizedBox(width: 16),
              Expanded(
                child: _Stat(
                  label: 'AVG 24H',
                  child: avg == null
                      ? Text('—', style: KxText.mono(22, weight: FontWeight.w700, color: KxColors.textMuted))
                      : TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: avg),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatPercent(v),
                              style: KxText.mono(22, weight: FontWeight.w700, color: KxColors.change(avg)),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (ranked.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('24H CHANGE BY ASSET', style: KxText.label(9, color: KxColors.textMuted)),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => CustomPaint(
                  painter: _ChangeBarsPainter([for (final c in ranked) c.change24h!], t),
                ),
              ),
            ),
          ],
          if (best != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _PerformerChip(coin: best, label: 'BEST')),
                if (worst != null) ...[
                  const SizedBox(width: 10),
                  Expanded(child: _PerformerChip(coin: worst, label: 'WORST')),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: KxText.label(10)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _PerformerChip extends StatelessWidget {
  const _PerformerChip({required this.coin, required this.label});

  final Coin coin;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = KxColors.change(coin.change24h);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          // No hero tag: the same coin is also in the list below.
          CoinAvatar(coin: coin, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KxText.label(9, color: color)),
                const SizedBox(height: 1),
                Text(coin.symbol,
                    style: KxText.display(14, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: ChangePill(coin.change24h, size: 10, filled: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Diverging bar strip around a zero line: one bar per asset, sorted best → worst.
class _ChangeBarsPainter extends CustomPainter {
  _ChangeBarsPainter(this.values, this.t);

  final List<double> values;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0 || size.width <= 0) return;
    final mid = size.height / 2;

    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = KxColors.borderStrong
        ..strokeWidth = 1,
    );

    final maxAbs = math.max(values.map((v) => v.abs()).reduce(math.max), 0.5);
    final gap = n > 40 ? 1.0 : 3.0;
    final barW = ((size.width - gap * (n - 1)) / n).clamp(1.0, 18.0).toDouble();
    final totalW = barW * n + gap * (n - 1);
    var x = math.max(0.0, (size.width - totalW) / 2);

    for (final v in values) {
      final h = math.max(1.5, v.abs() / maxAbs * (mid - 2) * t);
      final up = v >= 0;
      final rect = up ? Rect.fromLTWH(x, mid - h, barW, h) : Rect.fromLTWH(x, mid, barW, h);
      final color = KxColors.change(v);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: up ? Alignment.topCenter : Alignment.bottomCenter,
          end: up ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [color, color.withValues(alpha: 0.3)],
        ).createShader(rect);
      final r = Radius.circular(math.min(barW / 2, 3));
      canvas.drawRRect(
        up
            ? RRect.fromRectAndCorners(rect, topLeft: r, topRight: r)
            : RRect.fromRectAndCorners(rect, bottomLeft: r, bottomRight: r),
        paint,
      );
      x += barW + gap;
    }
  }

  @override
  bool shouldRepaint(_ChangeBarsPainter old) => old.t != t || !_listEquals(old.values, values);

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
