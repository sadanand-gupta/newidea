import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/coin.dart';
import '../services/api_service.dart';
import '../state/loadable.dart';
import '../state/watchlist_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/controls.dart';
import '../widgets/formatters.dart';
import '../widgets/glass.dart';
import '../widgets/kx_background.dart';
import '../widgets/market_widgets.dart';
import '../widgets/price_chart.dart';
import '../widgets/state_views.dart';

/// Readable column width on tablets, desktop and wide web windows.
const _maxContentWidth = 760.0;

const _ranges = [1, 7, 30, 90, 365];
const _rangeLabels = {1: '24H', 7: '7D', 30: '30D', 90: '90D', 365: '1Y'};
const _rangeLong = {
  1: 'Past 24 hours',
  7: 'Past 7 days',
  30: 'Past 30 days',
  90: 'Past 90 days',
  365: 'Past year',
};

/// Chart points tagged with the range they were fetched for, so the header
/// never mixes a stale range's change with the newly selected range label.
class _ChartData {
  const _ChartData(this.days, this.points);

  final int days;
  final List<PricePoint> points;

  double? get change {
    if (points.length < 2 || points.first.price == 0) return null;
    return (points.last.price / points.first.price - 1) * 100;
  }
}

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
  final _chart = Loadable<_ChartData>();

  /// Last good series per range, so flipping back to a range is instant and
  /// a failed refresh never blanks a chart the user already saw.
  final _chartCache = <int, _ChartData>{};

  /// Point under the finger while the chart is being scrubbed.
  final _scrub = ValueNotifier<PricePoint?>(null);
  int _days = 7;

  ApiService get _api => context.read<ApiService>();

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadChart();
  }

  @override
  void dispose() {
    _detail.dispose();
    _chart.dispose();
    _scrub.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() => _detail.load(() => _api.getCoinDetail(widget.coinId));

  Future<void> _loadChart() {
    final days = _days;
    final api = _api;
    return _chart.load(() async {
      final result = await api.getChart(widget.coinId, days);
      final data = _ChartData(days, result.data);
      _chartCache[days] = data;
      return ApiResult(data, result.source, result.updatedAt);
    });
  }

  Future<void> _refresh() async {
    await Future.wait([_loadDetail(), _loadChart()]);
  }

  void _selectRange(int days) {
    if (!mounted || days == _days) return;
    setState(() => _days = days);
    _scrub.value = null;
    _loadChart();
  }

  /// Series to draw for the selected range: fresh data, else the cached copy
  /// for this range, else (while loading) the previous range's series.
  _ChartData? get _visibleChart {
    final live = _chart.data;
    if (live != null && live.days == _days) return live;
    return _chartCache[_days] ?? live;
  }

  void _onScrub(PricePoint? point) {
    if (!mounted) return;
    if (_scrub.value != point) _scrub.value = point;
  }

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
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                      child: _Header(
                        coin: coin,
                        coinId: widget.coinId,
                        heroTag: widget.heroTag,
                        source: _detail.source,
                      ),
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

  /// Staggered entrance. Sections are keyed and live in a non-lazy Column,
  /// so each one animates only the first time it appears, not on rebuilds.
  Widget _enter(String id, int index, Widget child, {double gap = 18}) {
    return KeyedSubtree(
      key: ValueKey('section-$id'),
      child: Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: child
            .animate(delay: (90 * index).ms)
            .fadeIn(duration: 450.ms, curve: Curves.easeOut)
            .slideY(begin: 0.06, end: 0, duration: 520.ms, curve: Curves.easeOutCubic),
      ),
    );
  }

  Widget _buildBody(Coin? coin, CoinDetail? detail) {
    if (coin == null) {
      if (_detail.error != null) {
        return ErrorView(message: '${_detail.error}', onRetry: _loadDetail);
      }
      return const _PageLoader();
    }

    final low = coin.low24h, high = coin.high24h, price = coin.price;
    final hasAbout =
        detail != null && (detail.description.isNotEmpty || detail.categories.isNotEmpty || detail.homepage != null);

    final sections = <Widget>[
      if (detail != null && _detail.error != null)
        KeyedSubtree(
          key: const ValueKey('section-banner'),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: RefreshErrorBanner(message: '${_detail.error}', onRetry: _loadDetail),
          ),
        ),
      _enter('price', 0, _priceBlock(coin, detail), gap: 14),
      _enter('chart', 1, _chartCard()),
      if (low != null && high != null && price != null)
        _enter('range', 2, GlassCard(child: _RangeBar(low: low, high: high, current: price))),
      if (detail == null && _detail.error != null)
        _enter(
          'details-error',
          3,
          GlassCard(
            glow: KxColors.down,
            child: _InlineError(message: 'Could not load full details: ${_detail.error}', onRetry: _loadDetail),
          ),
        )
      else if (detail == null)
        _enter('details-loading', 3, const _DetailsSkeleton()),
      if (detail != null) ...[
        _enter(
          'performance',
          0,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [const SectionHeader('Performance'), _PerformanceRow(detail: detail)],
          ),
        ),
        _enter(
          'stats',
          1,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [const SectionHeader('Market stats'), _MarketStatsGrid(detail: detail)],
          ),
        ),
        _enter(
          'supply',
          2,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [const SectionHeader('Supply'), _SupplyCard(coin: detail.coin)],
          ),
        ),
        if (hasAbout)
          _enter(
            'about',
            3,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [SectionHeader('About ${coin.name}'), _AboutCard(detail: detail)],
            ),
          ),
      ],
    ];

    return RefreshIndicator(
      color: KxColors.cyan,
      backgroundColor: KxColors.bgElevated,
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 6, 16, 32 + MediaQuery.paddingOf(context).bottom),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sections),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- price

  Widget _priceBlock(Coin coin, CoinDetail? detail) {
    return ListenableBuilder(
      listenable: Listenable.merge([_scrub, _chart]),
      builder: (context, _) {
        final scrub = _scrub.value;
        final data = _visibleChart;
        final current = (data != null && data.days == _days) ? data : null;

        // Change for the selected range: chart first→last, then the matching
        // API field, then the 24h change as a last resort.
        double? change;
        String caption;
        final matching = switch (_days) {
          1 => coin.change24h,
          7 => coin.change7d,
          30 => detail?.change30d,
          365 => detail?.change1y,
          _ => null,
        };
        if (current?.change != null) {
          change = current!.change;
          caption = _rangeLong[_days]!;
        } else if (matching != null) {
          change = matching;
          caption = _rangeLong[_days]!;
        } else {
          change = coin.change24h;
          caption = _rangeLong[1]!;
        }

        double? scrubChange;
        if (scrub != null && data != null && data.points.isNotEmpty && data.points.first.price != 0) {
          scrubChange = (scrub.price / data.points.first.price - 1) * 100;
        }

        return _PriceBlock(
          symbol: coin.symbol,
          price: scrub?.price ?? coin.price,
          change: scrub != null ? scrubChange : change,
          caption: scrub != null ? formatDateTime(scrub.time) : caption,
          scrubbing: scrub != null,
          updatedAt: _detail.updatedAt,
        );
      },
    );
  }

  // ---------------------------------------------------------------- chart

  Widget _chartCard() {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 260,
            child: ListenableBuilder(listenable: _chart, builder: (context, _) => _chartBody()),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: 'Chart range, ${_rangeLong[_days]} selected',
            child: KxSegmented<int>(
              options: _ranges,
              selected: _days,
              labelOf: (d) => _rangeLabels[d]!,
              onSelected: _selectRange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartBody() {
    final data = _visibleChart;
    final error = _chart.error;
    final stale = data == null || data.days != _days;

    if (error != null && stale) {
      return _InlineError(
        message: "Couldn't load the ${_rangeLabels[_days]} chart",
        detail: '$error',
        onRetry: _loadChart,
      );
    }
    if (data == null) return const _ChartSkeleton();

    final Widget content = data.points.length < 2
        ? const EmptyView(icon: Icons.show_chart_rounded, title: 'No price history for this range')
        : PriceChart(points: data.points, days: data.days, onScrub: _onScrub);

    return Stack(
      children: [
        Positioned.fill(child: content),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              // Only dim the chart when it shows another range; refreshing a
              // range we already have (cached) happens silently.
              child: _chart.loading && stale
                  ? _ChartLoadingOverlay(key: const ValueKey('loading'), label: _rangeLabels[_days]!)
                  : const SizedBox.shrink(key: ValueKey('idle')),
            ),
          ),
        ),
        if (error != null && !_chart.loading)
          Positioned(top: 0, left: 0, child: _MiniRetry(onRetry: _loadChart)),
      ],
    );
  }
}

// =================================================================== header

class _Header extends StatelessWidget {
  const _Header({required this.coin, required this.coinId, required this.heroTag, required this.source});

  final Coin? coin;
  final String coinId;
  final String? heroTag;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final coin = this.coin;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            tooltip: 'Back',
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 12),
          if (coin != null) ...[
            CoinAvatar(coin: coin, size: 40, heroTag: heroTag),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coin?.name ?? 'Loading…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KxText.display(18),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (coin != null && coin.symbol.isNotEmpty) _TagChip(text: coin.symbol, accent: true),
                    if (coin != null && coin.rank != null) _TagChip(text: '#${coin.rank}'),
                    if (source != null) SourceBadge(source: source),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _WatchButton(coinId: coinId, coinName: coin?.name),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            splashColor: KxColors.cyan.withValues(alpha: 0.12),
            child: Ink(
              width: 44,
              height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: KxColors.border),
            ),
              child: Icon(icon, size: 16, color: KxColors.text),
            ),
          ),
        ),
      ),
    );
  }
}

/// Watchlist toggle with explicit feedback: the star animates, and a snackbar
/// confirms the change with an Undo (or explains a failure). Taps are ignored
/// while a toggle is in flight so rapid taps can't desync the server.
class _WatchButton extends StatefulWidget {
  const _WatchButton({required this.coinId, required this.coinName});

  final String coinId;
  final String? coinName;

  @override
  State<_WatchButton> createState() => _WatchButtonState();
}

class _WatchButtonState extends State<_WatchButton> {
  bool _busy = false;

  Future<void> _toggle({bool isUndo = false}) async {
    if (_busy) return;
    final provider = context.read<WatchlistProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final adding = !provider.contains(widget.coinId);
    final name = widget.coinName ?? 'Coin';
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    final error = await provider.toggle(widget.coinId);
    if (mounted) setState(() => _busy = false);

    messenger.hideCurrentSnackBar();
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (isUndo) return;
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(adding ? '$name added to your watchlist' : '$name removed from your watchlist'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: KxColors.cyan,
          onPressed: () {
            if (mounted) {
              _toggle(isUndo: true);
            } else {
              // Page was closed: still honour the undo.
              provider.toggle(widget.coinId);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final watched = context.select<WatchlistProvider, bool>((w) => w.contains(widget.coinId));
    return Semantics(
      toggled: watched,
      child: IconButton(
        tooltip: watched ? 'Remove from watchlist' : 'Add to watchlist',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: _busy ? null : _toggle,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
            child: child,
          ),
          child: watched
              ? Icon(Icons.star_rounded, key: const ValueKey(true), color: KxColors.warn, size: 26)
                  .animate(key: const ValueKey('glow'))
                  .shimmer(duration: 900.ms, color: Colors.white)
              : const Icon(Icons.star_outline_rounded, key: ValueKey(false), color: KxColors.textDim, size: 26),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.text, this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: accent
            ? LinearGradient(
                colors: [KxColors.cyan.withValues(alpha: 0.18), KxColors.violet.withValues(alpha: 0.18)],
              )
            : null,
        color: accent ? null : Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: accent ? KxColors.cyan.withValues(alpha: 0.35) : KxColors.border),
      ),
      child: Text(
        text,
        style: KxText.mono(11, weight: FontWeight.w700, color: accent ? KxColors.cyan : KxColors.textDim),
      ),
    );
  }
}

// ============================================================== price block

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({
    required this.symbol,
    required this.price,
    required this.change,
    required this.caption,
    required this.scrubbing,
    required this.updatedAt,
  });

  final String symbol;
  final double? price;
  final double? change;
  final String caption;
  final bool scrubbing;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final priceStyle = KxText.mono(36, weight: FontWeight.w700).copyWith(
      height: 1.1,
      shadows: [Shadow(color: KxColors.cyan.withValues(alpha: 0.35), blurRadius: 18)],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                symbol.isEmpty ? 'PRICE · USD' : '$symbol / USD',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: KxText.label(11, color: KxColors.textMuted),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: scrubbing
                  ? Container(
                      key: const ValueKey('scrub-tag'),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: KxColors.cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: KxColors.cyan.withValues(alpha: 0.35)),
                      ),
                      child: Text('HISTORICAL', style: KxText.label(9, color: KxColors.cyan)),
                    )
                  : updatedAt != null
                      ? _UpdatedAgo(key: const ValueKey('updated'), time: updatedAt!)
                      : const SizedBox.shrink(key: ValueKey('none')),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Scales down for long prices (e.g. $0.00001780) on 360px phones.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: _isMicroPrice(price)
              // AnimatedPrice caps at 8 decimals, which would read $0.00000000.
              ? Text(formatChartPrice(price), maxLines: 1, style: priceStyle)
              : Transform.translate(
                  offset: const Offset(-4, 0), // AnimatedPrice has 4px inner padding
                  child: AnimatedPrice(value: price, style: priceStyle, flash: !scrubbing),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ChangePill(change, size: 13),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previous, if (current != null) current],
                ),
                child: Text(
                  caption,
                  key: ValueKey(scrubbing),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KxText.mono(12, color: scrubbing ? KxColors.cyan : KxColors.textDim),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

bool _isMicroPrice(double? v) => v != null && v != 0 && v.abs() < 0.000001;

/// "Updated 2m ago" that keeps itself current instead of freezing at the
/// value computed when the page was built.
class _UpdatedAgo extends StatefulWidget {
  const _UpdatedAgo({super.key, required this.time});

  final DateTime time;

  @override
  State<_UpdatedAgo> createState() => _UpdatedAgoState();
}

class _UpdatedAgoState extends State<_UpdatedAgo> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'Updated ${timeAgo(widget.time)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: KxText.mono(10, color: KxColors.textDim),
    );
  }
}

// ==================================================================== chart

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withValues(alpha: 0.02), KxColors.cyan.withValues(alpha: 0.06)],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1400.ms, color: KxColors.cyan.withValues(alpha: 0.18)),
        ),
        const Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2, color: KxColors.cyan),
          ),
        ),
      ],
    );
  }
}

class _ChartLoadingOverlay extends StatelessWidget {
  const _ChartLoadingOverlay({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: KxColors.bg.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1200.ms, color: KxColors.cyan.withValues(alpha: 0.22)),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: KxColors.bgElevated.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: KxColors.cyan.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: KxColors.cyan),
                ),
                const SizedBox(width: 6),
                Text('Loading $label', style: KxText.mono(10, color: KxColors.textDim)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniRetry extends StatelessWidget {
  const _MiniRetry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Chart update failed. Retry',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: KxColors.bgElevated.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: KxColors.down.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh_rounded, size: 14, color: KxColors.down),
                const SizedBox(width: 6),
                Text('Update failed · Retry', style: KxText.mono(11, weight: FontWeight.w600, color: KxColors.down)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================ 24h range

class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.low, required this.high, required this.current});

  final double low, high, current;

  static Color _colorAt(double t) =>
      t < 0.5 ? Color.lerp(KxColors.down, KxColors.warn, t * 2)! : Color.lerp(KxColors.warn, KxColors.up, (t - 0.5) * 2)!;

  @override
  Widget build(BuildContext context) {
    final t = high > low ? ((current - low) / (high - low)).clamp(0.0, 1.0).toDouble() : 0.5;
    const marker = 16.0;
    final lowText = formatChartPrice(low), highText = formatChartPrice(high);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '24 hour range: low $lowText, high $highText. '
          'Current price is ${(t * 100).round()} percent of the way from low to high.',
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(child: Text('24H RANGE', maxLines: 1, overflow: TextOverflow.ellipsis, style: KxText.label(11))),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                '${(t * 100).round()}% from low',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: KxText.mono(11, color: KxColors.textDim),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: marker,
          child: LayoutBuilder(
            builder: (context, constraints) => TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: t),
              duration: const Duration(milliseconds: 1500),
              curve: const Interval(0.2, 1, curve: Curves.easeOutCubic),
              builder: (context, v, _) {
                final pos = v.clamp(0.0, 1.0).toDouble();
                final color = _colorAt(pos);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: (marker - 6) / 2,
                      height: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: const LinearGradient(colors: [KxColors.down, KxColors.warn, KxColors.up]),
                          boxShadow: [
                            BoxShadow(color: KxColors.down.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(-20, 0)),
                            BoxShadow(color: KxColors.up.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(20, 0)),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: (constraints.maxWidth - marker) * pos,
                      top: 0,
                      child: Container(
                        width: marker,
                        height: marker,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: KxColors.text,
                          border: Border.all(color: KxColors.bg, width: 3),
                          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.85), blurRadius: 14, spreadRadius: 1)],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _RangeLabel(label: 'LOW', value: lowText, color: KxColors.down)),
            const SizedBox(width: 12),
            Expanded(
              child: _RangeLabel(label: 'HIGH', value: highText, color: KxColors.up, end: true),
            ),
          ],
        ),
      ],
      ),
    );
  }
}

class _RangeLabel extends StatelessWidget {
  const _RangeLabel({required this.label, required this.value, required this.color, this.end = false});

  final String label;
  final String value;
  final Color color;
  final bool end;

  @override
  Widget build(BuildContext context) {
    final align = end ? Alignment.centerRight : Alignment.centerLeft;
    return Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: KxText.label(10, color: color.withValues(alpha: 0.8))),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: align,
          child: Text(value, maxLines: 1, style: KxText.mono(13, weight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ============================================================== performance

class _PerformanceRow extends StatelessWidget {
  const _PerformanceRow({required this.detail});

  final CoinDetail detail;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, double?)>[
      ('24H', detail.coin.change24h),
      ('7D', detail.coin.change7d),
      ('30D', detail.change30d),
      ('1Y', detail.change1y),
    ];
    return Row(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _PerfTile(label: entries[i].$1, value: entries[i].$2)
                .animate(delay: (200 + 70 * i).ms)
                .fadeIn(duration: 350.ms)
                .scaleXY(begin: 0.92, end: 1, duration: 450.ms, curve: Curves.easeOutBack),
          ),
        ],
      ],
    );
  }
}

class _PerfTile extends StatelessWidget {
  const _PerfTile({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final color = KxColors.change(value);
    return GlassCard(
      radius: 16,
      padding: EdgeInsets.zero,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.02)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0), color, color.withValues(alpha: 0)],
              ),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 10)],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
            child: Column(
              children: [
                Text(label, style: KxText.label(10, color: KxColors.textMuted)),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatPercent(value),
                    maxLines: 1,
                    style: KxText.mono(13, weight: FontWeight.w700, color: color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================= market stats

class _MarketStatsGrid extends StatelessWidget {
  const _MarketStatsGrid({required this.detail});

  final CoinDetail detail;

  @override
  Widget build(BuildContext context) {
    final c = detail.coin;
    final volToCap = (c.volume != null && c.marketCap != null && c.marketCap! > 0)
        ? (c.volume! / c.marketCap!).toStringAsFixed(4)
        : '—';
    final fromAtl = (c.price != null && detail.atl != null && detail.atl! > 0)
        ? (c.price! / detail.atl! - 1) * 100
        : null;
    final items = <(String, String, Color?)>[
      ('Market cap', formatCompact(c.marketCap), null),
      ('24h volume', formatCompact(c.volume), null),
      ('Fully diluted val.', formatCompact(detail.fullyDilutedValuation), null),
      ('Vol / Mkt cap', volToCap, null),
      ('All-time high', formatChartPrice(detail.ath), null),
      ('From ATH', formatPercent(detail.athChange), KxColors.change(detail.athChange)),
      ('ATH date', formatDate(detail.athDate), null),
      ('All-time low', formatChartPrice(detail.atl), null),
      ('From ATL', formatPercent(fromAtl), KxColors.change(fromAtl)),
      ('ATL date', formatDate(detail.atlDate), null),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = ((constraints.maxWidth - 10) / 2).floorToDouble();
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                width: width,
                child: _StatTile(label: items[i].$1, value: items[i].$2, color: items[i].$3)
                    .animate(delay: (150 + 40 * i).ms)
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.15, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),
              ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KxText.label(10, color: KxColors.textMuted),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: KxText.mono(14, weight: FontWeight.w600, color: color ?? KxColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================== supply

class _SupplyCard extends StatelessWidget {
  const _SupplyCard({required this.coin});

  final Coin coin;

  @override
  Widget build(BuildContext context) {
    final circ = coin.circulatingSupply;
    final max = coin.maxSupply;
    final ratio = (circ != null && max != null && max > 0) ? (circ / max).clamp(0.0, 1.0).toDouble() : null;

    final unit = coin.symbol.isEmpty ? '' : ' ${coin.symbol}';

    Widget row(String label, double? value, Color dot, {String missing = '—'}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dot,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.6), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 10),
              // Label and value share the row 2:3 so the values form a clean
              // right-aligned column regardless of label length.
              Expanded(
                flex: 2,
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: KxText.body(13, color: KxColors.textDim)),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      value == null ? missing : '${formatNumber(value)}$unit',
                      maxLines: 1,
                      style: KxText.mono(13, weight: FontWeight.w600, color: value == null ? KxColors.textMuted : KxColors.text),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row('Circulating', circ, KxColors.cyan),
          row('Total', coin.totalSupply, KxColors.violet),
          // CoinGecko reports max_supply as null for uncapped coins (e.g. ETH).
          row('Max', max, KxColors.magenta, missing: '∞  No fixed cap'),
          const SizedBox(height: 14),
          if (ratio != null)
            _SupplyProgress(ratio: ratio)
          else
            Text(
              circ == null
                  ? 'Circulating supply not reported.'
                  : 'No fixed maximum supply, so there is no circulation progress to show.',
              style: KxText.body(12, color: KxColors.textDim),
            ),
        ],
      ),
    );
  }
}

class _SupplyProgress extends StatelessWidget {
  const _SupplyProgress({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: ratio),
      duration: const Duration(milliseconds: 1700),
      // Leading interval lets the section's entrance finish before filling.
      curve: const Interval(0.25, 1, curve: Curves.easeOutCubic),
      builder: (context, v, _) {
        final fill = v.clamp(0.0, 1.0).toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('CIRCULATING / MAX',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: KxText.label(10, color: KxColors.textMuted)),
                ),
                GradientText('${(fill * 100).toStringAsFixed(1)}%', style: KxText.mono(15, weight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: KxColors.border),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: fill,
                  // Without this the childless DecoratedBox gets loose height
                  // constraints from Align and collapses to 0px tall.
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: KxColors.brandGradient,
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [BoxShadow(color: KxColors.cyan.withValues(alpha: 0.5), blurRadius: 10)],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(ratio * 100).toStringAsFixed(1)}% of max supply in circulation',
              style: KxText.body(11, color: KxColors.textMuted),
            ),
          ],
        );
      },
    );
  }
}

// ==================================================================== about

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.detail});

  final CoinDetail detail;

  @override
  Widget build(BuildContext context) {
    final homepage = detail.homepage;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.description.isNotEmpty) _ExpandableText(text: detail.description),
          if (detail.categories.isNotEmpty) ...[
            if (detail.description.isNotEmpty) const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final c in detail.categories) _CategoryPill(label: c)],
            ),
          ],
          if (homepage != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.language_rounded, size: 16, color: KxColors.cyan),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: SelectableText(homepage, style: KxText.mono(12, color: KxColors.cyan)),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Copy website link',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.copy_rounded, size: 16, color: KxColors.textDim),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: homepage));
                    HapticFeedback.selectionClick();
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(const SnackBar(content: Text('Website link copied')));
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.white.withValues(alpha: 0.07), Colors.white.withValues(alpha: 0.03)],
        ),
        border: Border.all(color: KxColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: KxColors.brandGradient),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KxText.body(12, weight: FontWeight.w500, color: KxColors.textDim),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  static const _collapsedLines = 4;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final style = KxText.body(14, color: KxColors.textDim).copyWith(height: 1.55);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: _collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Text(
                widget.text,
                style: style,
                maxLines: _expanded ? null : _collapsedLines,
                overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
            ),
            if (overflows) ...[
              const SizedBox(height: 2),
              Semantics(
                button: true,
                expanded: _expanded,
                child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GradientText(
                        _expanded ? 'Show less' : 'Read more',
                        style: KxText.body(13, weight: FontWeight.w700),
                      ),
                      const SizedBox(width: 2),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: KxColors.violet),
                      ),
                    ],
                  ),
                  ),
                ),
              ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ========================================================== loading / error

class _PageLoader extends StatelessWidget {
  const _PageLoader();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: KxColors.cyan),
          ),
          const SizedBox(height: 16),
          Text('Loading market data…', style: KxText.body(13, color: KxColors.textDim)),
        ],
      ).animate().fadeIn(duration: 300.ms),
    );
  }
}

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  static Widget _box(double height) => Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KxColors.border),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LoadingView.bar(110, 12),
        const SizedBox(height: 14),
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _box(64)),
            ],
          ],
        ),
        const SizedBox(height: 22),
        LoadingView.bar(90, 12),
        const SizedBox(height: 14),
        for (var r = 0; r < 2; r++) ...[
          if (r > 0) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _box(62)),
              const SizedBox(width: 10),
              Expanded(child: _box(62)),
            ],
          ),
        ],
      ],
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1400.ms, color: KxColors.cyan.withValues(alpha: 0.12));
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry, this.detail});

  final String message;
  final String? detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Scrollable so it can't overflow the fixed-height chart slot at large
    // text scales.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [KxColors.down.withValues(alpha: 0.25), KxColors.down.withValues(alpha: 0)],
                ),
                border: Border.all(color: KxColors.down.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.cloud_off_rounded, color: KxColors.down, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: KxText.body(13, weight: FontWeight.w600, color: KxColors.text),
            ),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(
                detail!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: KxText.body(12, color: KxColors.textDim),
              ),
            ],
            const SizedBox(height: 12),
            GradientButton(label: 'Retry', icon: Icons.refresh_rounded, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
