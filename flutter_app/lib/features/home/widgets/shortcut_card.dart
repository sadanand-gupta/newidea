import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/shared/shared.dart';

/// Tappable glass card linking to another part of the app: gradient icon
/// tile, [title], [subtitle] and a trailing arrow.
class ShortcutCard extends StatelessWidget {
  const ShortcutCard({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GlassCard(
          radius: KxLayout.radiusRow,
          padding: const EdgeInsets.all(14),
          onTap: onTap,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [KxColors.violet.withValues(alpha: 0.12), KxColors.cyan.withValues(alpha: 0.06)],
          ),
          child: Row(
            children: [
              Container(
                width: KxLayout.minTapTarget,
                height: KxLayout.minTapTarget,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(KxLayout.radiusControl),
                  gradient: KxColors.brandGradient,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.black, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: KxText.body(15, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: KxText.body(12, color: KxColors.textDim)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: KxColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
