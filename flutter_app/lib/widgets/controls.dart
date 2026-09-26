import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'glass.dart';

/// Frosted search field with a neon focus ring.
class KxSearchField extends StatefulWidget {
  const KxSearchField({super.key, required this.controller, required this.onChanged, this.hint = 'Search'});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  State<KxSearchField> createState() => _KxSearchFieldState();
}

class _KxSearchFieldState extends State<KxSearchField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (focused) BoxShadow(color: KxColors.cyan.withValues(alpha: 0.25), blurRadius: 20, spreadRadius: -4),
        ],
      ),
      child: GlassCard(
        blur: true,
        radius: 16,
        padding: EdgeInsets.zero,
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          onChanged: (v) {
            setState(() {});
            widget.onChanged(v);
          },
          style: KxText.body(15),
          cursorColor: KxColors.cyan,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: widget.hint,
            hintStyle: KxText.body(15, color: KxColors.textMuted),
            prefixIcon: Icon(Icons.search_rounded, color: focused ? KxColors.cyan : KxColors.textMuted),
            suffixIcon: widget.controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, color: KxColors.textDim, size: 20),
                    onPressed: () {
                      widget.controller.clear();
                      setState(() {});
                      widget.onChanged('');
                    },
                  ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

/// Horizontal chip bar whose selection glides between options.
class KxChipBar<T> extends StatelessWidget {
  const KxChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final option = options[i];
          final active = option == selected;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(option);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: active ? KxColors.brandGradient : null,
                color: active ? null : KxColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: active ? Colors.transparent : KxColors.border),
                boxShadow: [
                  if (active) BoxShadow(color: KxColors.cyan.withValues(alpha: 0.3), blurRadius: 14, spreadRadius: -4),
                ],
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 280),
                style: KxText.body(13,
                    weight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.black : KxColors.textDim),
                child: Text(labelOf(option)),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Segmented control with a sliding gradient thumb (used for chart ranges).
class KxSegmented<T> extends StatelessWidget {
  const KxSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final index = options.indexOf(selected);
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KxColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                left: segmentWidth * index,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: KxColors.brandGradient,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [BoxShadow(color: KxColors.cyan.withValues(alpha: 0.35), blurRadius: 12)],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSelected(option);
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            style: KxText.mono(12,
                                weight: FontWeight.w700,
                                color: option == selected ? Colors.black : KxColors.textDim),
                            child: Text(labelOf(option)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

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
    return Column(
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
          style: KxText.body(11,
              weight: active ? FontWeight.w700 : FontWeight.w500, color: active ? KxColors.text : KxColors.textMuted),
          child: Text(label),
        ),
      ],
    );
  }
}
