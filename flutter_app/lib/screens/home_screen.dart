import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/glass.dart';
import '../widgets/kx_background.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KxBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Consumer<AuthProvider>(
            builder: (context, auth, _) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome Header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back',
                          style: KxText.label(12, color: KxColors.cyan).copyWith(letterSpacing: 2),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.user?.username ?? 'User',
                                  style: KxText.display(32),
                                ),
                                Text(
                                  'Your crypto research hub',
                                  style: KxText.body(14, color: KxColors.textDim),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: KxColors.brandGradient,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                (auth.user?.username ?? 'U')[0].toUpperCase(),
                                style: KxText.display(24, color: Colors.black),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Features Grid
                  Text(
                    'FEATURES',
                    style: KxText.label(11, color: KxColors.cyan).copyWith(letterSpacing: 2),
                  ),
                  const SizedBox(height: 12),
                  _FeatureGrid(
                    features: [
                      (
                        icon: Icons.candlestick_chart_rounded,
                        title: 'Markets',
                        description: 'Browse and analyze cryptocurrency markets with real-time data'
                      ),
                      (
                        icon: Icons.insights_rounded,
                        title: 'Market Stats',
                        description: 'View global market trends, dominance, and top movers'
                      ),
                      (
                        icon: Icons.star_rounded,
                        title: 'Watchlist',
                        description: 'Track your favorite cryptocurrencies and manage your watch list'
                      ),
                      (
                        icon: Icons.bar_chart_rounded,
                        title: 'Price Charts',
                        description: 'Analyze price trends with 7, 30, 90, and 365-day charts'
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Quick Actions
                  Text(
                    'QUICK NAVIGATION',
                    style: KxText.label(11, color: KxColors.cyan).copyWith(letterSpacing: 2),
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    icon: Icons.candlestick_chart_rounded,
                    label: 'Explore Markets',
                    onTap: () => Navigator.of(context).pushNamed('/markets'),
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    icon: Icons.star_rounded,
                    label: 'Your Watchlist',
                    onTap: () => Navigator.of(context).pushNamed('/watchlist'),
                  ),
                  const SizedBox(height: 32),

                  // App Info
                  GlassCard(
                    radius: 16,
                    padding: const EdgeInsets.all(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [KxColors.violet.withValues(alpha: 0.1), KxColors.cyan.withValues(alpha: 0.1)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('About KryptoX', style: KxText.body(14, weight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(
                          'KryptoX is a powerful cryptocurrency market research application that provides real-time data, market analysis, and portfolio tracking. Stay informed about the crypto market with advanced tools and comprehensive data.',
                          style: KxText.body(13, color: KxColors.textDim),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: KxColors.cyan),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Data powered by CoinGecko API',
                                style: KxText.body(12, color: KxColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.features});

  final List<({IconData icon, String title, String description})> features;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: features.length,
      itemBuilder: (context, i) {
        final f = features[i];
        return GlassCard(
          radius: 16,
          padding: const EdgeInsets.all(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [KxColors.cyan.withValues(alpha: 0.08), KxColors.violet.withValues(alpha: 0.05)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: KxColors.brandGradient,
                ),
                alignment: Alignment.center,
                child: Icon(f.icon, size: 20, color: Colors.black),
              ),
              const SizedBox(height: 8),
              Text(f.title, style: KxText.body(13, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  f.description,
                  style: KxText.body(11, color: KxColors.textMuted),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: GlassCard(
          radius: 12,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: KxColors.surface,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: KxColors.cyan, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: KxText.body(15, weight: FontWeight.w600)),
              ),
              Icon(Icons.arrow_forward_rounded, color: KxColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
