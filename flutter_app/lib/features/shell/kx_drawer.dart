import 'package:flutter/material.dart';

import 'package:kryptox/core/config.dart';
import 'package:kryptox/features/shell/about_dialog.dart';
import 'package:kryptox/features/shell/home_shell.dart';
import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/shared/shared.dart';

/// Side menu of the shell: jumps between tabs and opens the About dialog.
class KxDrawer extends StatelessWidget {
  const KxDrawer({super.key, required this.currentIndex, required this.onSelectTab});

  /// Currently selected shell tab (see [ShellTab]); highlighted in the menu.
  final int currentIndex;

  /// Switches the shell to another tab.
  final ValueChanged<int> onSelectTab;

  static const _destinations = <({int tab, IconData icon, IconData activeIcon, String label, String hint})>[
    (
      tab: ShellTab.home,
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
      hint: 'Market overview',
    ),
    (
      tab: ShellTab.markets,
      icon: Icons.candlestick_chart_outlined,
      activeIcon: Icons.candlestick_chart,
      label: 'Markets',
      hint: 'Top 100 coins, live',
    ),
    (
      tab: ShellTab.stats,
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights,
      label: 'Market Stats',
      hint: 'Dominance, sentiment, movers',
    ),
    (
      tab: ShellTab.watchlist,
      icon: Icons.star_outline_rounded,
      activeIcon: Icons.star_rounded,
      label: 'Watchlist',
      hint: 'Coins you are tracking',
    ),
  ];

  void _go(BuildContext context, int tab) {
    Navigator.of(context).pop(); // closes the drawer
    onSelectTab(tab);
  }

  void _about(BuildContext context) {
    // Grab the navigator before the drawer closes and its context goes away.
    final navigator = Navigator.of(context);
    navigator.pop();
    showKxAboutDialog(navigator.context);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: KxColors.bg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(24))),
      child: Column(
        children: [
          const _DrawerHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              children: [
                const _SectionLabel('NAVIGATE'),
                for (final d in _destinations)
                  _DrawerItem(
                    icon: d.icon,
                    activeIcon: d.activeIcon,
                    label: d.label,
                    subtitle: d.hint,
                    selected: d.tab == currentIndex,
                    onTap: () => _go(context, d.tab),
                  ),
                const SizedBox(height: 8),
                const _SectionLabel('INFO'),
                _DrawerItem(
                  icon: Icons.info_outline_rounded,
                  activeIcon: Icons.info_rounded,
                  label: 'About KryptoX',
                  subtitle: 'Version, data source, licenses',
                  selected: false,
                  onTap: () => _about(context),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, size: 14, color: KxColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Data by CoinGecko · v${AppConfig.version}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KxText.body(12, color: KxColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KxColors.bgElevated.withValues(alpha: 0.8), KxColors.cyan.withValues(alpha: 0.1)],
        ),
        border: Border(bottom: BorderSide(color: KxColors.cyan.withValues(alpha: 0.2))),
      ),
      child: SafeArea(
        bottom: false,
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
          child: Row(
            children: [
              const KxLogoMark(size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: GradientText('KryptoX', style: KxText.display(22, weight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 4),
                    Text('Crypto market intelligence', style: KxText.body(13, color: KxColors.textDim)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Text(text, style: KxText.eyebrow()),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        button: true,
        selected: selected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            borderRadius: shape,
            gradient: selected
                ? LinearGradient(
                    colors: [KxColors.cyan.withValues(alpha: 0.14), KxColors.violet.withValues(alpha: 0.10)],
                  )
                : null,
            border: Border.all(color: selected ? KxColors.cyan.withValues(alpha: 0.35) : Colors.transparent),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: shape,
              splashColor: KxColors.cyan.withValues(alpha: 0.08),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: selected ? KxColors.brandGradient : null,
                          color: selected ? null : KxColors.cyan.withValues(alpha: 0.08),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          selected ? activeIcon : icon,
                          color: selected ? Colors.black : KxColors.cyan,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KxText.body(15, weight: selected ? FontWeight.w700 : FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: KxText.body(12, color: KxColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: KxColors.cyan,
                            boxShadow: [BoxShadow(color: KxColors.cyan.withValues(alpha: 0.7), blurRadius: 6)],
                          ),
                        )
                      else
                        const Icon(Icons.chevron_right_rounded, size: 20, color: KxColors.textMuted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
