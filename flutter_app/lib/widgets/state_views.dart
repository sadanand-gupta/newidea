import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import 'glass.dart';

/// Shimmering skeleton rows shaped like the real coin rows.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.rows = 8, this.physics = const NeverScrollableScrollPhysics()});

  final int rows;
  final ScrollPhysics physics;

  static Widget bar(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(6)),
  );

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: physics,
      padding: const EdgeInsets.only(top: 4, bottom: 120),
      itemCount: rows,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child:
            GlassCard(
                  radius: 18,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [bar(60, 12), const SizedBox(height: 6), bar(90, 10)],
                      ),
                      const Spacer(),
                      bar(60, 22),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [bar(70, 12), const SizedBox(height: 6), bar(46, 10)],
                      ),
                    ],
                  ),
                )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(duration: 1400.ms, delay: (i * 80).ms, color: KxColors.cyan.withValues(alpha: 0.12)),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _GlowIcon(icon: Icons.wifi_tethering_error_rounded, color: KxColors.down)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.94, end: 1.04, duration: 1200.ms, curve: Curves.easeInOut),
            const SizedBox(height: 24),
            Text('Connection lost', style: KxText.display(20)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: KxText.body(14, color: KxColors.textDim),
            ),
            const SizedBox(height: 24),
            GradientButton(label: 'Retry', icon: Icons.refresh_rounded, onPressed: onRetry),
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, curve: Curves.easeOutCubic),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.subtitle, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GlowIcon(icon: icon, color: KxColors.cyan)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: -4, end: 4, duration: 1800.ms, curve: Curves.easeInOut),
            const SizedBox(height: 24),
            Text(title, style: KxText.display(19), textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: KxText.body(14, color: KxColors.textDim),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              GradientButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, curve: Curves.easeOutCubic),
      ),
    );
  }
}

class _GlowIcon extends StatelessWidget {
  const _GlowIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)]),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 40)],
      ),
      child: Icon(icon, size: 38, color: color),
    );
  }
}

/// Primary CTA: brand gradient pill with a glow.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, this.icon, this.onPressed});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: KxColors.brandGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: KxColors.cyan.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: -6)],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 18, color: Colors.black), const SizedBox(width: 8)],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: KxText.body(14, weight: FontWeight.w700, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin floating error strip shown when a refresh fails but old data is on screen.
class RefreshErrorBanner extends StatelessWidget {
  const RefreshErrorBanner({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: true,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      gradient: LinearGradient(colors: [KxColors.down.withValues(alpha: 0.22), KxColors.down.withValues(alpha: 0.1)]),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: KxColors.down, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Refresh failed: $message',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: KxText.body(12),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.5, curve: Curves.easeOutBack);
  }
}
