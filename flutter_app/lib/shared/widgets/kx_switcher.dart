import 'package:flutter/material.dart';

/// Cross-fades between the loading / error / data states of a screen or
/// section. Give each state's child a distinct key.
///
/// [expand] stacks the states to fill the parent (full-screen bodies);
/// otherwise they are top-aligned and sized by the incoming child (sections
/// inside a scroll view).
class KxSwitcher extends StatelessWidget {
  const KxSwitcher({
    super.key,
    required this.child,
    this.expand = false,
    this.duration = const Duration(milliseconds: 280),
  });

  final Widget child;
  final bool expand;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        fit: expand ? StackFit.expand : StackFit.passthrough,
        children: [...previous, if (current != null) current],
      ),
      child: child,
    );
  }
}
