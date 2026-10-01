import 'package:flutter/material.dart';

import 'package:kryptox/core/theme/app_theme.dart';

/// The round KryptoX brand mark (gradient disc with the "X").
class KxLogoMark extends StatelessWidget {
  const KxLogoMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: KxColors.brandGradient,
          boxShadow: [BoxShadow(color: KxColors.cyan.withValues(alpha: 0.3), blurRadius: 16, spreadRadius: 1)],
        ),
        alignment: Alignment.center,
        child: Text(
          'X',
          style: KxText.display(size * 0.42, color: Colors.black, weight: FontWeight.w700),
        ),
      ),
    );
  }
}
