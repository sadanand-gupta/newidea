import 'package:flutter/material.dart';

import '../widgets/controls.dart';
import '../widgets/kx_background.dart';
import 'coin_list_screen.dart';
import 'market_stats_screen.dart';
import 'watchlist_screen.dart';

/// Bottom padding every tab adds so its content clears the floating nav bar.
const double kNavBarClearance = 110;

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  static const List<(IconData, IconData, String)> _items = [
    (Icons.candlestick_chart_outlined, Icons.candlestick_chart, 'Markets'),
    (Icons.insights_outlined, Icons.insights, 'Stats'),
    (Icons.star_outline_rounded, Icons.star_rounded, 'Watchlist'),
  ];

  int _index = 0;

  // Brief fade + lift on the newly selected tab. It wraps the whole
  // IndexedStack (not each child) so tab state is never torn down.
  late final AnimationController _switch =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 320), value: 1);
  late final Animation<double> _opacity = CurvedAnimation(parent: _switch, curve: Curves.easeOutCubic);
  late final Animation<Offset> _offset =
      Tween<Offset>(begin: const Offset(0, 0.012), end: Offset.zero).animate(_opacity);

  @override
  void dispose() {
    _switch.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _switch.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      // Back on a secondary tab returns to Markets instead of leaving the app.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: KxBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: FadeTransition(
            opacity: _opacity,
            child: SlideTransition(
              position: _offset,
              // IndexedStack keeps each tab's scroll position, search and filters.
              // It hides inactive tabs with Visibility.maintain, which keeps their
              // tickers running, so mute them explicitly: this stops the ticker
              // tape / pulses of hidden tabs and lets their timers see
              // TickerMode == false and skip polling.
              child: IndexedStack(
                index: _index,
                children: [
                  TickerMode(enabled: _index == 0, child: const CoinListScreen()),
                  TickerMode(enabled: _index == 1, child: const MarketStatsScreen()),
                  TickerMode(enabled: _index == 2, child: WatchlistScreen(onBrowseMarkets: () => _select(0))),
                ],
              ),
            ),
          ),
          bottomNavigationBar: KxNavBar(index: _index, onChanged: _select, items: _items),
        ),
      ),
    );
  }
}
