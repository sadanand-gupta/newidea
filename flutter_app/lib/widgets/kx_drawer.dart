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
                // Premium header with user info
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        KxColors.bgElevated.withValues(alpha: 0.8),
                        KxColors.cyan.withValues(alpha: 0.1),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(color: KxColors.cyan.withValues(alpha: 0.2), width: 1),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar with gradient
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: KxColors.brandGradient,
                          boxShadow: [
                            BoxShadow(
                              color: KxColors.cyan.withValues(alpha: 0.3),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          user?.username[0].toUpperCase() ?? 'U',
                          style: KxText.display(28, color: Colors.black, weight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Username
                      Text(
                        user?.username ?? 'User',
                        style: KxText.display(20, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      // Email
                      if (user?.email != null)
                        Text(
                          user!.email!,
                          style: KxText.body(13, color: KxColors.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // Menu items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      _MenuSection(
                        title: 'ACCOUNT',
                        items: [
                          _DrawerItem(
                            icon: Icons.person_rounded,
                            label: 'Profile',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.of(context).pushNamed('/profile');
                            },
                          ),
                        ],
                      ),
                      _MenuSection(
                        title: 'NAVIGATION',
                        items: [
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
                        ],
                      ),
                      _MenuSection(
                        title: 'SETTINGS',
                        items: [
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
                    ],
                  ),
                ),
                // Logout button at bottom
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _confirmLogout(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                KxColors.warn.withValues(alpha: 0.25),
                                KxColors.warn.withValues(alpha: 0.15),
                              ],
                            ),
                            border: Border.all(
                              color: KxColors.warn.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, color: KxColors.warn, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Logout',
                                style: KxText.body(15, weight: FontWeight.w700, color: KxColors.warn),
                              ),
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

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.items});

  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            title,
            style: KxText.label(11, color: KxColors.cyan).copyWith(letterSpacing: 1.5),
          ),
        ),
        ...items,
      ],
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: KxColors.cyan.withValues(alpha: 0.1),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: KxColors.cyan, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: KxText.body(15, weight: FontWeight.w500)),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: KxColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
