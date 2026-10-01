import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kryptox/core/theme/app_theme.dart';
import 'package:kryptox/shared/widgets/glass_card.dart';

/// Floating glass bottom navigation with a sliding glowing indicator.
class KxNavBar extends StatelessWidget {
  const KxNavBar({super.key, required this.index, required this.onChanged, required this.items});

  final int index;
  final ValueChanged<int> onChanged;
  final List<(IconData, IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: GlassCard(
        blur: true,
        radius: 26,
        padding: const EdgeInsets.all(6),
        gradient: LinearGradient(
          colors: [KxColors.bgElevated.withValues(alpha: 0.75), KxColors.bgElevated.withValues(alpha: 0.6)],
        ),
        child: SizedBox(
          height: 56,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth / items.length;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    left: w * index,
                    top: 0,
                    bottom: 0,
                    width: w,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [KxColors.cyan.withValues(alpha: 0.18), KxColors.violet.withValues(alpha: 0.18)],
                        ),
                        border: Border.all(color: KxColors.cyan.withValues(alpha: 0.35)),
                        boxShadow: [BoxShadow(color: KxColors.cyan.withValues(alpha: 0.18), blurRadius: 18)],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (i != index) HapticFeedback.selectionClick();
                              onChanged(i);
                            },
                            child: _NavItem(item: items[i], active: i == index),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.item, required this.active});

  final (IconData, IconData, String) item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final (icon, activeIcon, label) = item;
    // The bar has a fixed 56px height, so the icon + label shrink to fit
    // instead of overflowing at large system text sizes.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: active ? 1.12 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: active
                ? ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (b) => KxColors.brandGradient.createShader(Offset.zero & b.size),
                    child: Icon(activeIcon, size: 24),
                  )
                : Icon(icon, size: 24, color: KxColors.textMuted),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: KxText.body(
              11,
              weight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? KxColors.text : KxColors.textMuted,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
