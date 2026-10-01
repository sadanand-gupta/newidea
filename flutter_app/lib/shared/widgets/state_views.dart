import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/shared/widgets/gradient_button.dart';
import 'package:kryptox/shared/widgets/skeleton.dart';

/// Scrollable list of shimmering [SkeletonTile]s: the full-screen loading
/// state of coin lists. Use [SkeletonTileList] inside an existing scroll view.
class LoadingView extends StatelessWidget {
  const LoadingView({
    super.key,
    this.rows = 8,
    this.physics = const NeverScrollableScrollPhysics(),
    this.padding = const EdgeInsets.only(top: 4, bottom: KxLayout.navBarClearance + 10),
  });

  final int rows;
  final ScrollPhysics physics;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: ListView.builder(
          physics: physics,
          padding: padding,
          itemCount: rows,
          itemBuilder: (_, i) => SkeletonTile(index: i),
        ),
      ),
    );
  }
}

/// Full-area error state: pulsing icon, message and a Retry button.
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

/// Full-area empty state: floating icon, title, optional subtitle and action.
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
