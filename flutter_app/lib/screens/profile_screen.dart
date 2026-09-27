import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Profile', style: KxText.display(20)),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.user;
          if (user == null) {
            return Center(
              child: Text('Not authenticated', style: KxText.body(16)),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // User Avatar Card
                  GlassCard(
                    radius: 20,
                    padding: const EdgeInsets.all(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [KxColors.cyan.withValues(alpha: 0.1), KxColors.violet.withValues(alpha: 0.1)],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: KxColors.brandGradient,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            user.username[0].toUpperCase(),
                            style: KxText.display(36, color: Colors.black),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(user.username, style: KxText.display(24)),
                        const SizedBox(height: 8),
                        if (user.email != null)
                          Text(user.email!, style: KxText.body(14, color: KxColors.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Account Details
                  _InfoSection(
                    title: 'Account Details',
                    children: [
                      _InfoTile(label: 'Username', value: user.username),
                      if (user.email != null) _InfoTile(label: 'Email', value: user.email!),
                      _InfoTile(
                        label: 'Joined',
                        value: '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                      ),
                      _InfoTile(label: 'User ID', value: user.id.substring(0, 8)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Logout Button
                  GestureDetector(
                    onTap: () => _confirmLogout(context),
                    child: GlassCard(
                      radius: 12,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      gradient: LinearGradient(
                        colors: [KxColors.warn.withValues(alpha: 0.2), KxColors.warn.withValues(alpha: 0.1)],
                      ),
                      child: Center(
                        child: Text(
                          'Logout',
                          style: KxText.body(16, weight: FontWeight.w700, color: KxColors.warn),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 12),
          child: Text(title, style: KxText.label(12, color: KxColors.cyan).copyWith(letterSpacing: 1.2)),
        ),
        ...children,
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 12,
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KxText.body(14, color: KxColors.textDim)),
          Text(value, style: KxText.body(14, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}
