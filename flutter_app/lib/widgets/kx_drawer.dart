import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';

class KxDrawer extends StatelessWidget {
  const KxDrawer({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KxColors.bgElevated,
        title: Text('Logout?', style: KxText.display(18)),
        content: Text('Are you sure you want to logout?', style: KxText.body(14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: KxText.body(14, color: KxColors.cyan)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Logout', style: KxText.body(14, color: KxColors.warn)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Drawer(
        backgroundColor: KxColors.bg,
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            final user = auth.user;
            return Column(
              children: [
                // Header with user info
                Container(
                  color: KxColors.bgElevated,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: KxColors.brandGradient,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          user?.username[0].toUpperCase() ?? 'U',
                          style: KxText.display(24, color: Colors.black),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(user?.username ?? 'User', style: KxText.display(18)),
                      if (user?.email != null) ...[
                        const SizedBox(height: 4),
                        Text(user!.email!, style: KxText.body(12, color: KxColors.textMuted)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Menu items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    children: [
                      _DrawerItem(
                        icon: Icons.person_outline_rounded,
                        label: 'Profile',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.of(context).pushNamed('/profile');
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.candlestick_chart_rounded,
                        label: 'Markets',
                        onTap: () => Navigator.pop(context),
                      ),
                      _DrawerItem(
                        icon: Icons.insights_rounded,
                        label: 'Market Stats',
                        onTap: () => Navigator.pop(context),
                      ),
                      _DrawerItem(
                        icon: Icons.star_rounded,
                        label: 'Watchlist',
                        onTap: () => Navigator.pop(context),
                      ),
                      const Divider(color: KxColors.border),
                      _DrawerItem(
                        icon: Icons.tune_rounded,
                        label: 'Settings',
                        onTap: () => Navigator.pop(context),
                      ),
                      _DrawerItem(
                        icon: Icons.info_outline_rounded,
                        label: 'About',
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Logout button at bottom
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _confirmLogout(context);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: GlassCard(
                          radius: 10,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          gradient: LinearGradient(
                            colors: [
                              KxColors.warn.withValues(alpha: 0.2),
                              KxColors.warn.withValues(alpha: 0.1),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, color: KxColors.warn, size: 20),
                              const SizedBox(width: 8),
                              Text('Logout', style: KxText.body(14, weight: FontWeight.w600, color: KxColors.warn)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: KxColors.textDim, size: 22),
              const SizedBox(width: 12),
              Text(label, style: KxText.body(14)),
            ],
          ),
        ),
      ),
    );
  }
}
