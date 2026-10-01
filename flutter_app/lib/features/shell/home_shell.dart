import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/shared/shared.dart';
import 'package:kryptox/features/shell/kx_drawer.dart';
import 'package:kryptox/features/markets/coin_list_screen.dart';
import 'package:kryptox/features/home/home_screen.dart';
import 'package:kryptox/features/stats/market_stats_screen.dart';
import 'package:kryptox/features/watchlist/watchlist_screen.dart';

/// Bottom padding every tab adds so its content clears the floating nav bar.
const double kNavBarClearance = KxLayout.navBarClearance;

/// Widest the floating nav bar gets; on desktop/web it floats centred instead
/// of stretching edge to edge.
const double _kNavBarMaxWidth = 520;

/// Shell tab indices, shared by the nav bar, the drawer and the home dashboard.
abstract final class ShellTab {
  static const home = 0;
  static const markets = 1;
  static const stats = 2;
  static const watchlist = 3;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  static const List<(IconData, IconData, String)> _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.candlestick_chart_outlined, Icons.candlestick_chart, 'Markets'),
    (Icons.insights_outlined, Icons.insights, 'Stats'),
    (Icons.star_outline_rounded, Icons.star_rounded, 'Watchlist'),
  ];

  int _index = ShellTab.home;

  // Brief fade + lift on the newly selected tab. It wraps the whole
  // IndexedStack (not each child) so tab state is never torn down.
  late final AnimationController _switch = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );
  late final Animation<double> _opacity = CurvedAnimation(parent: _switch, curve: Curves.easeOutCubic);
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(0, 0.012),
    end: Offset.zero,
  ).animate(_opacity);

  @override
  void dispose() {
    _switch.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _index || i < 0 || i >= _items.length) return;
    setState(() => _index = i);
    if (MediaQuery.of(context).disableAnimations) {
      _switch.value = 1;
    } else {
      _switch.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      // Back on a secondary tab returns to Home instead of leaving the app.
      canPop: _index == ShellTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(ShellTab.home);
      },
      child: KxBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          drawer: KxDrawer(currentIndex: _index, onSelectTab: _select),
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
                  TickerMode(
                    enabled: _index == ShellTab.home,
                    child: HomeScreen(onNavigate: _select),
                  ),
                  TickerMode(enabled: _index == ShellTab.markets, child: const CoinListScreen()),
                  TickerMode(enabled: _index == ShellTab.stats, child: const MarketStatsScreen()),
                  TickerMode(
                    enabled: _index == ShellTab.watchlist,
                    child: WatchlistScreen(onBrowseMarkets: () => _select(ShellTab.markets)),
                  ),
                ],
              ),
            ),
          ),
          // heightFactor: 1 keeps the bar its natural height (Scaffold gives the
          // slot a loose height); the width cap stops it stretching on desktop.
          bottomNavigationBar: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kNavBarMaxWidth),
              child: KxNavBar(index: _index, onChanged: _select, items: _items),
            ),
          ),
        ),
      ),
    );
  }
}
