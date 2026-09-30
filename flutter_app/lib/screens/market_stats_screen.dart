import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
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
import '../widgets/sparkline.dart';
import '../widgets/state_views.dart';
import 'navigation.dart';

/// Brand colours for well-known assets; everything else falls back to the neon palette.
const _brandColors = <String, Color>{
  'BTC': Color(0xFFF7931A),
  'ETH': Color(0xFF627EEA),
  'USDT': Color(0xFF26A17B),
  'BNB': Color(0xFFF3BA2F),
  'SOL': Color(0xFF9945FF),
  'USDC': Color(0xFF2775CA),
  'XRP': Color(0xFF8FA3BF),
  'STETH': Color(0xFF00A3FF),
};

const _fallbackPalette = [
  KxColors.cyan,
  KxColors.violet,
  KxColors.magenta,
  KxColors.up,
  KxColors.warn,
  Color(0xFF3B82F6),
];

const _dominanceSlices = 5;
const _autoRefresh = Duration(seconds: 60);

/// Content never stretches wider than this on desktop / web windows.
const _maxContentWidth = 900.0;

/// Above this content width, dominance and sentiment sit side by side.
const _twoColumnBreakpoint = 720.0;

/// Minimum interactive height (Material / WCAG touch-target guidance).
const _minTap = 44.0;

class MarketStatsScreen extends StatefulWidget {
  const MarketStatsScreen({super.key});

  @override
  State<MarketStatsScreen> createState() => _MarketStatsScreenState();
}

class _MarketStatsScreenState extends State<MarketStatsScreen> with WidgetsBindingObserver {
  final _stats = Loadable<GlobalStats>();
  Timer? _timer;
  DateTime? _lastFetch;

  /// False while this tab is hidden in the shell's IndexedStack or covered by a route.
  ValueListenable<TickerModeData>? _tickerMode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
    _startAutoRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = TickerMode.getValuesNotifier(context);
    if (!identical(notifier, _tickerMode)) {
      _tickerMode?.removeListener(_onVisibilityChanged);
      _tickerMode = notifier..addListener(_onVisibilityChanged);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickerMode?.removeListener(_onVisibilityChanged);
    _timer?.cancel();
    _stats.dispose();
    super.dispose();
  }

  bool get _visible => _tickerMode?.value.enabled ?? true;

  bool get _isStale {
    final last = _lastFetch;
    return last == null || DateTime.now().difference(last) >= _autoRefresh;
  }

  Future<void> _reload() {
    final api = context.read<ApiService>();
    return _stats.load(() async {
      final result = await api.getGlobalStats();
      _lastFetch = DateTime.now();
      return result;
    });
  }

  void _startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(_autoRefresh, (_) {
      // Don't poll while the tab is off-screen; it catches up when shown again.
      if (mounted && _visible && !_stats.loading) _reload();
    });
  }

  void _stopAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }

  /// Tab became visible again: refresh if the data went stale while hidden.
  /// Deferred to after the frame because TickerMode flips during build.
  void _onVisibilityChanged() {
    if (!_visible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _visible && _isStale && !_stats.loading) _reload();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startAutoRefresh();
      if (_visible && _isStale && !_stats.loading) _reload();
    } else if (state != AppLifecycleState.inactive) {
      // paused / hidden / detached: no point polling in the background.
      _stopAutoRefresh();
    }
  }

  void _open(Coin coin, String heroPrefix) => openCoin(context, coin, heroPrefix: heroPrefix);

  /// Sections fade/slide in once, on the first data load. The Animate state
  /// survives rebuilds, so refreshes don't replay the entrance.
  Widget _reveal(int i, Widget child) => child
      .animate(key: ValueKey('reveal-$i'), delay: (90 * i).ms)
      .fadeIn(duration: 500.ms, curve: Curves.easeOut)
      .slideY(begin: 0.06, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);

  static Widget _pad(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _stats,
          builder: (context, _) {
            final stats = _stats.data;
            final Widget body;
            if (stats == null) {
              body = _stats.error != null
                  ? Padding(
                      key: const ValueKey('error'),
                      padding: const EdgeInsets.only(bottom: 90),
                      child: _MaxWidth(child: ErrorView(message: '${_stats.error}', onRetry: _reload)),
                    )
                  : const _MaxWidth(key: ValueKey('loading'), child: LoadingView(rows: 6));
            } else {
              body = KeyedSubtree(key: const ValueKey('data'), child: _buildDashboard(stats));
            }
            return Column(
              children: [
                _MaxWidth(
                  child: _Header(
                    eyebrow: 'OVERVIEW',
                    title: 'Global Market',
                    source: _stats.source,
                    updatedAt: _stats.updatedAt,
                    loading: _stats.loading,
                    onRefresh: _reload,
                  ),
                ),
                _MaxWidth(child: _LoadingLine(visible: _stats.loading && stats != null)),
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
                      if (stats != null && _stats.error != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 104,
                          child: _MaxWidth(
                            maxWidth: _maxContentWidth - 32,
                            child: RefreshErrorBanner(message: '${_stats.error}', onRetry: _reload),
                          ),
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

  Widget _buildDashboard(GlobalStats stats) {
    Widget section(String title, Widget child, {Widget? trailing}) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [SectionHeader(title, trailing: trailing), child],
        );

    final dominance = stats.dominance.isEmpty
        ? null
        : section('Market-cap dominance', _DominanceCard(dominance: stats.dominance));
    final sentiment = section('Sentiment', _SentimentCard(stats: stats), trailing: const _EstimateTag());

    return RefreshIndicator(
      onRefresh: _reload,
      color: KxColors.cyan,
      backgroundColor: KxColors.bgElevated,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 6, bottom: 120),
        child: _MaxWidth(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumn = constraints.maxWidth >= _twoColumnBreakpoint;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _reveal(0, _pad(_HeroCard(stats: stats))),
                  const SizedBox(height: 18),
                  _reveal(1, _pad(section('Key metrics', _KpiGrid(stats: stats)))),
                  const SizedBox(height: 18),
                  if (twoColumn && dominance != null)
                    _reveal(
                      2,
                      _pad(Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: dominance),
                          const SizedBox(width: 16),
                          Expanded(child: sentiment),
                        ],
                      )),
                    )
                  else ...[
                    if (dominance != null) ...[
                      _reveal(2, _pad(dominance)),
                      const SizedBox(height: 18),
                    ],
                    _reveal(3, _pad(sentiment)),
                  ],
                  const SizedBox(height: 18),
                  _reveal(4, _TopMovers(stats: stats, onOpen: _open)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Centres [child] and caps its width so the dashboard stays readable on wide windows.
class _MaxWidth extends StatelessWidget {
  const _MaxWidth({super.key, required this.child, this.maxWidth = _maxContentWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}

// --- Header -----------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.eyebrow,
    required this.title,
    required this.source,
    required this.updatedAt,
    required this.loading,
    required this.onRefresh,
  });

  final String eyebrow;
  final String title;
  final String? source;
  final DateTime? updatedAt;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow, style: KxText.label(11, color: KxColors.cyan), maxLines: 1),
                const SizedBox(height: 2),
                // Scales down instead of wrapping on narrow phones / large text.
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
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SourceBadge(source: source),
              if (updatedAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Updated ${formatTime(updatedAt!)}',
                  style: KxText.mono(10, color: KxColors.textDim),
                  maxLines: 1,
                  softWrap: false,
                ),
              ],
            ],
          ),
          // Explicit refresh: pull-to-refresh isn't discoverable (or mouse-draggable) on web/desktop.
          IconButton(
            tooltip: loading ? 'Refreshing…' : 'Refresh market data',
            onPressed: loading ? null : onRefresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: _minTap, height: _minTap),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: loading
                  ? const SizedBox(
                      key: ValueKey('spin'),
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: KxColors.cyan),
                    )
                  : const Icon(Icons.refresh_rounded, key: ValueKey('icon'), size: 22, color: KxColors.textDim),
            ),
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

// --- Hero -------------------------------------------------------------------

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.stats});

  final GlobalStats stats;

  /// Market-cap weighted 7d index of the highest-volume coins, rebased to 100.
  /// A real, data-driven "pulse" line: these coins carry most of the market cap.
  static List<double>? _pulse(List<Coin> coins) {
    final series = coins
        .where((c) => c.sparkline.length > 1 && c.sparkline.first > 0 && (c.marketCap ?? 0) > 0)
        .toList();
    if (series.isEmpty) return null;
    final n = series.map((c) => c.sparkline.length).reduce(math.min);
    if (n < 2) return null;
    final totalCap = series.fold<double>(0, (s, c) => s + c.marketCap!);
    return List<double>.generate(n, (i) {
      var v = 0.0;
      for (final c in series) {
        final s = c.sparkline;
        final idx = (i * (s.length - 1) / (n - 1)).round();
        v += s[idx] / s.first * (c.marketCap! / totalCap);
      }
      return v * 100;
    });
  }

  @override
  Widget build(BuildContext context) {
    final change = stats.marketCapChange24h;
    final pulse = _pulse(stats.topVolume);
    final pulseChange = pulse == null ? null : (pulse.last / pulse.first - 1) * 100;
    final accent = change == null ? KxColors.cyan : KxColors.change(change);
    final changeText = change == null
        ? '24h change unavailable'
        : '${change >= 0 ? 'Up' : 'Down'} ${change.abs().toStringAsFixed(2)}% in the last 24 hours';

    return GlassCard(
      glow: KxColors.cyan,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          KxColors.cyan.withValues(alpha: 0.12),
          KxColors.violet.withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.02),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(icon: Icons.public_rounded, color: KxColors.cyan, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text('TOTAL MARKET CAP',
                    style: KxText.label(11), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              ChangePill(change, size: 12),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            label: 'Total market cap ${formatCompact(stats.totalMarketCap)}. $changeText',
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AnimatedPrice(
                value: stats.totalMarketCap,
                compact: true,
                style: KxText.mono(36, weight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: Text(
              changeText,
              style: KxText.body(12, color: KxColors.textDim),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (pulse != null) ...[
            const SizedBox(height: 14),
            ExcludeSemantics(
              child: SizedBox(
                height: 64,
                width: double.infinity,
                child: Sparkline(values: pulse, color: KxColors.change(pulseChange)),
              ),
            ),
            const SizedBox(height: 8),
            Tooltip(
              message: 'Market-cap weighted 7-day performance of the most-traded coins, rebased to 100',
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '7D PULSE · TOP-VOLUME INDEX',
                      style: KxText.label(9, color: KxColors.textDim),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(formatPercent(pulseChange), style: KxText.mono(11, color: KxColors.change(pulseChange))),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            // Glow rule so the card still has a visual anchor without chart data.
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accent.withValues(alpha: 0), accent, accent.withValues(alpha: 0)]),
                boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 10)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --- KPI grid ---------------------------------------------------------------

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color, this.size = 32});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.08)],
        ),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 12, spreadRadius: -4)],
      ),
      child: Icon(icon, size: size * 0.55, color: color),
    );
  }
}

/// Number that counts up from zero on first appearance and glides on updates.
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.format, required this.style});

  final double? value;
  final String Function(double) format;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final target = value;
    if (target == null) return Text('—', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v), style: style, maxLines: 1, softWrap: false),
    );
  }
}

typedef _Kpi = ({IconData icon, String label, String caption, double? value, String Function(double) format, Color color});

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats});

  final GlobalStats stats;

  static String _pct1(double v) => '${v.toStringAsFixed(1)}%';
  static String _pct2(double v) => '${v.toStringAsFixed(2)}%';
  static String _compact(double v) => formatCompact(v);
  static String _int(double v) => formatNumber(v);

  @override
  Widget build(BuildContext context) {
    final mcap = stats.totalMarketCap, vol = stats.totalVolume;
    final ratio = (mcap != null && vol != null && mcap > 0) ? vol / mcap * 100 : null;
    final kpis = <_Kpi>[
      (
        icon: Icons.bar_chart_rounded,
        label: '24h volume',
        caption: 'Traded in 24h',
        value: vol,
        format: _compact,
        color: KxColors.cyan,
      ),
      (
        icon: Icons.speed_rounded,
        label: 'Vol / M.cap',
        caption: 'Liquidity turnover',
        value: ratio,
        format: _pct2,
        color: KxColors.magenta,
      ),
      (
        icon: Icons.currency_bitcoin,
        label: 'BTC dominance',
        caption: 'Share of total cap',
        value: stats.dominance['BTC'],
        format: _pct1,
        color: _brandColors['BTC']!,
      ),
      (
        icon: Icons.diamond_outlined,
        label: 'ETH dominance',
        caption: 'Share of total cap',
        value: stats.dominance['ETH'],
        format: _pct1,
        color: _brandColors['ETH']!,
      ),
      (
        icon: Icons.hub_outlined,
        label: 'Active coins',
        caption: 'Tracked assets',
        value: stats.activeCryptocurrencies?.toDouble(),
        format: _int,
        color: KxColors.up,
      ),
      (
        icon: Icons.storefront_outlined,
        label: 'Exchanges',
        caption: 'Trading venues',
        value: stats.markets?.toDouble(),
        format: _int,
        color: KxColors.warn,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final columns = constraints.maxWidth >= 560 ? 3 : 2;
        // Explicit rows (not a Wrap) so tiles in a row share one height even
        // when one label wraps to two lines at large text sizes.
        return Column(
          children: [
            for (var r = 0; r < kpis.length; r += columns) ...[
              if (r > 0) const SizedBox(height: spacing),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = r; i < r + columns; i++) ...[
                      if (i > r) const SizedBox(width: spacing),
                      Expanded(
                        child: i < kpis.length
                            ? _KpiTile(kpi: kpis[i])
                                .animate(delay: (140 + i * 60).ms)
                                .fadeIn(duration: 400.ms)
                                .scaleXY(begin: 0.96, end: 1, duration: 400.ms, curve: Curves.easeOutCubic)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.kpi});

  final _Kpi kpi;

  @override
  Widget build(BuildContext context) {
    final value = kpi.value;
    return Semantics(
      container: true,
      label: '${kpi.label}: ${value == null ? 'unavailable' : kpi.format(value)}. ${kpi.caption}',
      excludeSemantics: true,
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // Values line up along the bottom of each row regardless of label length.
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _IconBadge(icon: kpi.icon, color: kpi.color, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    kpi.label.toUpperCase(),
                    style: KxText.label(10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _CountUp(value: value, format: kpi.format, style: KxText.mono(19, weight: FontWeight.w700)),
                ),
                const SizedBox(height: 2),
                Text(kpi.caption,
                    style: KxText.body(11, color: KxColors.textDim), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Dominance donut --------------------------------------------------------

typedef _Slice = ({String label, double pct, Color color});

class _DominanceCard extends StatefulWidget {
  const _DominanceCard({required this.dominance});

  final Map<String, double> dominance;

  @override
  State<_DominanceCard> createState() => _DominanceCardState();
}

class _DominanceCardState extends State<_DominanceCard> {
  static const _donutSize = 150.0;

  /// Selected slice, or -1 for none (the centre then shows the leader, BTC).
  int _selected = -1;

  List<_Slice> _slices() {
    final top = widget.dominance.entries.take(_dominanceSlices).toList();
    final others = (100 - top.fold<double>(0, (s, e) => s + e.value)).clamp(0.0, 100.0).toDouble();
    return [
      for (final (i, e) in top.indexed)
        (label: e.key, pct: e.value, color: _brandColors[e.key] ?? _fallbackPalette[i % _fallbackPalette.length]),
      if (others > 0.05) (label: 'Others', pct: others, color: KxColors.textMuted),
    ];
  }

  void _select(int i) => setState(() => _selected = (i == _selected) ? -1 : i);

  @override
  Widget build(BuildContext context) {
    final slices = _slices();
    if (slices.isEmpty) return const SizedBox.shrink();
    final selected = _selected >= 0 && _selected < slices.length ? _selected : -1;
    final focus = slices[selected < 0 ? 0 : selected];
    final total = slices.fold<double>(0, (s, e) => s + e.pct);

    final donut = Semantics(
      label: 'Market-cap dominance chart. ${focus.label} ${focus.pct.toStringAsFixed(1)} percent',
      child: SizedBox(
        width: _donutSize,
        height: _donutSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ExcludeSemantics(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) {
                  final k = math.max(t, 0.001);
                  return PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      sectionsSpace: 2,
                      centerSpaceRadius: 46,
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, PieTouchResponse? response) {
                          if (event is! FlTapUpEvent) return;
                          final i = response?.touchedSection?.touchedSectionIndex ?? -1;
                          if (i < 0 || i >= slices.length) {
                            if (_selected != -1) setState(() => _selected = -1);
                            return;
                          }
                          _select(i);
                        },
                      ),
                      sections: [
                        for (final (i, s) in slices.indexed)
                          PieChartSectionData(
                            value: s.pct * k,
                            color: selected < 0 || selected == i ? s.color : s.color.withValues(alpha: 0.3),
                            radius: selected == i ? 26 : 20,
                            showTitle: false,
                          ),
                        // Transparent remainder makes the ring sweep in clockwise.
                        if (t < 1)
                          PieChartSectionData(
                            value: total * (1 - k),
                            color: Colors.transparent,
                            radius: 20,
                            showTitle: false,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            ExcludeSemantics(
              child: IgnorePointer(
                // Keep the centre readout inside the donut hole at any text scale.
                child: SizedBox(
                  width: 78,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(scale: Tween<double>(begin: 0.85, end: 1).animate(anim), child: child),
                      ),
                      child: Column(
                        key: ValueKey(focus.label),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(focus.label.toUpperCase(), style: KxText.label(10, color: focus.color)),
                          const SizedBox(height: 2),
                          _CountUp(
                            value: focus.pct,
                            format: (v) => '${v.toStringAsFixed(1)}%',
                            style: KxText.mono(17, weight: FontWeight.w700),
                          ),
                          Text(selected < 0 ? 'leader' : 'share', style: KxText.body(9, color: KxColors.textDim)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, s) in slices.indexed)
          _LegendRow(
            slice: s,
            active: selected == i,
            dimmed: selected >= 0 && selected != i,
            onTap: () => _select(i),
          ),
      ],
    );

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Side-by-side needs room for "SYMBOL  12.3%" next to the donut;
          // otherwise (narrow phones, large text) stack the legend underneath.
          final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
          final legendRoom = constraints.maxWidth - _donutSize - 16;
          if (legendRoom >= 120 * textScale) {
            return Row(children: [donut, const SizedBox(width: 16), Expanded(child: legend)]);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Center(child: donut), const SizedBox(height: 12), legend],
          );
        },
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice, required this.active, required this.dimmed, required this.onTap});

  final _Slice slice;
  final bool active;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: '${slice.label}, ${slice.pct.toStringAsFixed(1)} percent of total market cap',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 40 + 2×2 margin = 44px hit target (margin is inside the detector).
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(vertical: 2),
          constraints: const BoxConstraints(minHeight: _minTap - 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active ? slice.color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: dimmed ? 0.45 : 1,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: slice.color,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: slice.color.withValues(alpha: 0.6), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(slice.label,
                      style: KxText.body(12, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                Text('${slice.pct.toStringAsFixed(1)}%', style: KxText.mono(12, color: KxColors.textDim)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Sentiment gauge --------------------------------------------------------

const _sentimentMethod = 'Estimated in-app from the 24h market-cap change and the average move of '
    'the top gainers and losers. This is not the Crypto Fear & Greed Index or any official '
    'index, and not financial advice.';

class _EstimateTag extends StatelessWidget {
  const _EstimateTag();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _sentimentMethod,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 6),
      // Informational only (the full method note is also printed in the card),
      // kept compact so section headers stay aligned in the two-column layout.
      child: Semantics(
        label: 'In-app estimate',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: KxColors.borderStrong),
            color: KxColors.surface,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ESTIMATE', style: KxText.label(9, color: KxColors.textDim)),
              const SizedBox(width: 4),
              const Icon(Icons.info_outline_rounded, size: 12, color: KxColors.textDim),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _SentimentInput = ({double? score, double? mcapChange, double? gainersAvg, double? losersAvg});

/// Fear & greed *style* score (0-100), computed client-side:
/// 50 ± market-cap momentum (±30) ± top-mover balance (±20).
/// Returns a null score when there is no input at all, rather than a fake "Neutral 50".
_SentimentInput _estimateSentiment(GlobalStats s) {
  double? avg(List<Coin> coins) {
    final v = coins.map((c) => c.change24h).whereType<double>().toList();
    return v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  }

  final gainers = avg(s.topGainers), losers = avg(s.topLosers);
  if (s.marketCapChange24h == null && gainers == null && losers == null) {
    return (score: null, mcapChange: null, gainersAvg: null, losersAvg: null);
  }
  final momentum = ((s.marketCapChange24h ?? 0) * 6).clamp(-30.0, 30.0).toDouble();
  final g = gainers ?? 0, l = losers ?? 0;
  final denom = g.abs() + l.abs();
  final balance = denom == 0 ? 0.0 : (g + l) / denom * 20;
  final score = (50 + momentum + balance).clamp(0.0, 100.0).toDouble();
  return (score: score, mcapChange: s.marketCapChange24h, gainersAvg: gainers, losersAvg: losers);
}

String _sentimentLabel(double score) => switch (score) {
      < 25 => 'Extreme Fear',
      < 45 => 'Fear',
      < 55 => 'Neutral',
      < 75 => 'Greed',
      _ => 'Extreme Greed',
    };

Color _sentimentColor(double score) {
  final t = (score / 100).clamp(0.0, 1.0);
  return t < 0.5
      ? Color.lerp(KxColors.down, KxColors.warn, t * 2)!
      : Color.lerp(KxColors.warn, KxColors.up, (t - 0.5) * 2)!;
}

class _SentimentCard extends StatelessWidget {
  const _SentimentCard({required this.stats});

  final GlobalStats stats;

  @override
  Widget build(BuildContext context) {
    final s = _estimateSentiment(stats);
    final target = s.score;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (target == null)
            SizedBox(
              height: 150,
              child: Center(
                child: Text(
                  'Not enough market data to estimate sentiment right now.',
                  textAlign: TextAlign.center,
                  style: KxText.body(13, color: KxColors.textDim),
                ),
              ),
            )
          else
            Semantics(
              label: 'Estimated sentiment ${target.round()} out of 100, ${_sentimentLabel(target)}. '
                  'In-app estimate, not an official index.',
              excludeSemantics: true,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: target / 100),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) {
                  final score = t * 100;
                  final color = _sentimentColor(score);
                  return SizedBox(
                    height: 150,
                    child: Stack(
                      children: [
                        Positioned.fill(child: CustomPaint(painter: _GaugePainter(t))),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            // Scale down rather than overflow the gauge at large text sizes.
                            child: SizedBox(
                              height: 72,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.bottomCenter,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${score.round()}', style: KxText.mono(34, weight: FontWeight.w700)),
                                    Text(_sentimentLabel(score),
                                        style: KxText.display(14, weight: FontWeight.w600, color: color)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _MetricChip(label: 'M.cap 24h', value: s.mcapChange),
              _MetricChip(label: 'Gainers avg', value: s.gainersAvg),
              _MetricChip(label: 'Losers avg', value: s.losersAvg),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _sentimentMethod,
            textAlign: TextAlign.center,
            style: KxText.body(11, color: KxColors.textDim),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label ${formatPercent(value)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: KxColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: KxText.body(11, color: KxColors.textDim)),
            const SizedBox(width: 6),
            Text(formatPercent(value), style: KxText.mono(11, weight: FontWeight.w600, color: KxColors.change(value))),
          ],
        ),
      ),
    );
  }
}

/// Semicircle gauge: red → amber → green track, glowing progress arc, ticks and a knob.
class _GaugePainter extends CustomPainter {
  _GaugePainter(this.t);

  /// Progress 0..1.
  final double t;

  static const _stroke = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 12);
    final radius = math.min(size.width / 2 - 14, size.height - 26);
    if (radius <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: radius);

    SweepGradient gradient(double alpha) => SweepGradient(
          startAngle: math.pi,
          endAngle: 2 * math.pi,
          colors: [
            KxColors.down.withValues(alpha: alpha),
            KxColors.warn.withValues(alpha: alpha),
            KxColors.up.withValues(alpha: alpha),
          ],
        );

    // Track.
    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..shader = gradient(0.16).createShader(rect),
    );

    // Ticks at 0/25/50/75/100.
    final tick = Paint()
      ..color = KxColors.textMuted
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k <= 4; k++) {
      final a = math.pi + math.pi * k / 4;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(center + dir * (radius - _stroke - 4), center + dir * (radius - _stroke - 10), tick);
    }

    if (t <= 0.001) return;
    final sweep = math.pi * t.clamp(0.0, 1.0);

    // Glow under the progress arc.
    canvas.drawArc(
      rect,
      math.pi,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke + 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..shader = gradient(0.45).createShader(rect),
    );
    canvas.drawArc(
      rect,
      math.pi,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..shader = gradient(1).createShader(rect),
    );

    // Knob.
    final a = math.pi + sweep;
    final knob = center + Offset(math.cos(a), math.sin(a)) * radius;
    final color = _sentimentColor(t * 100);
    canvas.drawCircle(
      knob,
      11,
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(knob, 9, Paint()..color = color);
    canvas.drawCircle(knob, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.t != t;
}

// --- Top movers -------------------------------------------------------------

enum _Movers { gainers, losers, volume }

class _TopMovers extends StatefulWidget {
  const _TopMovers({required this.stats, required this.onOpen});

  final GlobalStats stats;
  final void Function(Coin coin, String heroPrefix) onOpen;

  @override
  State<_TopMovers> createState() => _TopMoversState();
}

class _TopMoversState extends State<_TopMovers> {
  _Movers _mode = _Movers.gainers;

  @override
  Widget build(BuildContext context) {
    final (coins, prefix, blurb, emptyIcon) = switch (_mode) {
      _Movers.gainers => (
          widget.stats.topGainers,
          'gain',
          'Biggest 24h price gains · tap a coin for details',
          Icons.trending_up_rounded,
        ),
      _Movers.losers => (
          widget.stats.topLosers,
          'lose',
          'Biggest 24h price drops · tap a coin for details',
          Icons.trending_down_rounded,
        ),
      _Movers.volume => (
          widget.stats.topVolume,
          'vol',
          'Most traded by 24h volume · tap a coin for details',
          Icons.bar_chart_rounded,
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader('Top movers · 24h'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          // Tight 44px height lifts the control's own 38px to a comfortable tap target.
          child: SizedBox(
            height: _minTap,
            child: KxSegmented<_Movers>(
              options: _Movers.values,
              selected: _mode,
              labelOf: (m) => switch (m) {
                _Movers.gainers => 'Gainers',
                _Movers.losers => 'Losers',
                _Movers.volume => 'Volume',
              },
              onSelected: (m) {
                if (m != _mode) setState(() => _mode = m);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              blurb,
              key: ValueKey(blurb),
              style: KxText.body(12, color: KxColors.textDim),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, if (current != null) current],
          ),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: coins.isEmpty
              ? Padding(
                  key: ValueKey('empty-$_mode'),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(emptyIcon, size: 28, color: KxColors.textMuted),
                      const SizedBox(height: 8),
                      Text('No coins in this list right now.',
                          textAlign: TextAlign.center, style: KxText.body(13, color: KxColors.textDim)),
                      const SizedBox(height: 2),
                      Text('Pull down or tap refresh to try again.',
                          textAlign: TextAlign.center, style: KxText.body(11, color: KxColors.textDim)),
                    ],
                  ),
                )
              : Column(
                  key: ValueKey(_mode),
                  children: [
                    for (final coin in coins)
                      CoinTile(
                        coin: coin,
                        heroPrefix: prefix,
                        showSparkline: false,
                        onTap: () => widget.onOpen(coin, prefix),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
