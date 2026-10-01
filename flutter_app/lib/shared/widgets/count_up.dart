import 'package:flutter/material.dart';

/// Number that counts up from zero on first appearance and glides to new
/// values on updates. Shows "—" for a null [value].
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.format,
    required this.style,
    this.duration = const Duration(milliseconds: 1200),
  });

  final double? value;
  final String Function(double value) format;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final target = value;
    if (target == null) return Text('—', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v), style: style, maxLines: 1, softWrap: false),
    );
  }
}
