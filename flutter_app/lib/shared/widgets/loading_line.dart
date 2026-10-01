import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';

/// Hairline progress strip shown while a background refresh is in flight.
///
/// Always occupies [height] so toggling it never shifts the layout.
class LoadingLine extends StatelessWidget {
  const LoadingLine({
    super.key,
    required this.visible,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.height = 2,
    this.color,
  });

  final bool visible;
  final EdgeInsetsGeometry padding;
  final double height;

  /// Defaults to the theme's progress colour ([KxColors.cyan]).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SizedBox(
        height: height,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height),
            child: visible
                ? LinearProgressIndicator(minHeight: height, backgroundColor: Colors.transparent, color: color)
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
